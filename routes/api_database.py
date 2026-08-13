from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from sqlalchemy import text
from models import db

api_database_bp = Blueprint('api_database', __name__)


@api_database_bp.route('/api/database/truncate', methods=['POST'])
@jwt_required()
def truncate_database():
    data = request.get_json()
    confirm = data.get('confirm', '')
    if confirm != 'TRUNCATE':
        return jsonify({'error': 'Введите TRUNCATE для подтверждения'}), 400
    try:
        db.session.execute(text('TRUNCATE TABLE public."PhotoTrap" RESTART IDENTITY CASCADE'))
        db.session.execute(text('TRUNCATE TABLE public."DownloadLog" RESTART IDENTITY'))
        db.session.execute(text('TRUNCATE TABLE public."SnapshotLog" RESTART IDENTITY'))
        db.session.execute(text('TRUNCATE TABLE public."CalibrationLog" RESTART IDENTITY'))
        db.session.commit()
        return jsonify({'message': 'База данных очищена'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': f'Ошибка: {str(e)}'}), 500
