async function loadUsers() {
    const users = await api.get('/api/users');
    if (!users) return;
    document.getElementById('users-info').textContent = `Пользователей: ${users.length}`;
    let html = `<div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead class="table-light">
        <tr><th>ID</th><th>Имя пользователя</th><th class="d-none d-md-table-cell">Создан</th><th>Действия</th></tr>
    </thead><tbody>`;
    users.forEach(u => {
        const isAdmin = u.username === 'admin';
        html += `<tr>
            <td>${u.id}</td>
            <td class="fw-medium">${u.username} ${isAdmin ? '<small class="text-muted">(admin)</small>' : ''}</td>
            <td class="d-none d-md-table-cell small">${u.created_at}</td>
            <td>
                <div class="d-flex gap-2">
                    <button onclick='editUser(${JSON.stringify(u)})' class="btn btn-sm btn-outline-primary">Изменить</button>
                    ${!isAdmin ? `<button onclick="deleteUser(${u.id}, '${u.username}')" class="btn btn-sm btn-outline-danger">Удалить</button>` : ''}
                </div>
            </td>
        </tr>`;
    });
    html += '</tbody></table></div>';
    document.getElementById('users-table').innerHTML = html;
}

function showCreateUserModal() {
    document.getElementById('modal-title').textContent = 'Новый пользователь';
    document.getElementById('edit-form').innerHTML = `
        <div class="mb-3">
            <label class="form-label">Имя пользователя</label>
            <input type="text" name="username" required class="form-control">
        </div>
        <div class="mb-3">
            <label class="form-label">Пароль</label>
            <input type="password" name="password" required class="form-control">
        </div>
        <div class="modal-footer px-0 pb-0">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Отмена</button>
            <button type="submit" class="btn btn-primary">Создать</button>
        </div>`;
    document.getElementById('edit-form').onsubmit = async (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        const result = await api.post('/api/users', { username: fd.get('username'), password: fd.get('password') });
        if (result && !result.error) { closeModal(); loadUsers(); }
        else alert(result.error || 'Ошибка создания');
    };
    showModal();
}

function editUser(user) {
    document.getElementById('modal-title').textContent = `Изменить: ${user.username}`;
    document.getElementById('edit-form').innerHTML = `
        <div class="mb-3">
            <label class="form-label">Имя пользователя</label>
            <input type="text" value="${user.username}" disabled class="form-control">
        </div>
        <div class="mb-3">
            <label class="form-label">Новый пароль (оставьте пустым чтобы не менять)</label>
            <input type="password" name="password" class="form-control">
        </div>
        <div class="modal-footer px-0 pb-0">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Отмена</button>
            <button type="submit" class="btn btn-primary">Сохранить</button>
        </div>`;
    document.getElementById('edit-form').onsubmit = async (e) => {
        e.preventDefault();
        const password = new FormData(e.target).get('password');
        if (password) {
            const result = await api.put(`/api/users/${user.id}`, { password });
            if (result && !result.error) closeModal();
            else alert(result.error || 'Ошибка обновления');
        } else closeModal();
    };
    showModal();
}

async function deleteUser(id, username) {
    if (!confirm(`Удалить пользователя "${username}"?`)) return;
    const result = await api.delete(`/api/users/${id}`);
    if (result && !result.error) loadUsers();
    else alert(result.error || 'Ошибка удаления');
}
