let calEventSource = null;

function updateCalStatusUI(status, running) {
    const statusEl = document.getElementById('cal-status');
    const startBtn = document.getElementById('cal-start-btn');
    if (!statusEl || !startBtn) return;
    if (running) {
        statusEl.textContent = status === 'running' || status === 'starting' ? 'Выполняется...' : status;
        statusEl.className = 'text-warning small';
        startBtn.disabled = true;
    } else {
        if (status === 'completed') {
            statusEl.textContent = 'Завершена';
            statusEl.className = 'text-success small';
        } else if (status && status.startsWith('error')) {
            statusEl.textContent = status;
            statusEl.className = 'text-danger small';
        } else {
            statusEl.textContent = 'Готова';
            statusEl.className = 'text-muted small';
        }
        startBtn.disabled = false;
    }
}

function appendCalLines(lines) {
    const logEl = document.getElementById('cal-log');
    const container = document.getElementById('cal-log-container');
    if (!logEl) return;
    if (logEl.textContent === 'Ожидание запуска...') logEl.textContent = '';
    if (logEl.textContent) logEl.textContent += '\n';
    logEl.textContent += lines.join('\n');
    if (container) container.scrollTop = container.scrollHeight;
}

function setCalLog(text) {
    const logEl = document.getElementById('cal-log');
    if (logEl) logEl.textContent = text;
}

function connectCalSSE() {
    disconnectCalSSE();
    const token = localStorage.getItem('token');
    if (!token) return;
    calEventSource = new EventSource('/api/calibration/stream?token=' + encodeURIComponent(token));
    calEventSource.onmessage = function(e) {
        const msg = JSON.parse(e.data);
        switch (msg.type) {
            case 'init':
                setCalLog(msg.lines.length > 0 ? msg.lines.join('\n') : 'Ожидание запуска...');
                updateCalStatusUI(msg.status, msg.running);
                break;
            case 'log':
                appendCalLines(msg.lines);
                break;
            case 'status':
                updateCalStatusUI(msg.status, msg.running);
                break;
            case 'done':
                updateCalStatusUI(msg.status, false);
                disconnectCalSSE();
                break;
        }
    };
    calEventSource.onerror = function() { disconnectCalSSE(); };
}

function disconnectCalSSE() {
    if (calEventSource) { calEventSource.close(); calEventSource = null; }
}

async function loadCalibrationStatus() {
    const data = await api.get('/api/calibration/logs');
    if (!data) return;
    updateCalStatusUI(data.status, data.running);
    setCalLog(data.lines && data.lines.length > 0 ? data.lines.join('\n') : 'Ожидание запуска...');
}

async function startCalibration() {
    const result = await api.post('/api/calibration/start', {});
    if (result && result.error) { alert(result.error); return; }
    setCalLog('');
    updateCalStatusUI('starting', true);
    connectCalSSE();
}

async function stopCalibration() {
    const result = await api.post('/api/calibration/stop', {});
    if (result && result.error) { alert(result.error); return; }
    updateCalStatusUI('stopping', true);
}
