async function loadTraps() {
    if (!cachedTraps) {
        cachedTraps = await api.get('/api/traps');
    }
    const traps = cachedTraps;
    if (!traps) return;
    const filterSelects = [document.getElementById('dl-trap-filter'), document.getElementById('snap-trap-filter')];
    filterSelects.forEach(sel => {
        if (sel) {
            const val = sel.value;
            sel.innerHTML = '<option value="">Все ловушки</option>' + traps.map(t => {
                const label = [t.MacAddress, t.WifiSSID, t.Description].filter(Boolean).join(' | ');
                return `<option value="${t.MacAddress || t.Id}">${label || t.Name}</option>`;
            }).join('');
            sel.value = val;
        }
    });
    let html = `<div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead class="table-light">
        <tr>
            <th>ID</th><th>Название</th><th>MAC</th>
            <th class="d-none d-md-table-cell">WiFi</th>
            <th class="d-none d-lg-table-cell">Описание</th>
            <th class="d-none d-lg-table-cell">Коорд.</th>
            <th>Статус</th><th>Действия</th>
        </tr></thead><tbody>`;
    traps.forEach(t => {
        html += `<tr>
            <td>${t.Id}</td>
            <td class="fw-medium">${t.Name}</td>
            <td><code class="small">${t.MacAddress || '-'}</code></td>
            <td class="d-none d-md-table-cell">${t.WifiSSID || '-'}</td>
            <td class="d-none d-lg-table-cell text-truncate" style="max-width:200px">${t.Description || '-'}</td>
            <td class="d-none d-lg-table-cell">${t.Latitude ? `${t.Latitude}, ${t.Longitude}` : '-'}</td>
            <td><span class="badge ${t.IsActive ? 'bg-success' : 'bg-secondary'}">${t.IsActive ? 'Активна' : 'Неактивна'}</span></td>
            <td><button onclick='editTrap(${JSON.stringify(t)})' class="btn btn-sm btn-outline-primary">Изменить</button></td>
        </tr>`;
    });
    html += '</tbody></table></div>';
    document.getElementById('traps-table').innerHTML = html;
}

function editTrap(trap) {
    document.getElementById('modal-title').textContent = `Редактирование: ${trap.Name}`;
    document.getElementById('edit-form').innerHTML = `
        <div class="mb-3">
            <label class="form-label">Описание</label>
            <textarea name="Description" rows="3" class="form-control">${trap.Description || ''}</textarea>
        </div>
        <div class="row g-3 mb-3">
            <div class="col-6">
                <label class="form-label">Широта</label>
                <input type="number" step="any" name="Latitude" value="${trap.Latitude || ''}" class="form-control">
            </div>
            <div class="col-6">
                <label class="form-label">Долгота</label>
                <input type="number" step="any" name="Longitude" value="${trap.Longitude || ''}" class="form-control">
            </div>
        </div>
        <div class="mb-3">
            <label class="form-label">Статус</label>
            <select name="IsActive" class="form-select">
                <option value="true" ${trap.IsActive ? 'selected' : ''}>Активна</option>
                <option value="false" ${!trap.IsActive ? 'selected' : ''}>Неактивна</option>
            </select>
        </div>
        <div class="modal-footer px-0 pb-0">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Отмена</button>
            <button type="submit" class="btn btn-primary">Сохранить</button>
        </div>`;
    document.getElementById('edit-form').onsubmit = async (e) => {
        e.preventDefault();
        const fd = new FormData(e.target);
        await api.put(`/api/traps/${trap.Id}`, {
            Description: fd.get('Description'),
            Latitude: parseFloat(fd.get('Latitude')) || null,
            Longitude: parseFloat(fd.get('Longitude')) || null,
            IsActive: fd.get('IsActive') === 'true'
        });
        closeModal();
        cachedTraps = null;
        loadTraps();
        loadStats();
    };
    showModal();
}
