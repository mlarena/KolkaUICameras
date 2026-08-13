from flask import Flask
from flask_jwt_extended import JWTManager
from werkzeug.security import generate_password_hash
from models import db, User, PhotoTrapConfig
from config import Config
from routes import register_routes
from datetime import timedelta


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)
    app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(hours=24)

    db.init_app(app)
    JWTManager(app)
    register_routes(app)

    with app.app_context():
        db.create_all()
        _init_defaults()

    return app


def _init_defaults():
    if not User.query.first():
        admin = User(username='admin', password_hash=generate_password_hash('admin123'))
        db.session.add(admin)
        db.session.commit()
        print("Created default admin user: admin / admin123")

    if PhotoTrapConfig.query.count() == 0:
        defaults = [
            ('NeedCalibration', 'false', 'Запускать калибровку (фаза 1+2) перед загрузкой файлов'),
            ('DownloadPath', '/opt/KolkaUICameras/images', 'Папка для сохранения файлов с камер'),
            ('CamerasCount', '1', 'Сколько камер должно быть в таблице PhotoTrap'),
            ('WifiPassword', '12345678', 'Пароль Wi-Fi сети камеры (WPA2PSK)'),
            ('BleScanTimeout', '10', 'Время BLE-сканирования (сек)'),
            ('BleCommandTimeout', '10', 'Таймаут BLE-подключения (сек)'),
            ('WifiWaitAfterOpen', '25', 'Ожидание после BLE open перед подключением к Wi-Fi (сек)'),
            ('WifiConnectTimeout', '45', 'Таймаут подключения к Wi-Fi сети камеры (сек)'),
            ('CloseWaitSeconds', '25', 'Пауза после close на все камеры (сек)'),
            ('RetryDelay', '15', 'Задержка между повторными попытками (сек)'),
            ('MaxRetriesPerCamera', '3', 'Попыток найти SSID / подключиться к одной камере'),
            ('MaxScanRetries', '10', 'Попыток BLE-сканирования для фазы 1'),
            ('CameraCooldown', '20', 'Пауза между разными камерами (сек)'),
            ('CompressQuality', '12', 'Качество сжатия ffmpeg -q:v (1-31, чем меньше тем лучше)'),
            ('WifiDownloadRetries', '3', 'Попыток реконнекта Wi-Fi при обрыве во время загрузки файлов'),
            ('WifiMaxRetries', '5', 'Максимум попыток подключения к Wi-Fi'),
            ('CompressAfterDownload', 'true', 'Сжимать JPG после загрузки (ffmpeg)'),
            ('DeleteAfterDownload', 'true', 'Удалять файлы с SD карты после загрузки'),
            ('SnapshotIntervalMinutes', '30', 'Интервал между снимками (мин)'),
        ]
        for key, value, desc in defaults:
            db.session.add(PhotoTrapConfig(Key=key, Value=value, Description=desc))
        db.session.commit()
        print(f"Created {len(defaults)} default config entries")


app = create_app()

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5011)
