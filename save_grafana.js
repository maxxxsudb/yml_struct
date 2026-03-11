// Прямо в консоли браузера на странице Grafana
const ds = "YOUR_DATASOURCE_UID";
const resp = await fetch(`/api/datasources/proxy/uid/${ds}/api/v1/label/__name__/values`);
const data = await resp.json();
console.log(data.data.join("\n"));
// или скопировать в буфер:
copy(data.data.join("\n"));
