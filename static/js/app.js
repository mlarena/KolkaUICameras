// Theme management (Bootstrap 5.3 native dark mode)
function getTheme() {
    return localStorage.getItem('bs-theme') || 'light';
}

function setTheme(theme) {
    document.documentElement.setAttribute('data-bs-theme', theme);
    localStorage.setItem('bs-theme', theme);
    updateThemeIcon(theme);
}

function toggleTheme() {
    setTheme(getTheme() === 'dark' ? 'light' : 'dark');
}

function updateThemeIcon(theme) {
    const icon = document.getElementById('theme-icon');
    const text = document.getElementById('theme-text');
    if (icon && text) {
        icon.className = theme === 'dark' ? 'bi bi-sun' : 'bi bi-moon';
        text.textContent = theme === 'dark' ? 'Светлая тема' : 'Тёмная тема';
    }
}

document.addEventListener('DOMContentLoaded', () => {
    setTheme(getTheme());
});

// Navigation
function navigateTab(tab) {
    const offcanvas = document.getElementById('sidebarOffcanvas');
    if (offcanvas) {
        const bsOffcanvas = bootstrap.Offcanvas.getInstance(offcanvas);
        if (bsOffcanvas) bsOffcanvas.hide();
    }
    if (typeof switchTab === 'function') {
        switchTab(tab);
    } else {
        window.location.href = '/dashboard#' + tab;
    }
}

// Auth
function checkAuth() {
    const token = localStorage.getItem('token');
    if (!token) {
        window.location.href = '/login';
        return false;
    }
    return true;
}

const api = {
    headers: () => ({ 'Authorization': `Bearer ${localStorage.getItem('token')}`, 'Content-Type': 'application/json' }),
    get: async (url) => {
        if (!checkAuth()) return null;
        const r = await fetch(url, { headers: api.headers() });
        if (r.status === 401) { localStorage.removeItem('token'); window.location.href = '/login'; return null; }
        return r.json();
    },
    put: async (url, data) => {
        if (!checkAuth()) return null;
        const r = await fetch(url, { method: 'PUT', headers: api.headers(), body: JSON.stringify(data) });
        if (r.status === 401) { localStorage.removeItem('token'); window.location.href = '/login'; return null; }
        return r.json();
    },
    post: async (url, data) => {
        if (!checkAuth()) return null;
        const r = await fetch(url, { method: 'POST', headers: api.headers(), body: JSON.stringify(data) });
        if (r.status === 401) { localStorage.removeItem('token'); window.location.href = '/login'; return null; }
        return r.json();
    },
    delete: async (url) => {
        if (!checkAuth()) return null;
        const r = await fetch(url, { method: 'DELETE', headers: api.headers() });
        if (r.status === 401) { localStorage.removeItem('token'); window.location.href = '/login'; return null; }
        return r.json();
    }
};

// Modal
function closeModal() {
    const modal = document.getElementById('editModal');
    if (modal) {
        const bsModal = bootstrap.Modal.getInstance(modal);
        if (bsModal) bsModal.hide();
    }
}

function showModal() {
    const modal = document.getElementById('editModal');
    if (modal) {
        let bsModal = bootstrap.Modal.getInstance(modal);
        if (!bsModal) bsModal = new bootstrap.Modal(modal);
        bsModal.show();
    }
}

// Stats
async function loadStats() {
    const stats = await api.get('/api/stats');
    if (!stats) return;
    document.getElementById('stat-traps').textContent = stats.traps_count;
    document.getElementById('stat-active').textContent = stats.active_traps;
    document.getElementById('stat-downloads').textContent = stats.downloads_today;
    document.getElementById('stat-errors').textContent = stats.errors_today;
}

// Tab switching
let currentPage = { downloads: 1, snapshots: 1 };
let cachedTraps = null;

function switchTab(tab) {
    cachedTraps = null;
    document.querySelectorAll('.tab-content-item').forEach(el => el.classList.add('d-none'));
    // Sidebar nav
    document.querySelectorAll('.offcanvas .nav-link, aside .nav-link').forEach(el => {
        el.classList.remove('active');
    });
    document.querySelectorAll(`[data-tab="${tab}"]`).forEach(el => el.classList.add('active'));
    const tabEl = document.getElementById(`tab-${tab}`);
    if (tabEl) tabEl.classList.remove('d-none');
    window.history.replaceState(null, null, `#${tab}`);
    loadStats();
    if (tab === 'traps') loadTraps();
    else if (tab === 'downloads') { loadTraps().then(() => loadDownloadLogs()); }
    else if (tab === 'snapshots') { loadTraps().then(() => loadSnapshotLogs()); }
    else if (tab === 'config') loadConfig();
    else if (tab === 'users') loadUsers();
    else if (tab === 'calibration') loadCalibrationStatus();
    else if (tab === 'snapshot-download') loadSnapshotDownloadStatus();
    // test-data tab is static, no loader needed
}

