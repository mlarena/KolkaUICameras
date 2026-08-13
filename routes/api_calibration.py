import json as _json
import time as _time
import threading
import asyncio
import queue
import logging

from flask import Blueprint, request, jsonify, Response, current_app
from flask_jwt_extended import jwt_required
from models import db

api_calibration_bp = Blueprint('api_calibration', __name__)

_calibration_state = {
    'running': False,
    'status': 'idle',
    'lines': [],
    'log_queue': None,
}


class _CalibrationLogHandler(logging.Handler):
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
    q = _calibration_state.get('log_queue')
    if q is None:
        return
    while not q.empty():
        try:
            _calibration_state['lines'].append(q.get_nowait())
        except queue.Empty:
            break


def _run_calibration_thread():
    log_queue = queue.Queue()
    _calibration_state['log_queue'] = log_queue
    _calibration_state['running'] = True
    _calibration_state['status'] = 'running'
    _calibration_state['lines'] = []

    handler = _CalibrationLogHandler(log_queue)
    handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(message)s"))

    # Root logger must be at least INFO so that messages from child loggers
    # (with propagate=True) are not silently dropped before reaching our handler.
    root_logger = logging.getLogger()
    prev_root_level = root_logger.level
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(handler)

    cal_logger = logging.getLogger("calibration")
    cal_logger.setLevel(logging.INFO)

    try:
        from calibration import run_calibration
        asyncio.run(run_calibration())
        _calibration_state['status'] = 'completed'
    except Exception as e:
        _calibration_state['status'] = f'error: {e}'
        cal_logger.error("Calibration failed: %s", e)
    finally:
        root_logger.removeHandler(handler)
        root_logger.setLevel(prev_root_level)
        _drain_queue()
        _calibration_state['running'] = False


@api_calibration_bp.route('/api/calibration/start', methods=['POST'])
@jwt_required()
def start_calibration():
    if _calibration_state['running']:
        return jsonify({'error': 'Калибровка уже выполняется'}), 409
    _calibration_state['lines'] = []
    _calibration_state['status'] = 'starting'
    thread = threading.Thread(target=_run_calibration_thread, daemon=True)
    thread.start()
    return jsonify({'message': 'Калибровка запущена'})


@api_calibration_bp.route('/api/calibration/logs', methods=['GET'])
@jwt_required()
def calibration_logs():
    _drain_queue()
    return jsonify({
        'running': _calibration_state['running'],
        'status': _calibration_state['status'],
        'lines': _calibration_state['lines'],
    })


@api_calibration_bp.route('/api/calibration/stream')
def calibration_stream():
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
        lines = _calibration_state['lines']
        if lines:
            yield f"data: {_json.dumps({'type': 'init', 'lines': lines, 'status': _calibration_state['status'], 'running': _calibration_state['running']})}\n\n"
            last_idx = len(lines)

        while True:
            _drain_queue()
            lines = _calibration_state['lines']
            running = _calibration_state['running']
            status = _calibration_state['status']

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


@api_calibration_bp.route('/api/calibration/stop', methods=['POST'])
@jwt_required()
def stop_calibration():
    if not _calibration_state['running']:
        return jsonify({'error': 'Калибровка не выполняется'}), 400
    _calibration_state['status'] = 'stopping'
    return jsonify({'message': 'Остановка будет выполнена после текущей фазы'})
