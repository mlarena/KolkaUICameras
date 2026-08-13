from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from models import db, PhotoTrap

api_traps_bp = Blueprint('api_traps', __name__)


@api_traps_bp.route('/api/traps', methods=['GET'])
@jwt_required()
def get_traps():
    traps = PhotoTrap.query.all()
    return jsonify([{
        'Id': t.Id, 'Name': t.Name, 'MacAddress': t.MacAddress,
        'WifiSSID': t.WifiSSID, 'Description': t.Description,
        'Latitude': float(t.Latitude) if t.Latitude else None,
        'Longitude': float(t.Longitude) if t.Longitude else None,
        'IsActive': t.IsActive, 'CreatedAt': str(t.CreatedAt), 'UpdatedAt': str(t.UpdatedAt)
    } for t in traps])


@api_traps_bp.route('/api/traps/<int:id>', methods=['PUT'])
@jwt_required()
def update_trap(id):
    trap = PhotoTrap.query.get_or_404(id)
    data = request.get_json()
    if 'Description' in data:
        trap.Description = data['Description']
    if 'Latitude' in data:
        trap.Latitude = data['Latitude']
    if 'Longitude' in data:
        trap.Longitude = data['Longitude']
    if 'IsActive' in data:
        trap.IsActive = data['IsActive']
    db.session.commit()
    return jsonify({'message': 'Обновлено'})
