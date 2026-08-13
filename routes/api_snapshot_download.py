"""
API для запуска снимков и загрузки файлов с фотоловушек.

POST /api/snapshot-download/start  — запуск в фоновом потоке
GET  /api/snapshot-download/status — статус + логи (polling)
GET  /api/snapshot-download/stream — SSE-стрим логов в реальном времени
POST /api/snapshot-download/stop   — остановка (текущая камера завершится)
"""
import json as _json
import time as _time
import threading
import asyncio
import queue
import logging

from flask import Blueprint, request, jsonify, Response, current_app
from flask_jwt_extended import jwt_required

api_snapshot_download_bp = Blueprint('api_snapshot_download', __name__)

_state = {
    'running': False,
    'status': 'idle',
    'lines': [],
    'log_queue': None,
    'stop_requested': False,
}


class _LogHandler(logging.Handler):
    """Перехватывает лог-записи из SnapshotDownloadManager и кладёт в очередь."""
    def __init__(self, log_queue):
        super().__init__()
        self._queue = log_queue

    def emit(self, record):
        try:
            msg = self.format(record)
            self._queue.put_nowait(msg)
        except Exception:
            pass


def _drain_queue():
    """Перенести все сообщения из очереди в _state['lines']."""
    q = _state.get('log_queue')
    if q is None:
        return
    while not q.empty():
        try:
            _state['lines'].append(q.get_nowait())
        except queue.Empty:
            break


def _run_snapshot_thread():
    """Фоновый поток: запуск SnapshotDownloadManager."""
    log_queue = queue.Queue()
    _state['log_queue'] = log_queue
    _state['running'] = True
    _state['status'] = 'running'
    _state['lines'] = []
    _state['stop_requested'] = False

    handler = _LogHandler(log_queue)
    handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(message)s"))

    # Перехватываем логи от всех связанных логгеров
    sd_logger = logging.getLogger("kolka_snapshot_and_download")
    sd_logger.setLevel(logging.INFO)
    sd_logger.addHandler(handler)

    root_logger = logging.getLogger()
    root_logger.addHandler(handler)

    try:
        from kolka_snapshot_and_download import SnapshotDownloadManager
        manager = SnapshotDownloadManager()

        # Патчим manager.run чтобы проверять stop_requested
        original_run = manager.run

        async def run_with_stop():
            await manager.init_db()
            try:
                async with manager.async_session() as session:
                    from config_loader import load_config
                    db_config = await load_config(session)
                    manager._apply_config(db_config)

                    if not await manager._validate_cameras(session):
                        logging.error("Камеры не настроены. Выполните калибровку.")
                        return

                    from sqlalchemy import select
                    from models import PhotoTrap
                    result = await session.execute(
                        select(PhotoTrap).where(
                            PhotoTrap.MacAddress.isnot(None),
                            PhotoTrap.WifiSSID.isnot(None),
                            PhotoTrap.IsActive == True
                        )
                    )
                    cameras = result.scalars().all()

                    if not cameras:
                        logging.warning("Нет активных камер")
                        return

                    logging.info("=" * 50)
                    logging.info("СНИМОК + ЗАГРУЗКА | %s", _time.strftime('%Y-%m-%d %H:%M:%S'))
                    logging.info("Камер: %d", len(cameras))
                    logging.info("=" * 50)

                    for cam in cameras:
                        if _state['stop_requested']:
                            logging.info("Остановка запрошена. Завершение.")
                            break

                        if not cam.WifiSSID:
                            logging.info("[%s] Пропуск — нет SSID", cam.MacAddress)
                            continue

                        await manager.snapshot_and_download(cam)

                        if cam != cameras[-1] and not _state['stop_requested']:
                            logging.info("Пауза %d сек...", manager.camera_cooldown)
                            await asyncio.sleep(manager.camera_cooldown)

                    logging.info("=" * 50)
                    logging.info("ЗАВЕРШЕНО")
                    logging.info("=" * 50)

            except Exception as e:
                logging.error("Ошибка: %s", e, exc_info=True)
            finally:
                await manager.engine.dispose()

        asyncio.run(run_with_stop())
        _state['status'] = 'completed'
    except Exception as e:
        _state['status'] = f'error: {e}'
        logging.error("Snapshot+Download failed: %s", e)
    finally:
        root_logger.removeHandler(handler)
        sd_logger.removeHandler(handler)
        _drain_queue()
        _state['running'] = False


@api_snapshot_download_bp.route('/api/snapshot-download/start', methods=['POST'])
@jwt_required()
def start_snapshot_download():
    if _state['running']:
        return jsonify({'error': 'Снимок+загрузка уже выполняется'}), 409
    _state['lines'] = []
    _state['status'] = 'starting'
    _state['stop_requested'] = False
    thread = threading.Thread(target=_run_snapshot_thread, daemon=True)
    thread.start()
    return jsonify({'message': 'Снимок+загрузка запущена'})


@api_snapshot_download_bp.route('/api/snapshot-download/status', methods=['GET'])
@jwt_required()
def snapshot_download_status():
    _drain_queue()
    return jsonify({
        'running': _state['running'],
        'status': _state['status'],
        'lines': _state['lines'],
    })


@api_snapshot_download_bp.route('/api/snapshot-download/stream')
def snapshot_download_stream():
    """SSE-стрим логов в реальном времени."""
    token = request.args.get('token', '')
    if not token:
        return jsonify({'error': 'Token required'}), 401
    try:
        import jwt as _jwt
        _jwt.decode(token, current_app.config['JWT_SECRET_KEY'], algorithms=['HS256'])
    except Exception:
        return jsonify({'error': 'Invalid token'}), 401

    def generate():
        last_idx = 0
        last_status = None
        _drain_queue()
        lines = _state['lines']
        if lines:
            yield f"data: {_json.dumps({'type': 'init', 'lines': lines, 'status': _state['status'], 'running': _state['running']})}\n\n"
            last_idx = len(lines)

        while True:
            _drain_queue()
            lines = _state['lines']
            running = _state['running']
            status = _state['status']

            if len(lines) > last_idx:
                new_lines = lines[last_idx:]
                yield f"data: {_json.dumps({'type': 'log', 'lines': new_lines})}\n\n"
                last_idx = len(lines)

            if status != last_status:
                yield f"data: {_json.dumps({'type': 'status', 'status': status, 'running': running})}\n\n"
                last_status = status

            if not running and last_status is not None:
                yield f"data: {_json.dumps({'type': 'done', 'status': status})}\n\n"
                break

            _time.sleep(0.5)

    return Response(generate(), mimetype='text/event-stream',
                    headers={'Cache-Control': 'no-cache', 'X-Accel-Buffering': 'no'})


@api_snapshot_download_bp.route('/api/snapshot-download/stop', methods=['POST'])
@jwt_required()
def stop_snapshot_download():
    if not _state['running']:
        return jsonify({'error': 'Снимок+загрузка не выполняется'}), 400
    _state['stop_requested'] = True
    _state['status'] = 'stopping'
    return jsonify({'message': 'Остановка будет выполнена после текущей камеры'})
