const CONFIG_BOOLEAN_KEYS = ['NeedCalibration', 'DeleteAfterDownload', 'CompressAfterDownload'];
const CONFIG_PATH_KEYS = ['DownloadPath'];
const CONFIG_NUMBER_KEYS = [
    'CamerasCount', 'BleScanTimeout', 'BleCommandTimeout', 'WifiWaitAfterOpen',
    'WifiConnectTimeout', 'CloseWaitSeconds', 'RetryDelay', 'MaxRetriesPerCamera',
    'MaxScanRetries', 'CameraCooldown', 'CompressQuality', 'WifiDownloadRetries',
    'SnapshotIntervalMinutes'
];

function getConfigInputType(key) {
    if (CONFIG_BOOLEAN_KEYS.includes(key)) return 'boolean';
    if (CONFIG_PATH_KEYS.includes(key)) return 'path';
    if (CONFIG_NUMBER_KEYS.includes(key)) return 'number';
    return 'text';
}

function isValidPath(val) {
    // Linux: /... or relative ./...
    // Windows: C:\... or \\server\...
    return /^(\/[^<>:"|?*]+|[A-Za-z]:\\[^<>:"|?*]+|\\\\[^<>:"|?*]+|\.\.?\/.+)$/.test(val);
}

function validateConfigValue(key, val) {
    const type = getConfigInputType(key);
    if (type === 'boolean') {
        return val === 'true' || val === 'false';
    }
    if (type === 'path') {
        return val.trim() !== '' && isValidPath(val.trim());
    }
    if (type === 'number') {
        return val !== '' && !isNaN(parseFloat(val)) && isFinite(val);
    }
    return true;
}

function getConfigValidationError(key, val) {
    const type = getConfigInputType(key);
    if (type === 'boolean') return null;
    if (type === 'path') {
        if (!val.trim()) return 'Путь не может быть пустым';
        if (!isValidPath(val.trim())) return 'Введите валидный путь (Linux: /path или Windows: C:\\path)';
        return null;
    }
    if (type === 'number') {
        if (val === '') return 'Значение обязательно';
        if (isNaN(parseFloat(val)) || !isFinite(val)) return 'Введите число';
        return null;
    }
    return null;
}

async function loadConfig() {
    const configs = await api.get('/api/config');
    if (!configs) return;
    let html = `<div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead class="table-light">
        <tr><th>Ключ</th><th>Значение</th><th class="d-none d-md-table-cell">Описание</th><th>Действия</th></tr>
    </thead><tbody>`;
    configs.forEach(c => {
        const type = getConfigInputType(c.Key);
        let valueDisplay = c.Value;
        if (type === 'boolean') {
            valueDisplay = c.Value === 'true'
                ? '<span class="badge bg-success">true</span>'
                : '<span class="badge bg-secondary">false</span>';
        } else {
            valueDisplay = `<code class="small text-truncate d-inline-block" style="max-width:300px">${c.Value}</code>`;
        }
        html += `<tr>
            <td><code class="small">${c.Key}</code></td>
            <td>${valueDisplay}</td>
            <td class="d-none d-md-table-cell text-muted">${c.Description || '-'}</td>
            <td><button onclick='editConfig(${JSON.stringify(c)})' class="btn btn-sm btn-outline-primary">Изменить</button></td>
        </tr>`;
    });
    html += '</tbody></table></div>';
    document.getElementById('config-table').innerHTML = html;
}

function editConfig(config) {
    const type = getConfigInputType(config.Key);
    let inputHtml = '';

    if (type === 'boolean') {
        inputHtml = `
            <select name="Value" class="form-select">
                <option value="true" ${config.Value === 'true' ? 'selected' : ''}>true</option>
                <option value="false" ${config.Value === 'false' ? 'selected' : ''}>false</option>
            </select>`;
    } else if (type === 'path') {
        inputHtml = `
            <input type="text" name="Value" value="${config.Value}" class="form-control"
                   placeholder="/path/to/dir или C:\\path\\to\\dir">
            <div class="form-text">Примеры: <code>/opt/KolkaUICameras/images</code>, <code>C:\\Photos\\trap</code></div>`;
    } else if (type === 'number') {
        inputHtml = `
            <input type="number" step="any" name="Value" value="${config.Value}" class="form-control">`;
    } else {
        inputHtml = `
            <input type="text" name="Value" value="${config.Value}" class="form-control">`;
    }

    document.getElementById('modal-title').textContent = `Редактирование: ${config.Key}`;
    document.getElementById('edit-form').innerHTML = `
        <div class="mb-3">
            <label class="form-label">Значение</label>
            ${inputHtml}
            <div id="config-error" class="invalid-feedback d-none"></div>
        </div>
        <div class="mb-3">
            <label class="form-label">Описание</label>
            <p class="text-muted small mb-0">${config.Description || '-'}</p>
        </div>
        <div class="modal-footer px-0 pb-0">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Отмена</button>
            <button type="submit" class="btn btn-primary">Сохранить</button>
        </div>`;

    document.getElementById('edit-form').onsubmit = async (e) => {
        e.preventDefault();
        const val = new FormData(e.target).get('Value');
        const errorEl = document.getElementById('config-error');
        const inputEl = e.target.querySelector('[name="Value"]');

        const error = getConfigValidationError(config.Key, val);
        if (error) {
            errorEl.textContent = error;
            errorEl.classList.remove('d-none');
            inputEl.classList.add('is-invalid');
            return;
        }

        errorEl.classList.add('d-none');
        inputEl.classList.remove('is-invalid');
        await api.put(`/api/config/${config.Id}`, { Value: val });
        closeModal();
        loadConfig();
        loadStats();
    };

    showModal();
}
