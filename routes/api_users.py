from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from werkzeug.security import generate_password_hash
from models import db, User

api_users_bp = Blueprint('api_users', __name__)


@api_users_bp.route('/api/users', methods=['GET'])
@jwt_required()
def get_users():
    users = User.query.all()
    return jsonify([{
        'id': u.id, 'username': u.username, 'created_at': str(u.created_at)
    } for u in users])


@api_users_bp.route('/api/users', methods=['POST'])
@jwt_required()
def create_user():
    data = request.get_json()
    username = data.get('username', '')
    password = data.get('password', '')
    if not username or not password:
        return jsonify({'error': 'Имя пользователя и пароль обязательны'}), 400
    if User.query.filter_by(username=username).first():
        return jsonify({'error': 'Пользователь уже существует'}), 400
    user = User(username=username, password_hash=generate_password_hash(password))
    db.session.add(user)
    db.session.commit()
    return jsonify({'message': 'Пользователь создан', 'id': user.id})


@api_users_bp.route('/api/users/<int:id>', methods=['PUT'])
@jwt_required()
def update_user(id):
    user = User.query.get_or_404(id)
    data = request.get_json()
    if 'password' in data and data['password']:
        user.password_hash = generate_password_hash(data['password'])
    db.session.commit()
    return jsonify({'message': 'Пользователь обновлен'})


@api_users_bp.route('/api/users/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_user(id):
    user = User.query.get_or_404(id)
    if user.username == 'admin':
        return jsonify({'error': 'Нельзя удалить пользователя admin'}), 400
    db.session.delete(user)
    db.session.commit()
    return jsonify({'message': 'Пользователь удален'})
