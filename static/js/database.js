function showTruncateModal() {
    document.getElementById('modal-title').textContent = 'Очистка базы данных';
    document.getElementById('edit-form').innerHTML = `
        <div class="alert alert-danger">
            <strong>Внимание! Это действие необратимо!</strong><br>
            <small>Будут удалены все данные из таблиц: PhotoTrap, DownloadLog, SnapshotLog, CalibrationLog.</small>
        </div>
        <div class="mb-3">
            <label class="form-label">Введите TRUNCATE для подтверждения</label>
            <input type="text" name="confirm" required placeholder="TRUNCATE" class="form-control">
        </div>
        <div class="modal-footer px-0 pb-0">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Отмена</button>
            <button type="submit" class="btn btn-danger">Очистить</button>
        </div>`;
    document.getElementById('edit-form').onsubmit = async (e) => {
        e.preventDefault();
        const confirmText = new FormData(e.target).get('confirm');
        if (confirmText !== 'TRUNCATE') { alert('Введите TRUNCATE для подтверждения'); return; }
        const result = await api.post('/api/database/truncate', { confirm: confirmText });
        if (result && !result.error) { closeModal(); alert('База данных очищена'); loadStats(); }
        else alert(result.error || 'Ошибка очистки');
    };
    showModal();
}
