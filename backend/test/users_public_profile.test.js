const { test } = require('node:test');
const assert = require('node:assert/strict');

// Offline unit tests only: no pool, migrations, provider calls or database writes.
const dbPath = require.resolve('../src/config/database');
const db = { query: async () => { throw new Error('Unexpected database call'); } };
require.cache[dbPath] = { id: dbPath, filename: dbPath, loaded: true, exports: db };
const repo = require('../src/features/users/users.repository');
const service = require('../src/features/users/users.service');
const id = '11111111-1111-4111-8111-111111111111';
const user = {
  id, full_name: 'Test name', nickname: 'Test nickname', avatar_url: null,
  bio: 'Public introduction', is_verified: true, trust_score: 4.5,
  review_count: 2, created_at: '2025-01-01T00:00:00Z', age: 21,
  dob: '2005-06-11', phone: 'PRIVATE_PHONE', gender: 'PRIVATE_GENDER',
  email: 'PRIVATE_EMAIL', role: 'ADMIN', cccd_number: 'PRIVATE_CCCD',
  bank_account_number: 'PRIVATE_BANK', verification_rejection_reason: 'PRIVATE_REASON',
};

test('public service exposes age but never private fields or role', async t => {
  t.mock.method(repo, 'findTrustScoreByUserId', async userId => {
    assert.equal(userId, id);
    return user;
  });
  const result = await service.getTrustScore(id);
  assert.equal(result.age, 21);
  assert.deepEqual(Object.keys(result).sort(), [
    'id', 'fullName', 'nickname', 'avatarUrl', 'bio', 'isVerified',
    'trustScore', 'reviewCount', 'memberSince', 'age',
  ].sort());
  for (const key of ['dob', 'phone', 'gender', 'email', 'role', 'cccdNumber', 'bankAccountNumber']) {
    assert.equal(Object.hasOwn(result, key), false);
  }
  assert.equal(JSON.stringify(result).includes('PRIVATE_'), false);
  assert.equal(JSON.stringify(result).includes('2005-06-11'), false);
});

test('null age remains null; private dob is not copied as a fallback', async t => {
  t.mock.method(repo, 'findTrustScoreByUserId', async () => ({ ...user, age: null }));
  const result = await service.getTrustScore(id);
  assert.equal(result.age, null);
  assert.equal(Object.hasOwn(result, 'dob'), false);
});

test('invalid derived age is not published', async t => {
  let derivedAge;
  t.mock.method(repo, 'findTrustScoreByUserId', async () => ({ ...user, age: derivedAge }));
  for (const age of [-1, 21.5, undefined, '21']) {
    derivedAge = age;
    assert.equal((await service.getTrustScore(id)).age, null);
  }
});

test('zero years is a valid derived age, not missing data', async t => {
  t.mock.method(repo, 'findTrustScoreByUserId', async () => ({ ...user, age: 0 }));
  assert.equal((await service.getTrustScore(id)).age, 0);
});

test('missing/inactive public user still returns 404', async t => {
  t.mock.method(repo, 'findTrustScoreByUserId', async () => null);
  await assert.rejects(service.getTrustScore(id), { status: 404 });
});

test('own profile keeps its existing personal fields', async t => {
  t.mock.method(repo, 'findProfileById', async () => user);
  const result = await service.getProfile(id);
  assert.equal(result.phone, user.phone);
  assert.equal(result.dob, user.dob);
  assert.equal(result.gender, user.gender);
  assert.equal(result.role, user.role);
});

test('read-only query computes calendar age and uses a parameterized active-user lookup', async t => {
  t.mock.method(db, 'query', async (sql, values) => {
    assert.deepEqual(values, [id]);
    assert.match(sql, /WHEN u\.dob <= CURRENT_DATE/);
    assert.match(sql, /EXTRACT\(YEAR FROM AGE\(CURRENT_DATE, u\.dob\)\)::INTEGER/);
    assert.match(sql, /ELSE NULL\s+END AS age/);
    assert.match(sql, /WHERE u\.id = \$1\s+AND u\.status = 'ACTIVE'/);
    assert.match(sql, /ON tr\.reviewee_id = u\.id/);
    assert.doesNotMatch(sql, /UPDATE|INSERT|DELETE|ALTER/i);
    const selected = sql.slice(sql.indexOf('SELECT'), sql.indexOf('FROM users'));
    assert.doesNotMatch(selected, /u\.(phone|gender|email|role|bank_account_number|cccd_number)/);
    return { rows: [{ ...user, age: 21 }] };
  });
  assert.equal((await repo.findTrustScoreByUserId(id)).age, 21);
});

test('repository returns null for missing user without extra queries', async t => {
  const query = t.mock.method(db, 'query', async () => ({ rows: [] }));
  assert.equal(await repo.findTrustScoreByUserId(id), null);
  assert.equal(query.mock.callCount(), 1);
});
