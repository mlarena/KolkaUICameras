from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from datetime import datetime
from models import db, PhotoTrap, SnapshotLog

api_snapshots_bp = Blueprint('api_snapshots', __name__)


@api_snapshots_bp.route('/api/snapshot-logs', methods=['GET'])
@jwt_required()
def get_snapshot_logs():
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    sort_by = request.args.get('sort', 'CreatedAt')
    sort_dir = request.args.get('dir', 'desc')
    mac_address = request.args.get('mac_address', type=str)
    status = request.args.get('status', type=str)
    activity_type = request.args.get('activity_type', type=str)
    has_error = request.args.get('has_error', type=str)
    date_from = request.args.get('date_from', type=str)
    date_to = request.args.get('date_to', type=str)

    query = SnapshotLog.query

    if mac_address:
        trap = PhotoTrap.query.filter_by(MacAddress=mac_address).first()
        if trap:
            query = query.filter_by(PhotoTrapId=trap.Id)
        else:
            query = query.filter_by(PhotoTrapId=-1)

    if status:
        query = query.filter_by(Status=status)

    if activity_type:
        query = query.filter_by(ActivityType=activity_type)

    if has_error == 'true':
        query = query.filter(SnapshotLog.ErrorMessage.isnot(None), SnapshotLog.ErrorMessage != '')
    elif has_error == 'false':
        query = query.filter(
            db.or_(SnapshotLog.ErrorMessage.is_(None), SnapshotLog.ErrorMessage == '')
        )

    if date_from:
        try:
            dt_from = datetime.strptime(date_from, '%Y-%m-%d %H:%M')
            query = query.filter(SnapshotLog.CreatedAt >= dt_from)
        except ValueError:
            try:
                dt_from = datetime.strptime(date_from, '%Y-%m-%d')
                query = query.filter(SnapshotLog.CreatedAt >= dt_from)
            except ValueError:
                pass

    if date_to:
        try:
            dt_to = datetime.strptime(date_to, '%Y-%m-%d %H:%M').replace(second=59)
            query = query.filter(SnapshotLog.CreatedAt <= dt_to)
        except ValueError:
            try:
                dt_to = datetime.strptime(date_to, '%Y-%m-%d').replace(hour=23, minute=59, second=59)
                query = query.filter(SnapshotLog.CreatedAt <= dt_to)
            except ValueError:
                pass

    sort_col = getattr(SnapshotLog, sort_by, SnapshotLog.CreatedAt)
    query = query.order_by(sort_col.desc() if sort_dir == 'desc' else sort_col.asc())
    pagination = query.paginate(page=page, per_page=per_page, error_out=False)

    return jsonify({
        'items': [{
            'Id': l.Id, 'PhotoTrapId': l.PhotoTrapId,
            'CycleNumber': l.CycleNumber,
            'StartTime': str(l.StartTime), 'EndTime': str(l.EndTime) if l.EndTime else None,
            'FileName': l.FileName, 'Status': l.Status,
            'LogMessage': l.LogMessage, 'ErrorMessage': l.ErrorMessage,
            'CreatedAt': str(l.CreatedAt), 'ActivityType': l.ActivityType
        } for l in pagination.items],
        'total': pagination.total, 'pages': pagination.pages, 'current_page': page
    })
