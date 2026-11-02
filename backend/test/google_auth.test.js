const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { generateKeyPairSync, randomUUID } = require('node:crypto');
const jwt = require('jsonwebtoken');
const fs = require('node:fs');
const path = require('node:path');
const { OAuth2Client } = require('google-auth-library');

assert.equal(process.env.NODE_ENV, 'test', 'Run via npm test with an isolated PostgreSQL');
assert.match(process.env.DATABASE_URL || '', /ft_test_/);
const schema = `ft_test_google_${randomUUID().replaceAll('-', '')}`;
const databaseUrl = new URL(process.env.DATABASE_URL);
databaseUrl.searchParams.set('options', `-c search_path=${schema},public`);
process.env.DATABASE_URL = databaseUrl.toString();

// Real signature/audience/expiry verification using an isolated local signing key.
// Only certificate discovery is replaced; no Google account or external API is used.
const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const audience = 'test-web-client.apps.googleusercontent.com';
process.env.GOOGLE_CLIENT_IDS = audience;
OAuth2Client.prototype.getFederatedSignonCertsAsync = async () => ({
  certs: { local: publicKey.export({ type: 'spki', format: 'pem' }) },
  format: 'PEM',
});

const db = require('../src/config/database');
const migrate = require('../scripts/migrate');
const app = require('../src/app');
const repo = require('../src/features/auth/auth.repository');
const { verifyGoogleToken } = require('../src/features/auth/google-token.service');
const service = require('../src/features/auth/auth.service');
let server, url;

const claims = (overrides = {}) => ({
  sub: randomUUID(), email: `google-${randomUUID()}@gmail.com`, email_verified: true,
  name: 'Google Test', iss: 'https://accounts.google.com', aud: audience,
  iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600,
  ...overrides,
});
const token = payload => jwt.sign(payload, privateKey, { algorithm: 'RS256', keyid: 'local' });
const consent = { termsAccepted: true, termsVersion: '1.0' };
const create = payload => service.googleLogin({ idToken: token(payload), ...consent });
const local = async (email, extra = {}) => {
  const user = await repo.createUser({ email, passwordHash: 'existing-password-hash', fullName: 'Local User', termsVersion: '1.0' });
  await db.query('UPDATE users SET is_email_verified=$2,status=$3 WHERE id=$1', [user.id, extra.verified ?? true, extra.status || 'ACTIVE']);
  return user;
};

before(async () => {
  assert.equal(process.env.NODE_ENV, 'test');
  assert.match(process.env.DATABASE_URL || '', /ft_test_/);
  await db.query(`CREATE SCHEMA ${schema}`);
  // gen_random_uuid is built into test PostgreSQL; avoid racing the shared
  // database-level extension installer used by the existing integration suite.
  await db.query(fs.readFileSync(path.join(__dirname, '../database/schema.sql'), 'utf8')
    .replace(/CREATE EXTENSION IF NOT EXISTS "uuid-ossp";/, ''));
  await migrate();
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  url = `http://127.0.0.1:${server.address().port}/api/v1/auth/google`;
});
after(async () => {
  if (server) await new Promise(resolve => server.close(resolve));
  await db.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
  await db.pool.end();
});

test('rejects wrong audience, issuer, expired token, tampered signature and unverified email', async () => {
  for (const override of [
    { aud: 'foreign-client' }, { iss: 'https://attacker.invalid' },
    { exp: Math.floor(Date.now() / 1000) - 3600 }, { email_verified: false },
  ]) {
    await assert.rejects(verifyGoogleToken(token(claims(override))), { status: 401 });
  }
  const valid = token(claims());
  const parts = valid.split('.');
  parts[1] = Buffer.from(JSON.stringify(claims({ email: 'attacker@gmail.com' }))).toString('base64url');
  await assert.rejects(verifyGoogleToken(parts.join('.')), { status: 401 });
});

test('missing server client IDs fails closed', async () => {
  delete process.env.GOOGLE_CLIENT_IDS;
  try { await assert.rejects(verifyGoogleToken(token(claims())), { status: 503 }); }
  finally { process.env.GOOGLE_CLIENT_IDS = audience; }
});

