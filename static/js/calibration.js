let calEventSource = null;

// ── localStorage persistence ────────────────────────────────────────────────

const CAL_LINES_KEY = 'calibration_lines';
const CAL_META_KEY = 'calibration_meta';

function calSave(lines, status, running) {
    try {
        localStorage.setItem(CAL_LINES_KEY, JSON.stringify(lines));
        localStorage.setItem(CAL_META_KEY, JSON.stringify({ status: status || 'idle', running: !!running }));
    } catch (e) { /* quota */ }
}

function calLoad() {
    try {
        return {
            lines: JSON.parse(localStorage.getItem(CAL_LINES_KEY) || '[]'),
            status: (JSON.parse(localStorage.getItem(CAL_META_KEY) || '{}')).status || 'idle',
            running: !!(JSON.parse(localStorage.getItem(CAL_META_KEY) || '{}')).running
        };
    } catch { return { lines: [], status: 'idle', running: false }; }
}

function calClear() {
    localStorage.removeItem(CAL_LINES_KEY);
    localStorage.removeItem(CAL_META_KEY);
}

// ── DOM helpers ─────────────────────────────────────────────────────────────

function calGetEls() {
    return {
        log: document.getElementById('cal-log'),
        box: document.getElementById('cal-log-container'),
        start: document.getElementById('cal-start-btn'),
        stop: document.getElementById('cal-stop-btn'),
        status: document.getElementById('cal-status'),
    };
}

function calRender(lines) {
    const { log, box } = calGetEls();
    if (!log) return;
    log.textContent = lines.length ? lines.join('\n') : 'Ожидание запуска...';
    if (box) box.scrollTop = box.scrollHeight;
}

function calAppend(newLines) {
    const { log, box } = calGetEls();
    if (!log) return;
    if (log.textContent === 'Ожидание запуска...') log.textContent = '';
    if (log.textContent && newLines.length) log.textContent += '\n';
    log.textContent += newLines.join('\n');
    if (box) box.scrollTop = box.scrollHeight;
}

function calStatusUI(status, running) {
    const { start, stop, status: s } = calGetEls();
    if (!start) return;
    if (running) {
        start.disabled = true;
        start.innerHTML = '<i class="bi bi-hourglass-split"></i> Выполняется...';
        s.textContent = status === 'running' || status === 'starting' ? 'Выполняется...' : status;
        s.className = 'text-warning small';
        if (stop) stop.classList.remove('d-none');
    } else {
        start.disabled = false;
        start.innerHTML = '<i class="bi bi-broadcast"></i> Запустить калибровку';
        if (stop) stop.classList.add('d-none');
        if (status === 'completed') {
            s.textContent = 'Завершена';
            s.className = 'text-success small';
        } else if (status && status.startsWith('error')) {
            s.textContent = status;
            s.className = 'text-danger small';
        } else {
            s.textContent = 'Готова';
            s.className = 'text-muted small';
        }
    }
}

// ── SSE ─────────────────────────────────────────────────────────────────────

function connectCalSSE() {
    disconnectCalSSE();
    const token = localStorage.getItem('token');
    if (!token) return;
    calEventSource = new EventSource('/api/calibration/stream?token=' + encodeURIComponent(token));
    calEventSource.onmessage = function(e) {
        let msg;
        try { msg = JSON.parse(e.data); } catch { return; }
        switch (msg.type) {
            case 'init': {
                const cached = calLoad();
                if (cached.lines.length > 0) {
                    calRender(cached.lines);
                } else if (msg.lines.length > 0) {
                    calRender(msg.lines);
                    calSave(msg.lines, msg.status, msg.running);
                }
                calStatusUI(msg.status, msg.running);
                break;
            }
            case 'log': {
                const cached = calLoad();
                const all = cached.lines.concat(msg.lines);
                calAppend(msg.lines);
                calSave(all, cached.status, cached.running);
                break;
            }
            case 'status': {
                calStatusUI(msg.status, msg.running);
                const cached = calLoad();
                calSave(cached.lines, msg.status, msg.running);
                break;
            }
            case 'done': {
                calStatusUI(msg.status, false);
                const cached = calLoad();
                calSave(cached.lines, msg.status, false);
                disconnectCalSSE();
                break;
            }
        }
    };
    calEventSource.onerror = function() {
        if (calEventSource && calEventSource.readyState === EventSource.CLOSED) disconnectCalSSE();
    };
}

function disconnectCalSSE() {
    if (calEventSource) { calEventSource.close(); calEventSource = null; }
}

// ── API calls ───────────────────────────────────────────────────────────────

async function loadCalibrationStatus() {
    const data = await api.get('/api/calibration/logs');
    if (!data) return;
    if (data.running) {
        connectCalSSE();
    } else {
        const cached = calLoad();
        if (cached.lines.length > 0) {
            calRender(cached.lines);
        } else if (data.lines && data.lines.length > 0) {
            calRender(data.lines);
            calSave(data.lines, data.status, data.running);
        }
    }
    calStatusUI(data.status, data.running);
}

async function startCalibration() {
    const { start } = calGetEls();
    if (start) {
        start.disabled = true;
        start.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Запуск...';
    }
    try {
        const result = await api.post('/api/calibration/start', {});
        if (result && result.error) {
            alert(result.error);
            if (start) { start.disabled = false; start.innerHTML = '<i class="bi bi-broadcast"></i> Запустить калибровку'; }
            return;
        }
        calClear();
        calRender([]);
        calStatusUI('running', true);
        connectCalSSE();
    } catch (e) {
        alert('Ошибка запуска: ' + e.message);
        if (start) { start.disabled = false; start.innerHTML = '<i class="bi bi-broadcast"></i> Запустить калибровку'; }
    }
}

async function stopCalibration() {
    const result = await api.post('/api/calibration/stop', {});
    if (result && result.error) { alert(result.error); return; }
    calStatusUI('stopping', true);
}
