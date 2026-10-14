const { test } = require('node:test');
const assert = require('node:assert/strict');
const express = require('express');

// No database or provider calls. Test files run in isolated Node processes.
const dbPath = require.resolve('../src/config/database');
const db = { query: async () => { throw new Error('Unexpected database call'); } };
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };

const repo = require('../src/features/reviews/reviews.repository');
const service = require('../src/features/reviews/reviews.service');
const reporter = '11111111-1111-4111-8111-111111111111';
const target = '22222222-2222-4222-8222-222222222222';
const trip = '33333333-3333-4333-8333-333333333333';
const base = { reporterId: reporter, reportedTripId: trip, reason: 'Nội dung vi phạm cần xem xét' };

function arrange(t, context, { userExists = true } = {}) {
  const writes = [];
  const lookups = [];
  t.mock.method(repo, 'findUserById', async () => userExists ? { id: target } : null);
  t.mock.method(repo, 'findReportTripContext', async args => {
    lookups.push(args);
    return context;
  });
  t.mock.method(repo, 'createReport', async data => {
    writes.push(data);
    return { id: 'new-report', reporter_id: data.reporterId,
      reported_user_id: data.reportedUserId, reported_trip_id: data.reportedTripId,
      reason: data.reason, evidence_image_url: data.evidenceImageUrl, status: 'PENDING' };
  });
  return { writes, lookups };
}

test('outsider may report publicly accessible trip without identifying a member', async t => {
  const { writes, lookups } = arrange(t, { id: trip,
    is_publicly_reportable: true, reporter_was_member: false });
  const result = await service.createReport(base);
  assert.equal(result.status, 'PENDING');
  assert.equal(result.reportedUserId, null);
  assert.equal(writes.length, 1);
  assert.deepEqual(lookups, [{ tripId: trip, reporterId: reporter, reportedUserId: null }]);
});

test('outsider cannot report private trip without public recruitment', async t => {
  const { writes } = arrange(t, { id: trip,
    is_publicly_reportable: false, reporter_was_member: false });
  await assert.rejects(service.createReport(base), { status: 403 });
  assert.equal(writes.length, 0);
});

for (const state of ['ACTIVE', 'LEFT', 'REMOVED', 'LEGACY_CREATOR']) {
  test(`${state} participant may report a private trip without completion requirement`, async t => {
    const { writes } = arrange(t, { id: trip,
      is_publicly_reportable: false, reporter_was_member: true });
    const result = await service.createReport(base);
    assert.equal(result.reportedTripId, trip);
    assert.equal(writes.length, 1);
  });
}

test('public trip does not let an outsider report one of its members', async t => {
  const { writes } = arrange(t, { id: trip, is_publicly_reportable: true,
    reporter_was_member: false, reported_user_was_member: true });
  await assert.rejects(service.createReport({ ...base, reportedUserId: target }),
    { status: 403 });
  assert.equal(writes.length, 0);
});

test('participant cannot attach an unrelated user to a trip report', async t => {
  const { writes } = arrange(t, { id: trip, is_publicly_reportable: true,
    reporter_was_member: true, reported_user_was_member: false });
  await assert.rejects(service.createReport({ ...base, reportedUserId: target }),
    { status: 400 });
  assert.equal(writes.length, 0);
});

test('current or former co-participants may report a member before trip completion', async t => {
  const { writes } = arrange(t, { id: trip, is_publicly_reportable: false,
    reporter_was_member: true, reported_user_was_member: true });
  const result = await service.createReport({ ...base, reportedUserId: target,
    evidenceImageUrl: 'https://example.com/evidence.jpg' });
  assert.equal(result.reportedUserId, target);
  assert.equal(writes[0].evidenceImageUrl, 'https://example.com/evidence.jpg');
});

test('missing trip, missing target, and self-report never create a report', async t => {
  const { writes } = arrange(t, null, { userExists: false });
  await assert.rejects(service.createReport(base), { status: 404 });
  await assert.rejects(service.createReport({ ...base, reportedUserId: target }), { status: 404 });
  await assert.rejects(service.createReport({ ...base, reportedUserId: reporter }), { status: 400 });
  assert.equal(writes.length, 0);
});

test('standalone account-report API remains independent of trip membership', async t => {
  const { writes, lookups } = arrange(t, null);
  await service.createReport({ reporterId: reporter, reportedUserId: target, reason: base.reason });
  assert.equal(lookups.length, 0);
  assert.equal(writes[0].reportedTripId, null);
});

test('review completion restriction remains unchanged', async t => {
  t.mock.method(repo, 'findTripContext', async () => ({ status: 'UPCOMING',
    reviewer_is_member: true, reviewee_is_member: true }));
  await assert.rejects(service.reviewTrip({ reviewerId: reporter, tripId: trip, rating: 5 }),
    { status: 409 });
  await assert.rejects(service.reviewMember({ reviewerId: reporter, tripId: trip,
    revieweeId: target, rating: 5 }), { status: 409 });
});

test('repository uses parameterized historical membership and public-post checks', async t => {
  t.mock.method(db, 'query', async (sql, parameters) => {
    assert.deepEqual(parameters, [trip, reporter, target]);
    assert.match(sql, /t\.privacy_type = 'PUBLIC'/);
    assert.match(sql, /cp\.status IN \('OPEN', 'FULL'\)/);
    assert.match(sql, /reporter_member\.membership_status IN \('ACTIVE', 'LEFT', 'REMOVED'\)/);
    assert.match(sql, /reported_member\.membership_status IN \('ACTIVE', 'LEFT', 'REMOVED'\)/);
    assert.match(sql, /t\.creator_id = \$2/);
    assert.match(sql, /t\.creator_id = \$3/);
    assert.ok(!sql.includes(reporter));
    assert.ok(!sql.includes('COMPLETED'));
    return { rows: [{ id: trip }] };
  });
  assert.deepEqual(await repo.findReportTripContext({ tripId: trip,
    reporterId: reporter, reportedUserId: target }), { id: trip });
});

test('report route applies permissions and validation even without frontend controls', async t => {
  const authPath = require.resolve('../src/shared/middlewares/auth.middleware');
  const uploadPath = require.resolve('../src/shared/middlewares/upload.middleware');
  require.cache[authPath] = { id: authPath, filename: authPath, loaded: true,
    exports: (req, res, next) => { req.user = { id: reporter }; next(); } };
  require.cache[uploadPath] = { id: uploadPath, filename: uploadPath, loaded: true,
    exports: { single: () => (req, res, next) => next() } };
  const context = { id: trip, is_publicly_reportable: true,
    reporter_was_member: false, reported_user_was_member: true };
  const { writes } = arrange(t, context);
  const app = express();
  app.use(express.json());
  app.use('/reviews', require('../src/features/reviews/reviews.routes'));
  app.use((error, req, res, next) => res.status(error.status || 500).json({ message: error.message }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(async () => {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  });
  const send = body => fetch(`http://127.0.0.1:${server.address().port}/reviews/report`, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
  });
  assert.equal((await send({ reportedTripId: trip, reportedUserId: target,
    reason: base.reason })).status, 403);
  assert.equal(writes.length, 0);
  const allowed = await send({ reportedTripId: trip, reason: base.reason });
  assert.equal(allowed.status, 201);
  assert.equal((await allowed.json()).data.status, 'PENDING');
  assert.equal(writes.length, 1);
  context.is_publicly_reportable = false;
  assert.equal((await send({ reportedTripId: trip, reason: base.reason })).status, 403);
  assert.equal((await send({ reportedTripId: 'invalid-id', reason: base.reason })).status, 400);
  assert.equal(writes.length, 1);
});