// Pagination
function renderPagination(type, data) {
    if (data.pages <= 1) {
        const el = document.getElementById(`${type}-pagination`);
        if (el) el.innerHTML = '';
        const topEl = document.getElementById(`${type}-pagination-top`);
        if (topEl) topEl.innerHTML = '';
        return;
    }
    const btn = (page, label, disabled) =>
        `<button class="btn btn-sm btn-outline-secondary ${disabled ? 'disabled' : ''}" ${disabled ? 'disabled' : ''} onclick="goToPage('${type}', ${page})">${label}</button>`;
    const html = `<div class="d-flex align-items-center justify-content-center gap-1 py-2">
        ${btn(1, '&laquo;', currentPage[type] === 1)}
        ${btn(currentPage[type] - 1, '&lsaquo;', currentPage[type] === 1)}
        <span class="btn btn-sm btn-secondary disabled">${data.current_page} / ${data.pages}</span>
        ${btn(currentPage[type] + 1, '&rsaquo;', currentPage[type] === data.pages)}
        ${btn(data.pages, '&raquo;', currentPage[type] === data.pages)}
    </div>`;
    const el = document.getElementById(`${type}-pagination`);
    if (el) el.innerHTML = html;
    const topEl = document.getElementById(`${type}-pagination-top`);
    if (topEl) topEl.innerHTML = html;
}

function changePage(type, delta) {
    currentPage[type] += delta;
    if (type === 'downloads') loadDownloadLogs();
    else if (type === 'snapshots') loadSnapshotLogs();
}

function goToPage(type, page) {
    currentPage[type] = page;
    if (type === 'downloads') loadDownloadLogs();
    else if (type === 'snapshots') loadSnapshotLogs();
}

// Quick date buttons
const dayNames = ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
const monthNames = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];

function makeStartOfDay(d) { const s = new Date(d); s.setHours(0, 0, 0, 0); return s; }
function makeEndOfDay(d) { const s = new Date(d); s.setHours(23, 59, 0, 0); return s; }

function generateQuickDateButtons(containerId, prefix) {
    const container = document.getElementById(containerId);
    if (!container) return;
    const today = new Date();
    const buttons = [];
    buttons.push({ label: 'Сегодня', dateFrom: makeStartOfDay(today), dateTo: makeEndOfDay(today) });
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    buttons.push({ label: 'Вчера', dateFrom: makeStartOfDay(yesterday), dateTo: makeEndOfDay(yesterday) });
    for (let i = 2; i <= 6; i++) {
        const d = new Date(today);
        d.setDate(d.getDate() - i);
        buttons.push({ label: `${dayNames[d.getDay()]} ${d.getDate()} ${monthNames[d.getMonth()]}`, dateFrom: makeStartOfDay(d), dateTo: makeEndOfDay(d) });
    }
    container.innerHTML = buttons.map((btn, idx) =>
        `<button type="button" onclick="applyQuickDate('${prefix}', ${idx})" class="btn btn-sm btn-outline-secondary quick-date-btn" data-idx="${idx}">${btn.label}</button>`
    ).join('');
    container._buttons = buttons;
}

function applyQuickDate(prefix, idx) {
    const container = document.getElementById(`${prefix}-quick-dates`);
    if (!container || !container._buttons) return;
    const btn = container._buttons[idx];
    if (!btn) return;
    const dateFrom = document.getElementById(`${prefix}-date-from`);
    const dateTo = document.getElementById(`${prefix}-date-to`);
    if (dateFrom && dateFrom._flatpickr) dateFrom._flatpickr.setDate(btn.dateFrom, true);
    if (dateTo && dateTo._flatpickr) dateTo._flatpickr.setDate(btn.dateTo, true);
    container.querySelectorAll('.quick-date-btn').forEach(b => {
        b.classList.remove('active');
        b.classList.remove('btn-primary');
        b.classList.add('btn-outline-secondary');
    });
    const activeBtn = container.querySelector(`[data-idx="${idx}"]`);
    if (activeBtn) {
        activeBtn.classList.add('active');
        activeBtn.classList.remove('btn-outline-secondary');
        activeBtn.classList.add('btn-primary');
    }
    currentPage[prefix === 'dl' ? 'downloads' : 'snapshots'] = 1;
    if (prefix === 'dl') loadDownloadLogs();
    else loadSnapshotLogs();
}

