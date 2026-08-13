from flask import Blueprint, render_template

page_bp = Blueprint('page', __name__)


@page_bp.route('/dashboard')
def dashboard():
    return render_template('dashboard.html')
