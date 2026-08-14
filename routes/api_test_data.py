"""
API для генерации тестовых данных.

Копирует файлы из fortest/ в /outgoing/, заменяя 'date' в имени файла на текущую дату-время.
"""
import os
import shutil
from datetime import datetime

from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required

api_test_data_bp = Blueprint('api_test_data', __name__)

# Путь к корню проекта (где лежит app.py и fortest/)
APP_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Каталог с тестовыми файлами
FORTEST_DIR = os.path.join(APP_ROOT, 'fortest')

# Базовый путь для outgoing (серверный путь по умолчанию)
OUTGOING_BASE = '/outgoing'

# Маппинг: имя подкаталога в fortest/ → имя подкаталога в outgoing/
CATEGORIES = {
    'actinometry': 'actinometry',
    'cameratrap': 'cameratrap',
    'meteo': 'meteo',
    'official_information': 'official_information',
}


@api_test_data_bp.route('/api/test-data/generate', methods=['POST'])
@jwt_required()
def generate_test_data():
    """Копирует тестовые файлы из fortest/ в outgoing/, заменяя 'date' на текущую дату."""
    now = datetime.now()
    date_str = now.strftime('%Y%m%d_%H%M%S')

    results = []
    errors = []

    for src_dir_name, dst_dir_name in CATEGORIES.items():
        src_dir = os.path.join(FORTEST_DIR, src_dir_name)
        dst_dir = os.path.join(OUTGOING_BASE, dst_dir_name)

        if not os.path.isdir(src_dir):
            errors.append(f'Каталог-источник не найден: {src_dir}')
            continue

        if not os.path.isdir(dst_dir):
            try:
                os.makedirs(dst_dir, exist_ok=True)
            except Exception as e:
                errors.append(f'Не удалось создать {dst_dir}: {e}')
                continue

        for filename in os.listdir(src_dir):
            src_file = os.path.join(src_dir, filename)
            if not os.path.isfile(src_file):
                continue

            # Зеняем 'date' на дату-время в имени файла
            new_filename = filename.replace('date', date_str)
            dst_file = os.path.join(dst_dir, new_filename)

            try:
                shutil.copy2(src_file, dst_file)
                results.append(f'{src_dir_name}/{new_filename}')
            except Exception as e:
                errors.append(f'{src_dir_name}/{filename}: {e}')

    if errors:
        return jsonify({
            'success': False,
            'copied': results,
            'errors': errors,
            'date': date_str,
        }), 207

    return jsonify({
        'success': True,
        'copied': results,
        'date': date_str,
        'message': f'Скопировано файлов: {len(results)}',
    })
