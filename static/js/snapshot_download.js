let sdEventSource = null;

function updateSdStatusUI(status, running) {
    const statusEl = document.getElementById('sd-status');
    const startBtn = document.getElementById('sd-start-btn');
    const stopBtn = document.getElementById('sd-stop-btn');
    if (!statusEl || !startBtn) return;
    if (running) {
        statusEl.textContent = status === 'running' || status === 'starting' ? 'Выполняется...' : status;
        statusEl.className = 'text-warning small';
        startBtn.disabled = true;
        if (stopBtn) stopBtn.classList.remove('d-none');
    } else {
        if (status === 'completed') {
            statusEl.textContent = 'Завершено';
            statusEl.className = 'text-success small';
        } else if (status && status.startsWith('error')) {
            statusEl.textContent = status;
            statusEl.className = 'text-danger small';
        } else {
            statusEl.textContent = 'Готово';
            statusEl.className = 'text-muted small';
        }
        startBtn.disabled = false;
        if (stopBtn) stopBtn.classList.add('d-none');
    }
}

function appendSdLines(lines) {
    const logEl = document.getElementById('sd-log');
    const container = document.getElementById('sd-log-container');
    if (!logEl) return;
    if (logEl.textContent === 'Ожидание запуска...') logEl.textContent = '';
    if (logEl.textContent) logEl.textContent += '\n';
    logEl.textContent += lines.join('\n');
    if (container) container.scrollTop = container.scrollHeight;
}

function setSdLog(text) {
    const logEl = document.getElementById('sd-log');
    if (logEl) logEl.textContent = text;
}

function connectSdSSE() {
    disconnectSdSSE();
    const token = localStorage.getItem('token');
    if (!token) return;
    sdEventSource = new EventSource('/api/snapshot-download/stream?token=' + encodeURIComponent(token));
    sdEventSource.onmessage = function(e) {
        const msg = JSON.parse(e.data);
        switch (msg.type) {
            case 'init':
                setSdLog(msg.lines.length > 0 ? msg.lines.join('\n') : 'Ожидание запуска...');
                updateSdStatusUI(msg.status, msg.running);
                break;
            case 'log':
                appendSdLines(msg.lines);
                break;
            case 'status':
                updateSdStatusUI(msg.status, msg.running);
                break;
            case 'done':
                updateSdStatusUI(msg.status, false);
                disconnectSdSSE();
                break;
        }
    };
    sdEventSource.onerror = function() { disconnectSdSSE(); };
}

function disconnectSdSSE() {
    if (sdEventSource) { sdEventSource.close(); sdEventSource = null; }
}

async function loadSnapshotDownloadStatus() {
    const data = await api.get('/api/snapshot-download/status');
    if (!data) return;
    updateSdStatusUI(data.status, data.running);
    setSdLog(data.lines && data.lines.length > 0 ? data.lines.join('\n') : 'Ожидание запуска...');
}

async function startSnapshotDownload() {
    const result = await api.post('/api/snapshot-download/start', {});
    if (result && result.error) { alert(result.error); return; }
    setSdLog('');
    updateSdStatusUI('starting', true);
    connectSdSSE();
}

async function stopSnapshotDownload() {
    const result = await api.post('/api/snapshot-download/stop', {});
    if (result && result.error) { alert(result.error); return; }
    updateSdStatusUI('stopping', true);
}
