const { test } = require('node:test');
const assert = require('node:assert/strict');
const dbPath = require.resolve('../src/config/database');
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: { transaction: fn => fn({}) } };
const repo = require('../src/features/companions/companions.repository');
const users = require('../src/features/users/users.repository');
const service = require('../src/features/companions/companions.service');
const { createCompanionPostSchema, updateCompanionPostSchema } = require('../src/features/companions/companions.validation');

function setup(t, count) {
  t.mock.method(users, 'findProfileById', async () => ({ is_verified: true }));
  t.mock.method(repo, 'getTripByIdForUpdate', async () => ({ status: 'UPCOMING', privacy_type: 'PUBLIC' }));
  t.mock.method(repo, 'isTripLeader', async () => true);
  t.mock.method(repo, 'checkExistsPostByTripId', async () => false);
  t.mock.method(repo, 'getTripMembersCount', async () => count);
  t.mock.method(repo, 'createCompanionPost', async data => data);
  t.mock.method(repo, 'updateCompanionPost', async data => data);
  t.mock.method(repo, 'getCompanionPostById', async () => ({ trip_id: 'trip', status: 'OPEN', target_members_count: 5 }));
}

test('recruitment adds places to actual members, including the leader', async t => {
  setup(t, 1);
  const post = await service.createCompanionPost({ tripId: 'trip', userId: 'leader', recruitmentCount: 4 });
  assert.equal(post.targetMembersCount, 5);
  assert.equal(post.currentMembersCount, 1);
  assert.equal(post.minAge, null);
  assert.equal(post.maxAge, null);
  assert.equal(post.genderPreference, 'ANY');
  t.mock.method(repo, 'getTripMembersCount', async () => 3);
  const next = await service.createCompanionPost({ tripId: 'trip', userId: 'leader', recruitmentCount: 1, tags: null });
  assert.equal(next.targetMembersCount, 4);
  assert.equal(next.tags, null);
});

test('legacy total capacity remains compatible; zero recruitment and overflow are rejected', async t => {
  setup(t, 3);
  assert.equal((await service.createCompanionPost({ targetMembersCount: 5 })).targetMembersCount, 5);
  await assert.rejects(service.createCompanionPost({ recruitmentCount: 0 }), /phải lớn hơn/);
  await assert.rejects(service.createCompanionPost({ recruitmentCount: 48 }), /50 người/);
});

test('editing uses current membership and permits clearing preferences or keeping a full group', async t => {
  setup(t, 4);
  const post = await service.updateCompanionPost({ postId: 'post', userId: 'leader', recruitmentCount: 2, minAge: null, maxAge: null, tags: null });
  assert.equal(post.targetMembersCount, 6);
  assert.equal(post.status, 'OPEN');
  assert.equal(post.tags, null);
  assert.equal(post.minAge, null);
  const full = await service.updateCompanionPost({ postId: 'post', userId: 'leader', recruitmentCount: 0 });
  assert.equal(full.targetMembersCount, 4);
  assert.equal(full.status, 'FULL');
  await assert.rejects(service.updateCompanionPost({ postId: 'post', recruitmentCount: 47 }), /50 người/);
});

test('validation requires one capacity format and accepts nullable optional preferences', () => {
  const body = { tripId: '11111111-1111-4111-8111-111111111111', title: 'Đi Hà Nội', content: 'Cùng đi Hà Nội nhé', recruitmentCount: 1, minAge: null, maxAge: null, tags: null };
  assert.equal(createCompanionPostSchema.validate(body).error, undefined);
  assert.ok(createCompanionPostSchema.validate({ ...body, targetMembersCount: 2 }).error);
  assert.ok(createCompanionPostSchema.validate({ ...body, recruitmentCount: 0 }).error);
  assert.ok(createCompanionPostSchema.validate({ ...body, recruitmentCount: undefined }).error);
  assert.equal(createCompanionPostSchema.validate({ ...body, recruitmentCount: undefined, targetMembersCount: 3 }).error, undefined);
  assert.equal(updateCompanionPostSchema.validate({ recruitmentCount: 0, tags: null, minAge: null }).error, undefined);
  assert.ok(updateCompanionPostSchema.validate({ recruitmentCount: 1, targetMembersCount: 5 }).error);
});


test('post message accepts three trimmed characters and rejects shorter text on create and update', () => {
  const base = { tripId: '11111111-1111-4111-8111-111111111111', title: 'Đi Hà Nội', recruitmentCount: 1 };
  assert.equal(createCompanionPostSchema.validate({ ...base, content: ' abc ' }).error, undefined);
  assert.equal(updateCompanionPostSchema.validate({ content: ' abc ' }).value.content, 'abc');
  for (const content of ['', '  ', ' ab ']) {
    assert.ok(createCompanionPostSchema.validate({ ...base, content }).error);
    assert.ok(updateCompanionPostSchema.validate({ content }).error);
  }
});
