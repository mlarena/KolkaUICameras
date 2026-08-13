from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from models import db, PhotoTrapConfig

api_config_bp = Blueprint('api_config', __name__)


@api_config_bp.route('/api/config', methods=['GET'])
@jwt_required()
def get_config():
    configs = PhotoTrapConfig.query.order_by(PhotoTrapConfig.Id.asc()).all()
    return jsonify([{
        'Id': c.Id, 'Key': c.Key, 'Value': c.Value,
        'Description': c.Description, 'CreatedAt': str(c.CreatedAt), 'UpdatedAt': str(c.UpdatedAt)
    } for c in configs])


@api_config_bp.route('/api/config/<int:id>', methods=['PUT'])
@jwt_required()
def update_config(id):
    config = PhotoTrapConfig.query.get_or_404(id)
    data = request.get_json()
    if 'Value' in data:
        config.Value = data['Value']
    db.session.commit()
    return jsonify({'message': 'Обновлено'})
