(async () => {
  const datasourceName = null; // например: 'Prometheus' или 'Mimir'. null = авто-поиск
  const start = null; // например: '2025-03-01T00:00:00Z'
  const end = null;   // например: '2025-03-11T23:59:59Z'
  const fileName = 'metrics.txt';

  const getJson = async (url) => {
    const res = await fetch(url, { credentials: 'same-origin' });
    const text = await res.text();

    if (!res.ok) {
      throw new Error(`HTTP ${res.status} ${res.statusText} @ ${url}\n${text.slice(0, 500)}`);
    }

    try {
      return JSON.parse(text);
    } catch {
      throw new Error(`Ответ не JSON @ ${url}\n${text.slice(0, 500)}`);
    }
  };

  const datasources = await getJson('/api/datasources');

  const ds =
    (datasourceName && datasources.find((d) => d.name === datasourceName)) ||
    datasources.find((d) => /prometheus|mimir/i.test(`${d.name} ${d.type}`));

  if (!ds) {
    console.error('Datasource не найден. Доступные datasource:');
    console.table(datasources.map(({ id, uid, name, type, url }) => ({ id, uid, name, type, url })));
    return;
  }

  const params = new URLSearchParams();
  if (start) params.set('start', start);
  if (end) params.set('end', end);

  const apiPath = `/api/v1/label/__name__/values${params.toString() ? `?${params}` : ''}`;

  const candidateUrls = [
    ds.uid ? `/api/datasources/proxy/uid/${encodeURIComponent(ds.uid)}${apiPath}` : null,
    ds.id != null ? `/api/datasources/proxy/${ds.id}${apiPath}` : null,
  ].filter(Boolean);

  let payload = null;
  let usedUrl = null;
  let lastError = null;

  for (const url of candidateUrls) {
    try {
      payload = await getJson(url);
      usedUrl = url;
      break;
    } catch (err) {
      lastError = err;
    }
  }

  if (!payload) {
    throw lastError || new Error('Не удалось получить список метрик');
  }

  if (!Array.isArray(payload.data)) {
    throw new Error(`Неожиданный ответ API: ${JSON.stringify(payload).slice(0, 500)}`);
  }

  const metrics = [...new Set(payload.data)].sort((a, b) => a.localeCompare(b));
  const text = metrics.join('\n');

  try {
    if (typeof copy === 'function') {
      copy(text);
    } else if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
    }
  } catch (err) {
    console.warn('Не удалось скопировать в буфер:', err);
  }

  const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = fileName;
  a.style.display = 'none';
  document.body.appendChild(a);
  a.click();

  setTimeout(() => {
    URL.revokeObjectURL(a.href);
    a.remove();
  }, 1000);

  console.log(`Datasource: ${ds.name} (uid=${ds.uid}, id=${ds.id}, type=${ds.type})`);
  console.log(`URL: ${usedUrl}`);
  console.log(`Метрик: ${metrics.length}`);
  console.log(metrics.slice(0, 100).join('\n'));
})().catch((err) => {
  console.error('Ошибка:', err);
});
