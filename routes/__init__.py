from routes.auth import auth_bp
from routes.page import page_bp
from routes.api_traps import api_traps_bp
from routes.api_downloads import api_downloads_bp
from routes.api_snapshots import api_snapshots_bp
from routes.api_config import api_config_bp
from routes.api_stats import api_stats_bp
from routes.api_users import api_users_bp
from routes.api_database import api_database_bp
from routes.api_calibration import api_calibration_bp
from routes.api_snapshot_download import api_snapshot_download_bp


def register_routes(app):
    app.register_blueprint(auth_bp)
    app.register_blueprint(page_bp)
    app.register_blueprint(api_traps_bp)
    app.register_blueprint(api_downloads_bp)
    app.register_blueprint(api_snapshots_bp)
    app.register_blueprint(api_config_bp)
    app.register_blueprint(api_stats_bp)
    app.register_blueprint(api_users_bp)
    app.register_blueprint(api_database_bp)
    app.register_blueprint(api_calibration_bp)
    app.register_blueprint(api_snapshot_download_bp)
