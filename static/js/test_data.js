/*  test_data.js — Test data generation tab logic */

async function generateTestData() {
    const btn = document.getElementById('td-generate-btn');
    const resultEl = document.getElementById('td-result');
    if (!btn) return;

    btn.disabled = true;
    btn.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span> Генерация...';
    if (resultEl) {
        resultEl.innerHTML = '';
        resultEl.className = '';
    }

    try {
        const data = await api.post('/api/test-data/generate', {});
        if (!data) return;

        if (data.error) {
            if (resultEl) {
                resultEl.className = 'alert alert-danger mt-3 mb-0';
                resultEl.textContent = data.error;
            }
            return;
        }

        let html = '';
        if (data.success) {
            html += '<div class="alert alert-success mt-3 mb-0">';
            html += '<strong>' + data.message + '</strong>';
            html += '<br><small class="text-muted">Метка времени: ' + data.date + '</small>';
            html += '</div>';
        } else {
            html += '<div class="alert alert-warning mt-3 mb-0">';
            html += '<strong>Частичная ошибка</strong>';
            if (data.errors) {
                html += '<ul class="mb-0 mt-1">';
                data.errors.forEach(function(err) { html += '<li>' + err + '</li>'; });
                html += '</ul>';
            }
            html += '</div>';
        }

        if (data.copied && data.copied.length > 0) {
            html += '<div class="mt-2"><small class="text-muted">Скопированные файлы:</small>';
            html += '<ul class="list-unstyled mb-0 mt-1">';
            data.copied.forEach(function(f) {
                html += '<li><code>' + f + '</code></li>';
            });
            html += '</ul></div>';
        }

        if (resultEl) resultEl.innerHTML = html;
    } catch (e) {
        if (resultEl) {
            resultEl.className = 'alert alert-danger mt-3 mb-0';
            resultEl.textContent = 'Ошибка: ' + e.message;
        }
    } finally {
        btn.disabled = false;
        btn.innerHTML = '<i class="bi bi-lightning"></i> Сгенерировать тестовые данные';
    }
}
