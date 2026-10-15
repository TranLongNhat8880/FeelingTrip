const { test } = require('node:test');
const assert = require('node:assert/strict');

// No database, migration, network or provider calls. SQL is inspected, not run.
const dbPath = require.resolve('../src/config/database');
const db = { query: async () => { throw new Error('Unexpected database access'); } };
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
const repo = require('../src/features/reviews/reviews.repository');
const service = require('../src/features/reviews/reviews.service');
const controller = require('../src/features/reviews/reviews.controller');
const v = require('../src/features/reviews/reviews.validation');
const tripId = '11111111-1111-4111-8111-111111111111';
const authorId = '22222222-2222-4222-8222-222222222222';
const review = { id: '33333333-3333-4333-8333-333333333333',
  rating: 5, comment: 'Lịch trình tốt', created_at: '2026-10-15T00:00:00Z',
  reviewer: { id: authorId, displayName: 'Người đã đi', avatarUrl: null,
    phone: 'PRIVATE_PHONE', email: 'PRIVATE_EMAIL' }, reviewee_id: null,
};
const row = { trip_id: tripId, review_count: 2, average_rating: '4.50', items: [review] };

test('one read snapshot gates PUBLIC COMPLETED, excludes member reviews in both aggregates and items', async t => {
  t.mock.method(db, 'query', async (sql, params) => {
    assert.deepEqual(params, [tripId, 20, 40]);
    assert.match(sql, /t.id = \$1 AND t.privacy_type = 'PUBLIC' AND t.status = 'COMPLETED'/);
    assert.equal((sql.match(/r.reviewee_id IS NULL/g) || []).length, 2);
    assert.match(sql, /ORDER BY r.created_at DESC, r.id DESC/);
    assert.match(sql, /LIMIT \$2 OFFSET \$3/);
    assert.match(sql, /AVG\(r.rating\)/);
    assert.doesNotMatch(sql, /trip_members|original_trip_id|u\.phone|u\.email|u\.dob|u\.role|SELECT \*/);
    assert.ok(!sql.includes(tripId));
    return { rows: [row] };
  });
  assert.deepEqual(await repo.findPublicTripReviews({ tripId, page: 3, limit: 20 }), row);
});

test('source review DTO exposes only safe author fields and whole-trip summary', async t => {
  t.mock.method(repo, 'findPublicTripReviews', async args => {
    assert.deepEqual(args, { tripId, page: 1, limit: 1 });
    return row;
  });
  const result = await service.getTripReviews({ tripId, limit: 1 });
  assert.equal(result.averageRating, 4.5);
  assert.equal(result.reviewCount, 2);
  assert.deepEqual(result.pagination, { page: 1, limit: 1, total: 2, totalPages: 2 });
  assert.deepEqual(result.items[0].reviewer, { id: authorId, displayName: 'Người đã đi', avatarUrl: null });
  assert.equal(result.items[0].tripId, tripId);
  assert.equal(JSON.stringify(result).includes('PRIVATE_'), false);
  assert.equal(Object.hasOwn(result.items[0], 'reviewee_id'), false);
});

test('no reviews is a successful empty result, not a missing trip', async t => {
  t.mock.method(repo, 'findPublicTripReviews', async () => ({ ...row,
    review_count: 0, average_rating: '0', items: [] }));
  assert.deepEqual(await service.getTripReviews({ tripId }), {
    tripId, averageRating: 0, reviewCount: 0, items: [],
    pagination: { page: 1, limit: 20, total: 0, totalPages: 0 },
  });
});

test('page beyond last stays empty and retains total and average', async t => {
  t.mock.method(repo, 'findPublicTripReviews', async () => ({ ...row, items: [] }));
  const result = await service.getTripReviews({ tripId, page: 5 });
  assert.equal(result.items.length, 0);
  assert.equal(result.reviewCount, 2);
  assert.equal(result.averageRating, 4.5);
  assert.equal(result.pagination.page, 5);
});

