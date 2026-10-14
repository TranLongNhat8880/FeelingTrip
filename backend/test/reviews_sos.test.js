const { test } = require('node:test');
const assert = require('node:assert/strict');

// Offline only. No real alerts, network, migrations or DB mutations.
const dbPath = require.resolve('../src/config/database');
const db = {
  query: async () => { throw new Error('Unexpected query'); },
  transaction: async () => { throw new Error('Unexpected transaction'); },
};
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
const repo = require('../src/features/reviews/reviews.repository');
const service = require('../src/features/reviews/reviews.service');
const validation = require('../src/features/reviews/reviews.validation');
const controller = require('../src/features/reviews/reviews.controller');
const userId = '11111111-1111-4111-8111-111111111111';
const tripId = '22222222-2222-4222-8222-222222222222';
const row = { id: '33333333-3333-4333-8333-333333333333', user_id: userId, trip_id: tripId,
  latitude: 21, longitude: 105, message: 'Help', status: 'ACTIVE', created_at: new Date(), resolved_at: null };
const payload = { userId, tripId, latitude: 21, longitude: 105, message: 'Help' };

test('ongoing active member can record SOS; service only persists, does not dispatch messages', async t => {
  t.mock.method(repo, 'findSosTripContext', async () => ({ status: 'ONGOING', is_member: true }));
  const create = t.mock.method(repo, 'createSos', async data => { assert.deepEqual(data, payload); return row; });
  assert.equal((await service.createSos(payload)).status, 'ACTIVE');
  assert.equal(create.mock.callCount(), 1);
});

test('left/removed/non-member cannot record trip SOS', async t => {
  t.mock.method(repo, 'findSosTripContext', async () => ({ status: 'ONGOING', is_member: false }));
  const create = t.mock.method(repo, 'createSos', async () => row);
  await assert.rejects(service.createSos(payload), { status: 403 });
  assert.equal(create.mock.callCount(), 0);
});

test('non-ongoing trips cannot create SOS, unknown trip is 404', async t => {
  let context;
  t.mock.method(repo, 'findSosTripContext', async () => context);
  for (const status of ['UPCOMING', 'COMPLETED', 'CANCELLED']) {
    context = { status, is_member: true };
    await assert.rejects(service.createSos(payload), { status: 409 });
  }
  context = null;
  await assert.rejects(service.createSos(payload), { status: 404 });
});

test('active SOS lookup is scoped to authenticated owner and requested trip', async t => {
  t.mock.method(repo, 'findActiveSos', async args => { assert.deepEqual(args, { userId, tripId }); return row; });
  assert.equal((await service.getActiveSos({ userId, tripId })).id, row.id);
});

test('active query is owner-filtered and parameterized', async t => {
  t.mock.method(db, 'query', async (sql, params) => {
    assert.match(sql, /user_id = \$1 AND trip_id IS NOT DISTINCT FROM \$2::UUID AND status = 'ACTIVE'/);
    assert.deepEqual(params, [userId, tripId]);
    return { rows: [row] };
  });
  assert.equal((await repo.findActiveSos({ userId, tripId })).id, row.id);
});

test('membership check uses ACTIVE, keeps only legacy-creator fallback', async t => {
  t.mock.method(db, 'query', async (sql, params) => {
    assert.match(sql, /membership_status='ACTIVE'/);
    assert.match(sql, /creator_id=\$2 AND NOT EXISTS/);
    assert.deepEqual(params, [tripId, userId]);
    return { rows: [] };
  });
  assert.equal(await repo.findSosTripContext({ userId, tripId }), null);
});

test('repeated create reuses active record under a transaction lock', async t => {
  let saved = null, inserts = 0;
  const operations = [];
  t.mock.method(db, 'transaction', async work => work({ query: async (sql) => {
    operations.push(sql);
    if (sql.includes('pg_advisory_xact_lock')) return { rows: [] };
    if (sql.includes('INSERT INTO sos_alerts')) { inserts++; saved = row; return { rows: [row] }; }
    return { rows: saved ? [saved] : [] };
  } }));
  await repo.createSos(payload);
  await repo.createSos(payload);
  assert.equal(inserts, 1);
  assert.match(operations[0], /pg_advisory_xact_lock/);
});

