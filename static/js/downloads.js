async function loadDownloadLogs() {
    const trap = document.getElementById('dl-trap-filter').value;
    const status = document.getElementById('dl-status-filter').value;
    const dateFrom = document.getElementById('dl-date-from').value;
    const dateTo = document.getElementById('dl-date-to').value;
    const params = new URLSearchParams({ page: currentPage.downloads, per_page: 15, sort: 'Id', dir: 'desc' });
    if (trap) params.set('mac_address', trap);
    if (status) params.set('is_success', status);
    if (dateFrom) params.set('date_from', dateFrom.replace('T', ' '));
    if (dateTo) params.set('date_to', dateTo.replace('T', ' '));
    const [data, traps] = await Promise.all([api.get(`/api/download-logs?${params}`), api.get('/api/traps')]);
    if (!data) return;
    const trapMap = {};
    if (traps) traps.forEach(t => trapMap[t.Id] = t);
    document.getElementById('downloads-info').textContent = `Найдено: ${data.total} записей`;
    let html = `<div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead class="table-light">
        <tr><th>ID</th><th>Ловушка</th><th>Файл</th><th>Статус</th><th class="d-none d-md-table-cell">Удалён</th><th class="d-none d-md-table-cell">Отправлен</th><th>Загружено</th></tr>
    </thead><tbody>`;
    data.items.forEach(l => {
        const t = trapMap[l.PhotoTrapId];
        const trapLabel = t ? [t.MacAddress, t.WifiSSID, t.Description].filter(Boolean).join(' | ') : l.PhotoTrapId;
        html += `<tr>
            <td>${l.Id}</td>
            <td><code class="small" title="${trapLabel}">${trapLabel || l.PhotoTrapId}</code></td>
            <td class="text-truncate" style="max-width:200px" title="${l.FilePath || ''}">${l.FileName || '-'}</td>
            <td><span class="badge ${l.IsSuccess ? 'bg-success' : 'bg-danger'}">${l.IsSuccess ? 'OK' : 'Ошибка'}</span></td>
            <td class="d-none d-md-table-cell"><span class="badge ${l.IsDeleted ? 'bg-warning' : 'bg-secondary'}">${l.IsDeleted ? 'Да' : 'Нет'}</span></td>
            <td class="d-none d-md-table-cell"><span class="badge ${l.IsSent ? 'bg-info' : 'bg-secondary'}">${l.IsSent ? 'Да' : 'Нет'}</span></td>
            <td class="small">${l.DownloadedAt}</td>
        </tr>`;
    });
    html += '</tbody></table></div>';
    document.getElementById('downloads-table').innerHTML = html;
    renderPagination('downloads', data);
}

function clearDownloadFilters() {
    document.getElementById('dl-trap-filter').value = '';
    document.getElementById('dl-status-filter').value = '';
    document.getElementById('dl-date-from')._flatpickr.clear();
    document.getElementById('dl-date-to')._flatpickr.clear();
    const container = document.getElementById('dl-quick-dates');
    if (container) container.querySelectorAll('.quick-date-btn').forEach(b => {
        b.classList.remove('active', 'btn-primary');
        b.classList.add('btn-outline-secondary');
    });
    currentPage.downloads = 1;
    loadDownloadLogs();
}
