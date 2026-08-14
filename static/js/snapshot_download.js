let sdEventSource = null;

// ── localStorage persistence ────────────────────────────────────────────────

const SD_LINES_KEY = 'snapshot_download_lines';
const SD_META_KEY = 'snapshot_download_meta';

function sdSave(lines, status, running) {
    try {
        localStorage.setItem(SD_LINES_KEY, JSON.stringify(lines));
        localStorage.setItem(SD_META_KEY, JSON.stringify({ status: status || 'idle', running: !!running }));
    } catch (e) { /* quota */ }
}

function sdLoad() {
    try {
        return {
            lines: JSON.parse(localStorage.getItem(SD_LINES_KEY) || '[]'),
            status: (JSON.parse(localStorage.getItem(SD_META_KEY) || '{}')).status || 'idle',
            running: !!(JSON.parse(localStorage.getItem(SD_META_KEY) || '{}')).running
        };
    } catch { return { lines: [], status: 'idle', running: false }; }
}

function sdClear() {
    localStorage.removeItem(SD_LINES_KEY);
    localStorage.removeItem(SD_META_KEY);
}

// ── DOM helpers ─────────────────────────────────────────────────────────────

function sdGetEls() {
    return {
        log: document.getElementById('sd-log'),
        box: document.getElementById('sd-log-container'),
        start: document.getElementById('sd-start-btn'),
        stop: document.getElementById('sd-stop-btn'),
        status: document.getElementById('sd-status'),
    };
}

function sdRender(lines) {
    const { log, box } = sdGetEls();
    if (!log) return;
    log.textContent = lines.length ? lines.join('\n') : 'Ожидание запуска...';
    if (box) box.scrollTop = box.scrollHeight;
}

function sdAppend(newLines) {
    const { log, box } = sdGetEls();
    if (!log) return;
    if (log.textContent === 'Ожидание запуска...') log.textContent = '';
    if (log.textContent && newLines.length) log.textContent += '\n';
    log.textContent += newLines.join('\n');
    if (box) box.scrollTop = box.scrollHeight;
}

function sdStatusUI(status, running) {
    const { start, stop, status: s } = sdGetEls();
    if (!start) return;
    if (running) {
        start.disabled = true;
        start.innerHTML = '<i class="bi bi-hourglass-split"></i> Выполняется...';
        s.textContent = status === 'running' || status === 'starting' ? 'Выполняется...' : status;
        s.className = 'text-warning small';
        if (stop) stop.classList.remove('d-none');
    } else {
        start.disabled = false;
        start.innerHTML = '<i class="bi bi-camera"></i> Запустить снимок + загрузку';
        if (stop) stop.classList.add('d-none');
        if (status === 'completed') {
            s.textContent = 'Завершено';
            s.className = 'text-success small';
        } else if (status && status.startsWith('error')) {
            s.textContent = status;
            s.className = 'text-danger small';
        } else {
            s.textContent = 'Готово';
            s.className = 'text-muted small';
        }
    }
}

// ── SSE ─────────────────────────────────────────────────────────────────────

function connectSdSSE() {
    disconnectSdSSE();
    const token = localStorage.getItem('token');
    if (!token) return;
    sdEventSource = new EventSource('/api/snapshot-download/stream?token=' + encodeURIComponent(token));
    sdEventSource.onmessage = function(e) {
        let msg;
        try { msg = JSON.parse(e.data); } catch { return; }
        switch (msg.type) {
            case 'init': {
                const cached = sdLoad();
                if (cached.lines.length > 0) {
                    sdRender(cached.lines);
                } else if (msg.lines.length > 0) {
                    sdRender(msg.lines);
                    sdSave(msg.lines, msg.status, msg.running);
                }
                sdStatusUI(msg.status, msg.running);
                break;
            }
            case 'log': {
                const cached = sdLoad();
                const all = cached.lines.concat(msg.lines);
                sdAppend(msg.lines);
                sdSave(all, cached.status, cached.running);
                break;
            }
            case 'status': {
                sdStatusUI(msg.status, msg.running);
                const cached = sdLoad();
                sdSave(cached.lines, msg.status, msg.running);
                break;
            }
            case 'done': {
                sdStatusUI(msg.status, false);
                const cached = sdLoad();
                sdSave(cached.lines, msg.status, false);
                disconnectSdSSE();
                break;
            }
        }
    };
    sdEventSource.onerror = function() {
        if (sdEventSource && sdEventSource.readyState === EventSource.CLOSED) disconnectSdSSE();
    };
}

function disconnectSdSSE() {
    if (sdEventSource) { sdEventSource.close(); sdEventSource = null; }
}

// ── API calls ───────────────────────────────────────────────────────────────

async function loadSnapshotDownloadStatus() {
    const data = await api.get('/api/snapshot-download/status');
    if (!data) return;
    if (data.running) {
        connectSdSSE();
    } else {
        const cached = sdLoad();
        if (cached.lines.length > 0) {
            sdRender(cached.lines);
        } else if (data.lines && data.lines.length > 0) {
            sdRender(data.lines);
            sdSave(data.lines, data.status, data.running);
        }
    }
    sdStatusUI(data.status, data.running);
}

async function startSnapshotDownload() {
    const { start } = sdGetEls();
    if (start) {
        start.disabled = true;
        start.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Запуск...';
    }
    try {
        const result = await api.post('/api/snapshot-download/start', {});
        if (result && result.error) {
            alert(result.error);
            if (start) { start.disabled = false; start.innerHTML = '<i class="bi bi-camera"></i> Запустить снимок + загрузку'; }
            return;
        }
        sdClear();
        sdRender([]);
        sdStatusUI('running', true);
        connectSdSSE();
    } catch (e) {
        alert('Ошибка запуска: ' + e.message);
        if (start) { start.disabled = false; start.innerHTML = '<i class="bi bi-camera"></i> Запустить снимок + загрузку'; }
    }
}

async function stopSnapshotDownload() {
    const result = await api.post('/api/snapshot-download/stop', {});
    if (result && result.error) { alert(result.error); return; }
    sdStatusUI('stopping', true);
}