test('ending SOS requires ownership and an ACTIVE record', async t => {
  let existing = null;
  t.mock.method(repo, 'findSosByIdForUser', async () => existing);
  t.mock.method(repo, 'updateSosStatus', async data => ({ ...row, status: data.status }));
  await assert.rejects(service.updateSosStatus({ sosId: row.id, userId, status: 'RESOLVED' }), { status: 404 });
  existing = { ...row, status: 'RESOLVED' };
  await assert.rejects(service.updateSosStatus({ sosId: row.id, userId, status: 'FALSE_ALARM' }), { status: 409 });
  existing = row;
  assert.equal((await service.updateSosStatus({ sosId: row.id, userId, status: 'RESOLVED' })).status, 'RESOLVED');
});

test('validation rejects invalid coordinates/status and validates active query tripId', () => {
  assert.ok(validation.emergencySosSchema.validate({ tripId, latitude: 91, longitude: 105 }).error);
  assert.ok(validation.emergencySosSchema.validate({ tripId, latitude: 21, longitude: -181 }).error);
  assert.ok(validation.updateSosStatusSchema.validate({ status: 'ACTIVE' }).error);
  assert.ok(validation.activeSosQuerySchema.validate({ tripId: 'bad-id' }).error);
  assert.equal(validation.emergencySosSchema.validate({ tripId, latitude: 21, longitude: 105 }).error, undefined);
});

test('history SQL only selects owner records, all statuses, even after trip completion', async t => {
  t.mock.method(db, 'query', async (sql, params) => {
    assert.match(sql, /WHERE s.user_id = \$1/);
    assert.match(sql, /LEFT JOIN trips/);
    assert.match(sql, /ORDER BY s.created_at DESC, s.id DESC/);
    assert.match(sql, /LIMIT \$2 OFFSET \$3/);
    assert.doesNotMatch(sql, /membership_status|t.status|s.status\s*=/);
    assert.deepEqual(params, [userId, 21, 40]);
    return { rows: [row] };
  });
  assert.deepEqual(await repo.findSosHistory({ userId, limit: 21, offset: 40 }), [row]);
});

test('history DTO paginates, includes finished alerts, whitelists fields', async t => {
  let rows = ['ACTIVE', 'RESOLVED', 'FALSE_ALARM'].map(status => ({
    ...row, status, trip_name: 'Hà Nội', private_field: 'never expose',
    resolved_at: status === 'ACTIVE' ? null : new Date(),
  }));
  t.mock.method(repo, 'findSosHistory', async args => {
    assert.deepEqual(args, { userId, limit: 3, offset: 0 });
    return rows;
  });
  const first = await service.getSosHistory({ userId, limit: 2, offset: 0 });
  assert.equal(first.hasMore, true);
  assert.deepEqual(first.items.map(x => x.status), ['ACTIVE', 'RESOLVED']);
  assert.equal(first.items[0].tripName, 'Hà Nội');
  assert.equal(first.items[0].userId, undefined);
  assert.equal(first.items[0].private_field, undefined);
  assert.ok(first.items[1].resolvedAt);
  rows = [rows[2]];
  assert.equal((await service.getSosHistory({ userId, limit: 2 })).items[0].status, 'FALSE_ALARM');
  rows = [];
  assert.deepEqual(await service.getSosHistory({ userId, limit: 2 }), { items: [], hasMore: false });
});

test('history controller uses authenticated owner, never query userId', async t => {
  const result = { items: [], hasMore: false };
  t.mock.method(service, 'getSosHistory', async args => {
    assert.deepEqual(args, { userId, limit: 20, offset: 0 });
    return result;
  });
  const res = { status(code) { assert.equal(code, 200); return this; },
    json(body) { assert.deepEqual(body.data, result); return this; } };
  await controller.getSosHistory({ user: { id: userId }, query: {
    userId: 'another-user', limit: 20, offset: 0,
  } }, res, error => { throw error; });
});

test('history pagination validation bounds and defaults', () => {
  assert.deepEqual(validation.sosHistoryQuerySchema.validate({}).value, { limit: 20, offset: 0 });
  assert.deepEqual(validation.sosHistoryQuerySchema.validate({ limit: '10', offset: '20' }).value, { limit: 10, offset: 20 });
  for (const query of [{ limit: 0 }, { limit: 51 }, { offset: -1 }, { offset: 1.5 }, { offset: 'bad' }]) {
    assert.ok(validation.sosHistoryQuerySchema.validate(query).error);
  }
});
