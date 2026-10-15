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

test('retired feature no longer has callable controllers, services, SQL functions or validation', () => {
  for (const module of [repo, service, controller, validation]) {
    assert.equal(Object.keys(module).some(key => /sos|emergency.?contact/i.test(key)), false);
  }
});

test('retired emergency endpoints are not routed', async t => {
  const authPath = require.resolve('../src/shared/middlewares/auth.middleware');
  const uploadPath = require.resolve('../src/shared/middlewares/upload.middleware');
  require.cache[authPath] = { id: authPath, filename: authPath, loaded: true,
    exports: (req, res, next) => { req.user = { id: userId }; next(); } };
  require.cache[uploadPath] = { id: uploadPath, filename: uploadPath, loaded: true,
    exports: { single: () => (req, res, next) => next() } };
  const router = require('../src/features/reviews/reviews.routes');
  const request = (method, path, body = {}) => new Promise((resolve, reject) => {
    const req = { method, url: path, originalUrl: path, body, query: {}, headers: {} };
    const res = { statusCode: 200, status(code) { this.statusCode = code; return this; },
      json(value) { resolve({ status: this.statusCode, body: value }); return this; } };
    router.handle(req, res, error => {
      if (error) reject(error);
      else resolve({ status: 404, body: null });
    });
  });
  for (const [method, path] of [
    ['POST', '/sos'],
    ['GET', '/sos/active'],
    ['GET', '/sos/history'],
    ['PUT', '/sos/22222222-2222-4222-8222-222222222222/status'],
    ['GET', '/emergency-contacts'],
    ['POST', '/emergency-contacts'],
    ['PUT', '/emergency-contacts/22222222-2222-4222-8222-222222222222'],
    ['DELETE', '/emergency-contacts/22222222-2222-4222-8222-222222222222'],
  ]) {
    assert.equal((await request(method, path)).status, 404);
  }
});
