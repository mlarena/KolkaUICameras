from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required
from datetime import date
from models import db, PhotoTrap, DownloadLog, SnapshotLog

api_stats_bp = Blueprint('api_stats', __name__)


@api_stats_bp.route('/api/stats', methods=['GET'])
@jwt_required()
def get_stats():
    today = date.today()
    download_errors = DownloadLog.query.filter(
        db.func.date(DownloadLog.DownloadedAt) == today,
        DownloadLog.IsSuccess == False
    ).count()
    snapshot_errors = SnapshotLog.query.filter(
        db.func.date(SnapshotLog.CreatedAt) == today,
        SnapshotLog.ErrorMessage.isnot(None),
        SnapshotLog.ErrorMessage != ''
    ).count()
    return jsonify({
        'traps_count': PhotoTrap.query.count(),
        'active_traps': PhotoTrap.query.filter_by(IsActive=True).count(),
        'downloads_today': DownloadLog.query.filter(
            db.func.date(DownloadLog.DownloadedAt) == today
        ).count(),
        'errors_today': download_errors + snapshot_errors
    })