test('rating-only review stays visible with null comment', async t => {
  t.mock.method(repo, 'findPublicTripReviews', async () => ({ ...row,
    items: [{ ...review, comment: null }] }));
  assert.equal((await service.getTripReviews({ tripId })).items[0].comment, null);
});

test('inaccessible or unknown trip is 404; no fallback to cloned/source trip or membership', async t => {
  t.mock.method(db, 'query', async () => ({ rows: [] }));
  assert.equal(await repo.findPublicTripReviews({ tripId, page: 1, limit: 20 }), null);
  await assert.rejects(service.getTripReviews({ tripId }), { status: 404 });
});

test('controller uses trip path and validated pagination, not supplied reviewer/target IDs', async t => {
  t.mock.method(service, 'getTripReviews', async args => {
    assert.deepEqual(args, { tripId, page: 2, limit: 10 });
    return { items: [] };
  });
  const res = { status(code) { assert.equal(code, 200); return this; },
    json(body) { assert.deepEqual(body.data, { items: [] }); return this; } };
  await controller.getTripReviews({ params: { id: tripId },
    query: { page: 2, limit: 10, revieweeId: authorId } }, res, error => { throw error; });
});

test('read pagination validates UUID, bounded integers and defaults', () => {
  assert.deepEqual(v.tripReviewsQuerySchema.validate({}).value, { page: 1, limit: 20 });
  assert.deepEqual(v.tripReviewsQuerySchema.validate({ page: '2', limit: '10' }).value, { page: 2, limit: 10 });
  for (const query of [{ page: 0 }, { page: -1 }, { page: 1.5 }, { page: 100001 },
    { limit: 0 }, { limit: 51 }, { page: 'bad' }]) {
    assert.ok(v.tripReviewsQuerySchema.validate(query).error);
  }
  assert.ok(v.idParamSchema.validate({ id: 'bad' }).error);
});

test('GET route requires authentication and rejects bad input before repository', async t => {
  const authPath = require.resolve('../src/shared/middlewares/auth.middleware');
  const uploadPath = require.resolve('../src/shared/middlewares/upload.middleware');
  require.cache[authPath] = { id: authPath, filename: authPath, loaded: true,
    exports: (req, res, next) => req.headers.authorization === 'Bearer test'
      ? next() : res.status(401).json({ success: false }) };
  require.cache[uploadPath] = { id: uploadPath, filename: uploadPath, loaded: true,
    exports: { single: () => (req, res, next) => next() } };
  const router = require('../src/features/reviews/reviews.routes');
  let accessible = true;
  const lookup = t.mock.method(repo, 'findPublicTripReviews', async args => {
    assert.equal(args.tripId, tripId);
    return accessible ? row : null;
  });
  // Invoke Express router directly; no listening port or outgoing HTTP required.
  const get = (path, authenticated = true) => new Promise((resolve, reject) => {
    const url = new URL(path, 'http://test.invalid');
    const req = { method: 'GET', url: path, originalUrl: path,
      headers: authenticated ? { authorization: 'Bearer test' } : {},
      query: Object.fromEntries(url.searchParams) };
    const res = { statusCode: 200, status(code) { this.statusCode = code; return this; },
      json(body) { resolve({ status: this.statusCode, body }); return this; } };
    router.handle(req, res, error => {
      if (error) resolve({ status: error.status, body: null });
      else reject(new Error('Route did not handle request'));
    });
  });
  assert.equal((await get(`/trip/${tripId}`, false)).status, 401);
  assert.equal(lookup.mock.callCount(), 0);
  assert.equal((await get('/trip/invalid')).status, 400);
  assert.equal((await get(`/trip/${tripId}?limit=99`)).status, 400);
  assert.equal(lookup.mock.callCount(), 0);
  const result = await get(`/trip/${tripId}`);
  assert.equal(result.status, 200);
  assert.equal(result.body.data.items[0].comment, review.comment);
  accessible = false;
  assert.equal((await get(`/trip/${tripId}`)).status, 404);
});
