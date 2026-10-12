const { test } = require('node:test');
const assert = require('node:assert/strict');

// Unit tests only: no DB, external requests, or actual API credentials.
const envPath = require.resolve('../src/config/env');
require.cache[envPath] = {
  id: envPath, filename: envPath, loaded: true,
  exports: { geoapifyApiKey: 'unit-test-key' },
};
const service = require('../src/features/places/geocoding.service');

test('geocoding forwards only sanitized structured address fields', async t => {
  t.mock.method(global, 'fetch', async url => {
    assert.equal(url.hostname, 'api.geoapify.com');
    assert.equal(url.searchParams.get('apiKey'), 'unit-test-key');
    return { ok: true, status: 200, json: async () => ({ features: [
      { properties: { lat: 21.028, lon: 105.852, state: ' Hà Nội ',
        country_code: 'vn', county: 'Hoàn Kiếm', suburb: 'Phường Hoàn Kiếm',
        street: 'Lê Thái Tổ', housenumber: '1', city: { malicious: true },
        apiKey: 'must-not-leak', datasource: { url: 'must-not-leak' } } },
      { properties: { lat: 999, lon: 105 } },
    ] }) };
  });
  const result = await service.reverse(21.028, 105.852);
  assert.equal(result.features.length, 1);
  assert.deepEqual(result.features[0].properties, {
    lat: 21.028, lon: 105.852, state: 'Hà Nội', country_code: 'vn',
    county: 'Hoàn Kiếm', suburb: 'Phường Hoàn Kiếm',
    street: 'Lê Thái Tổ', housenumber: '1',
  });
  assert.ok(!JSON.stringify(result).includes('must-not-leak'));
});

test('missing administrative labels remain missing instead of being invented', async t => {
  t.mock.method(global, 'fetch', async () => ({ ok: true, status: 200,
    json: async () => ({ features: [{ properties: { name: 'Point' },
      geometry: { coordinates: [105, 21] } }] }),
  }));
  const result = await service.search('Point');
  assert.deepEqual(result.features[0].properties, { lat: 21, lon: 105, name: 'Point' });
});
