from flask import Blueprint, request, jsonify, redirect, url_for, flash, render_template
from flask_jwt_extended import create_access_token, unset_jwt_cookies
from werkzeug.security import check_password_hash
from models import db, User

auth_bp = Blueprint('auth', __name__)


@auth_bp.route('/')
def index():
    return redirect(url_for('page.dashboard'))


@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        data = request.get_json() if request.is_json else request.form
        username = data.get('username', '')
        password = data.get('password', '')
        user = User.query.filter_by(username=username).first()
        if user and check_password_hash(user.password_hash, password):
            token = create_access_token(identity=str(user.id))
            if request.is_json:
                return jsonify({'token': token, 'redirect': '/dashboard'})
            return redirect(url_for('page.dashboard'))
        if request.is_json:
            return jsonify({'error': 'Неверное имя пользователя или пароль'}), 401
        flash('Неверное имя пользователя или пароль', 'error')
    return render_template('login.html')


@auth_bp.route('/logout', methods=['POST'])
def logout():
    response = redirect(url_for('auth.login'))
    unset_jwt_cookies(response)
    response.delete_cookie('token')
    return response
