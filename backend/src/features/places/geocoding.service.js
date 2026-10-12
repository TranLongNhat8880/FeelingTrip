const env = require('../../config/env');
const apiError = require('../../shared/utils/apiError.util');

const tiles = new Map();
const pendingTiles = new Map();
const tileTtl = 10 * 60 * 1000;
const isConfigured = () => Boolean(env.geoapifyApiKey);

const request = async (host, path, parameters) => {
  if (!isConfigured()) throw apiError(503, 'Dịch vụ bản đồ chưa được cấu hình trên máy chủ');
  const url = new URL(path, `https://${host}`);
  for (const [key, value] of Object.entries(parameters)) url.searchParams.set(key, value);
  url.searchParams.set('apiKey', env.geoapifyApiKey);
  let response;
  try {
    response = await fetch(url, { signal: AbortSignal.timeout(10000), redirect: 'error' });
  } catch {
    throw apiError(502, 'Không kết nối được dịch vụ bản đồ. Vui lòng thử lại');
  }
  if (response.status === 429) throw apiError(429, 'Dịch vụ bản đồ đang giới hạn lượt gọi. Vui lòng thử lại sau');
  if (!response.ok) throw apiError(502, 'Dịch vụ bản đồ tạm thời không khả dụng');
  return response;
};

const geocode = async (path, parameters) => {
  const response = await request('api.geoapify.com', path,
    { format: 'geojson', lang: 'vi', limit: '5', ...parameters });
  let body;
  try { body = await response.json(); }
  catch { throw apiError(502, 'Dịch vụ bản đồ trả dữ liệu không hợp lệ'); }
  if (!Array.isArray(body?.features)) throw apiError(502, 'Dịch vụ bản đồ trả dữ liệu không hợp lệ');
  // Return only location fields, never provider headers, URLs or credentials.
  return { features: body.features.flatMap(feature => {
    const p = feature?.properties || {};
    const lon = p.lon ?? feature?.geometry?.coordinates?.[0];
    const lat = p.lat ?? feature?.geometry?.coordinates?.[1];
    if (!Number.isFinite(lat) || !Number.isFinite(lon) ||
        lat < -90 || lat > 90 || lon < -180 || lon > 180) return [];
    const properties = { lat, lon };
    // Explicit whitelist: address components help the admin form match the
    // selected administrative dataset, without exposing provider internals.
    for (const key of ['place_id', 'name', 'formatted', 'address_line1',
      'country_code', 'state', 'county', 'city', 'district', 'suburb',
      'quarter', 'street', 'housenumber']) {
      if (typeof p[key] === 'string' && p[key].trim()) {
        properties[key] = p[key].trim();
      }
    }
    return [{ properties }];
  }) };
};

const search = text => geocode('/v1/geocode/autocomplete', { text, filter: 'countrycode:vn' });
const reverse = (lat, lon) => geocode('/v1/geocode/reverse', { lat, lon, limit: '1' });

const tile = async (z, x, y) => {
  if (x >= 2 ** z || y >= 2 ** z) throw apiError(400, 'Ô bản đồ không hợp lệ');
  const key = `${z}/${x}/${y}`;
  const cached = tiles.get(key);
  if (cached && cached.expires > Date.now()) {
    tiles.delete(key);
    tiles.set(key, cached);
    return cached.bytes;
  }
  if (pendingTiles.has(key)) return pendingTiles.get(key);
  const task = (async () => {
    const response = await request('maps.geoapify.com', `/v1/tile/osm-carto/${key}.png`, {});
    if (!response.headers.get('content-type')?.startsWith('image/png')) {
      throw apiError(502, 'Dịch vụ bản đồ trả ảnh không hợp lệ');
    }
    let bytes;
    try { bytes = Buffer.from(await response.arrayBuffer()); }
    catch { throw apiError(502, 'Không tải được ảnh bản đồ'); }
    if (!bytes.length || bytes.length > 1024 * 1024) throw apiError(502, 'Ảnh bản đồ không hợp lệ');
    tiles.delete(key);
    tiles.set(key, { bytes, expires: Date.now() + tileTtl });
    while (tiles.size > 200) tiles.delete(tiles.keys().next().value);
    return bytes;
  })();
  pendingTiles.set(key, task);
  try { return await task; }
  finally { pendingTiles.delete(key); }
};

module.exports = { isConfigured, search, reverse, tile };