test('new non-Google-hosted email requires independent email verification', async () => {
  const payload = claims({ email: `external-${randomUUID()}@example.com` });
  await assert.rejects(create(payload), { code: 'GOOGLE_EMAIL_VERIFICATION_REQUIRED' });
  assert.equal(await repo.findUserByEmail(payload.email), null);
});

test('new Google user must accept terms before any user record or session is created', async () => {
  const payload = claims();
  const response = await fetch(url, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken: token(payload) }),
  });
  assert.equal(response.status, 409);
  assert.equal((await response.json()).code, 'GOOGLE_TERMS_REQUIRED');
  assert.equal(await repo.findUserByEmail(payload.email), null);
});

test('Google registration returns app JWT and email verification without granting eKYC or ADMIN', async () => {
  const payload = claims();
  const response = await fetch(url, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ idToken: token(payload), ...consent }),
  });
  assert.equal(response.status, 200);
  const { data } = await response.json();
  assert.equal(data.user.email, payload.email);
  assert.equal(data.user.role, 'USER');
  assert.equal(data.user.isEmailVerified, true);
  assert.equal(data.user.isVerified, false);
  assert.equal(data.user.verificationStatus, 'UNVERIFIED');
  const decoded = jwt.verify(data.token, require('../src/config/env').jwt.secret);
  assert.equal(decoded.id, data.user.id);
  for (const field of ['password_hash', 'google_id', 'cccd_number']) assert.equal(field in data.user, false);
});

test('verified existing Gmail links once, preserving profile and identity status', async () => {
  const payload = claims();
  const user = await local(payload.email);
  const loggedIn = await create(payload);
  assert.equal(loggedIn.user.id, user.id);
  assert.equal(loggedIn.user.fullName, 'Local User');
  const { rows: [saved] } = await db.query('SELECT * FROM users WHERE id=$1', [user.id]);
  assert.equal(saved.google_id, payload.sub);
  assert.equal(saved.password_hash, 'existing-password-hash');
  assert.equal(saved.is_verified, false);
});

test('unverified local email, another linked Google identity and non-authoritative email cannot auto-link', async () => {
  const unverified = claims();
  await local(unverified.email, { verified: false });
  await assert.rejects(create(unverified), { code: 'GOOGLE_ACCOUNT_CONFLICT' });
  const thirdParty = claims({ email: `google-${randomUUID()}@example.com` });
  await local(thirdParty.email);
  await assert.rejects(create(thirdParty), { code: 'GOOGLE_ACCOUNT_CONFLICT' });
  const linked = claims();
  await create(linked);
  await assert.rejects(create({ ...linked, sub: randomUUID() }), { code: 'GOOGLE_ACCOUNT_CONFLICT' });
});

test('banned account cannot sign in or acquire a Google link', async () => {
  const payload = claims();
  const user = await local(payload.email, { status: 'BANNED' });
  await assert.rejects(create(payload), { status: 403, code: 'ACCOUNT_BANNED' });
  const { rows: [saved] } = await db.query('SELECT google_id FROM users WHERE id=$1', [user.id]);
  assert.equal(saved.google_id, null);
});

test('returning Google account is identified by sub even after Google email changes', async () => {
  const payload = claims();
  const first = await create(payload);
  const next = await service.googleLogin({ idToken: token({ ...payload, email: `changed-${randomUUID()}@gmail.com` }) });
  assert.equal(next.user.id, first.user.id);
  assert.equal(next.user.email, first.user.email);
});

test('concurrent first Google sign-ins create one user', async () => {
  const payload = claims();
  const results = await Promise.all([create(payload), create(payload)]);
  assert.equal(results[0].user.id, results[1].user.id);
  const count = await db.query('SELECT COUNT(*)::int AS count FROM users WHERE google_id=$1', [payload.sub]);
  assert.equal(count.rows[0].count, 1);
});

test('HTTP rejects empty token and ignores forged client-side profile fields', async () => {
  const post = body => fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  assert.equal((await post({ idToken: '' })).status, 400);
  const payload = claims();
  const response = await post({ idToken: token(payload), role: 'ADMIN', email: 'fake@gmail.com', ...consent });
  assert.equal(response.status, 200);
  const { data } = await response.json();
  assert.equal(data.user.email, payload.email);
  assert.equal(data.user.role, 'USER');
});
