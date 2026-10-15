const { test } = require('node:test');
const assert = require('node:assert/strict');

// Retirement regression only: no database, network, migrations or messages.
const dbPath = require.resolve('../src/config/database');
const db = { query: async () => { throw new Error('Unexpected database access'); } };
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
const repo = require('../src/features/reviews/reviews.repository');
const service = require('../src/features/reviews/reviews.service');
const controller = require('../src/features/reviews/reviews.controller');
const validation = require('../src/features/reviews/reviews.validation');
const userId = '11111111-1111-4111-8111-111111111111';
const contactId = '22222222-2222-4222-8222-222222222222';

test('retired feature no longer has callable controllers, services, SQL functions or validation', () => {
  for (const module of [repo, service, controller, validation]) {
    assert.equal(Object.keys(module).some(key => /sos/i.test(key)), false);
  }
});

test('retired endpoints are not routed; emergency contacts CRUD remains available', async t => {
  const authPath = require.resolve('../src/shared/middlewares/auth.middleware');
  const uploadPath = require.resolve('../src/shared/middlewares/upload.middleware');
  require.cache[authPath] = { id: authPath, filename: authPath, loaded: true,
    exports: (req, res, next) => { req.user = { id: userId }; next(); } };
  require.cache[uploadPath] = { id: uploadPath, filename: uploadPath, loaded: true,
    exports: { single: () => (req, res, next) => next() } };
  const router = require('../src/features/reviews/reviews.routes');
  const row = { id: contactId, full_name: 'Người liên hệ', phone: '0912345678', relationship: null };
  t.mock.method(repo, 'findEmergencyContacts', async id => { assert.equal(id, userId); return [row]; });
  t.mock.method(repo, 'createEmergencyContact', async data => { assert.equal(data.userId, userId); return row; });
  t.mock.method(repo, 'updateEmergencyContact', async data => { assert.equal(data.userId, userId); return row; });
  t.mock.method(repo, 'deleteEmergencyContact', async data => { assert.equal(data.userId, userId); return row; });
  const request = (method, path, body = {}) => new Promise((resolve, reject) => {
    const req = { method, url: path, originalUrl: path, body, query: {}, headers: {} };
    const res = { statusCode: 200, status(code) { this.statusCode = code; return this; },
      json(value) { resolve({ status: this.statusCode, body: value }); return this; } };
    router.handle(req, res, error => {
      if (error) reject(error);
      else resolve({ status: 404, body: null });
    });
  });
  for (const [method, path] of [['POST', '/sos'], ['GET', '/sos/active'],
    ['GET', '/sos/history'], ['PUT', `/sos/${contactId}/status`]]) {
    assert.equal((await request(method, path)).status, 404);
  }
  assert.equal((await request('GET', '/emergency-contacts')).body.data[0].fullName, row.full_name);
  assert.equal((await request('POST', '/emergency-contacts', {
    fullName: row.full_name, phone: row.phone,
  })).status, 201);
  assert.equal((await request('PUT', `/emergency-contacts/${contactId}`, { fullName: 'Tên mới' })).status, 200);
  assert.equal((await request('DELETE', `/emergency-contacts/${contactId}`)).status, 200);
});
