from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from datetime import datetime
from models import db, PhotoTrap, DownloadLog

api_downloads_bp = Blueprint('api_downloads', __name__)


@api_downloads_bp.route('/api/download-logs', methods=['GET'])
@jwt_required()
def get_download_logs():
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)
    sort_by = request.args.get('sort', 'DownloadedAt')
    sort_dir = request.args.get('dir', 'desc')
    mac_address = request.args.get('mac_address', type=str)
    is_success = request.args.get('is_success', type=str)
    date_from = request.args.get('date_from', type=str)
    date_to = request.args.get('date_to', type=str)

    query = DownloadLog.query

    if mac_address:
        trap = PhotoTrap.query.filter_by(MacAddress=mac_address).first()
        if trap:
            query = query.filter_by(PhotoTrapId=trap.Id)
        else:
            query = query.filter_by(PhotoTrapId=-1)

    if is_success is not None:
        query = query.filter_by(IsSuccess=is_success.lower() == 'true')

    if date_from:
        try:
            dt_from = datetime.strptime(date_from, '%Y-%m-%d %H:%M')
            query = query.filter(DownloadLog.DownloadedAt >= dt_from)
        except ValueError:
            try:
                dt_from = datetime.strptime(date_from, '%Y-%m-%d')
                query = query.filter(DownloadLog.DownloadedAt >= dt_from)
            except ValueError:
                pass

    if date_to:
        try:
            dt_to = datetime.strptime(date_to, '%Y-%m-%d %H:%M').replace(second=59)
            query = query.filter(DownloadLog.DownloadedAt <= dt_to)
        except ValueError:
            try:
                dt_to = datetime.strptime(date_to, '%Y-%m-%d').replace(hour=23, minute=59, second=59)
                query = query.filter(DownloadLog.DownloadedAt <= dt_to)
            except ValueError:
                pass

    sort_col = getattr(DownloadLog, sort_by, DownloadLog.DownloadedAt)
    query = query.order_by(sort_col.desc() if sort_dir == 'desc' else sort_col.asc())
    pagination = query.paginate(page=page, per_page=per_page, error_out=False)

    return jsonify({
        'items': [{
            'Id': l.Id, 'PhotoTrapId': l.PhotoTrapId, 'FileName': l.FileName,
            'FilePath': l.FilePath, 'FileSize': l.FileSize, 'TimeCode': l.TimeCode,
            'FileTime': str(l.FileTime) if l.FileTime else None, 'IsSuccess': l.IsSuccess,
            'IsDeleted': l.IsDeleted, 'IsSent': l.IsSent,
            'ErrorMessage': l.ErrorMessage, 'LocalPath': l.LocalPath,
            'DownloadedAt': str(l.DownloadedAt)
        } for l in pagination.items],
        'total': pagination.total, 'pages': pagination.pages, 'current_page': page
    })
