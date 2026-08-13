async function loadSnapshotLogs() {
    const trap = document.getElementById('snap-trap-filter').value;
    const status = document.getElementById('snap-status-filter').value;
    const hasError = document.getElementById('snap-error-filter').value;
    const dateFrom = document.getElementById('snap-date-from').value;
    const dateTo = document.getElementById('snap-date-to').value;
    const activityType = document.getElementById('snap-activity-filter').value;
    const params = new URLSearchParams({ page: currentPage.snapshots, per_page: 15, sort: 'Id', dir: 'desc' });
    if (trap) params.set('mac_address', trap);
    if (status) params.set('status', status);
    if (hasError) params.set('has_error', hasError);
    if (activityType) params.set('activity_type', activityType);
    if (dateFrom) params.set('date_from', dateFrom.replace('T', ' '));
    if (dateTo) params.set('date_to', dateTo.replace('T', ' '));
    const [data, traps] = await Promise.all([api.get(`/api/snapshot-logs?${params}`), api.get('/api/traps')]);
    if (!data) return;
    const trapMap = {};
    if (traps) traps.forEach(t => trapMap[t.Id] = t);
    document.getElementById('snapshots-info').textContent = `Найдено: ${data.total} записей`;
    const statusColors = { 'PENDING': 'bg-warning', 'OK': 'bg-success', 'ERROR': 'bg-danger' };
    let html = `<div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead class="table-light">
        <tr><th>ID</th><th>Тип</th><th>Ловушка</th><th>Цикл</th><th>Начало</th><th class="d-none d-md-table-cell">Конец</th><th>Файл</th><th>Статус</th><th class="d-none d-lg-table-cell">Сообщение</th></tr>
    </thead><tbody>`;
    data.items.forEach(l => {
        const t = trapMap[l.PhotoTrapId];
        const trapLabel = t ? [t.MacAddress, t.WifiSSID, t.Description].filter(Boolean).join(' | ') : l.PhotoTrapId;
        const messageText = (l.ErrorMessage || l.LogMessage || '-').replace(/;/g, '<br>');
        const formatDT = (str) => str ? str.substring(0, 19) : '-';
        html += `<tr>
            <td>${l.Id}</td>
            <td><span class="badge ${l.ActivityType === 'download' ? 'bg-warning' : 'bg-info'}">${l.ActivityType === 'download' ? 'Загрузка' : 'Фото'}</span></td>
            <td><code class="small" title="${trapLabel}">${trapLabel || l.PhotoTrapId}</code></td>
            <td>${l.CycleNumber ?? '-'}</td>
            <td class="small">${formatDT(l.StartTime)}</td>
            <td class="d-none d-md-table-cell small">${formatDT(l.EndTime)}</td>
            <td class="small text-truncate" style="max-width:150px" title="${l.FileName || ''}">${l.FileName || '-'}</td>
            <td><span class="badge ${statusColors[l.Status] || 'bg-secondary'}">${l.Status || '-'}</span></td>
            <td class="d-none d-lg-table-cell small" style="white-space:normal;word-break:break-word">${messageText}</td>
        </tr>`;
    });
    html += '</tbody></table></div>';
    document.getElementById('snapshots-table').innerHTML = html;
    renderPagination('snapshots', data);
}

function clearSnapshotFilters() {
    document.getElementById('snap-trap-filter').value = '';
    document.getElementById('snap-status-filter').value = '';
    document.getElementById('snap-error-filter').value = '';
    document.getElementById('snap-activity-filter').value = '';
    document.getElementById('snap-date-from')._flatpickr.clear();
    document.getElementById('snap-date-to')._flatpickr.clear();
    const container = document.getElementById('snap-quick-dates');
    if (container) container.querySelectorAll('.quick-date-btn').forEach(b => {
        b.classList.remove('active', 'btn-primary');
        b.classList.add('btn-outline-secondary');
    });
    currentPage.snapshots = 1;
    loadSnapshotLogs();
}
