const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { Writable } = require('node:stream');
const fs = require('node:fs');
const path = require('node:path');

assert.equal(process.env.NODE_ENV, 'test', 'Run through npm test');
assert.match(process.env.DATABASE_URL || '', /ft_test_/);
const schema = `ft_test_manual_${randomUUID().replaceAll('-', '')}`;
const dbUrl = new URL(process.env.DATABASE_URL);
dbUrl.searchParams.set('options', `-c search_path=${schema},public`);
process.env.DATABASE_URL = dbUrl.toString();
delete process.env.EKYC_AUTO_ENABLED;

const db = require('../src/config/database');
const migrate = require('../scripts/migrate');
const cloudinary = require('../src/config/cloudinary');
const manual = require('../src/features/users/manual-identity.service');
const { generateToken } = require('../src/shared/utils/token.util');
const app = require('../src/app');
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lboAAAAASUVORK5CYII=', 'base64');
const number = '001201012345';
const fields = ['cccdFrontImage', 'cccdBackImage', 'selfieImage'];
const files = () => Object.fromEntries(fields.map(field => [field, [{ buffer: png }]]));
let server, base;
const originalCloudConfig = { ...cloudinary.config() };

before(async () => {
  cloudinary.config({ cloud_name: 'manual-test', api_key: 'test-key', api_secret: 'test-secret' });
  await db.query(`CREATE SCHEMA ${schema}`);
  await db.query(fs.readFileSync(path.join(__dirname, '../database/schema.sql'), 'utf8').replace(/CREATE EXTENSION IF NOT EXISTS "uuid-ossp";/, ''));
  await migrate();
  server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}/api/v1`;
});
after(async () => {
  if (server) await new Promise(resolve => server.close(resolve));
  await db.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
  await db.pool.end();
  cloudinary.config(originalCloudConfig);
});

async function user(role = 'USER') {
  const { rows: [row] } = await db.query("INSERT INTO users(email,full_name,role,is_email_verified) VALUES($1,'Manual test',$2,true) RETURNING *", [`${randomUUID()}@example.com`, role]);
  return { ...row, token: generateToken({ id: row.id, tokenVersion: row.token_version }) };
}
const headers = account => ({ Authorization: `Bearer ${account.token}` });
function uploads(t, failAt = -1) {
  const stored = [], destroyed = [];
  t.mock.method(cloudinary.uploader, 'upload_stream', (options, callback) => {
    assert.equal(options.type, 'authenticated');
    return new Writable({ write(chunk, encoding, done) { done(); }, final(done) {
      if (stored.length === failAt) { callback(new Error('Upload failure')); done(); return; }
      const public_id = `feelingtrip/identity/${randomUUID()}`;
      const asset = { public_id, secure_url: cloudinary.url(public_id, {
        type: 'authenticated', resource_type: 'image', format: 'jpg',
        version: 1, secure: true, sign_url: true,
      }) };
      stored.push(asset); callback(null, asset); done();
    } });
  });
  t.mock.method(cloudinary.uploader, 'destroy', async id => { destroyed.push(id); return {}; });
  return { stored, destroyed };
}
async function submit(account, modify = () => {}) {
  const form = new FormData();
  form.set('cccdNumber', number);
  for (const field of fields) form.set(field, new Blob([png], { type: 'image/png' }), `${field}.png`);
  modify(form);
  return fetch(`${base}/users/ekyc-submit`, { method: 'POST', headers: account ? headers(account) : {}, body: form });
}
async function review(admin, id, approve, reason) {
  return fetch(`${base}/admin/ekyc/${id}/${approve ? 'approve' : 'reject'}`, {
    method: 'PUT', headers: { ...headers(admin), 'Content-Type': 'application/json' },
    body: JSON.stringify(approve ? {} : { reason }),
  });
}

test('manual submission works without worker configuration and exposes no documents to the user', async t => {
  const account = await user(); const media = uploads(t);
  const response = await submit(account);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.data.verificationStatus, 'PENDING');
  assert.equal(body.data.isVerified, false);
  assert.equal(media.stored.length, 3);
  const profile = await (await fetch(`${base}/users/profile`, { headers: headers(account) })).json();
  assert.equal(profile.data.hasEkycDocuments, true);
  for (const field of ['cccdNumber', ...fields]) assert.equal(field in profile.data, false);
  const again = await submit(account);
  assert.equal(again.status, 409);
  assert.equal(media.stored.length, 3);
});

test('only admin sees expiring document links and reject/resubmit/approve completes the manual lifecycle', async t => {
  const account = await user(), admin = await user('ADMIN'); uploads(t);
  assert.equal((await submit(account)).status, 200);
  assert.equal((await fetch(`${base}/admin/ekyc/pending`, { headers: headers(account) })).status, 403);
  const pending = await fetch(`${base}/admin/ekyc/pending`, { headers: headers(admin) });
  assert.equal(pending.headers.get('cache-control'), 'no-store');
  const data = (await pending.json()).data;
  const record = data.profiles.find(item => item.id === account.id);
  for (const field of fields) {
    const url = new URL(record[field]);
    assert.equal(url.hostname, 'api.cloudinary.com');
    assert.equal(url.searchParams.get('type'), 'authenticated');
    assert.match(url.searchParams.get('public_id'), /^feelingtrip\/identity\//);
    assert.ok(!url.searchParams.get('public_id').includes('s--'));
    assert.ok(Number(url.searchParams.get('expires_at')) <= Date.now() / 1000 + 601);
  }
  assert.equal((await review(admin, account.id, false, 'Ảnh mặt sau bị mờ')).status, 200);
  let profile = await (await fetch(`${base}/users/profile`, { headers: headers(account) })).json();
  assert.equal(profile.data.verificationStatus, 'REJECTED');
  assert.equal(profile.data.verificationRejectionReason, 'Ảnh mặt sau bị mờ');
  assert.equal((await submit(account)).status, 200);
  assert.equal((await review(admin, account.id, true)).status, 200);
  profile = await (await fetch(`${base}/users/profile`, { headers: headers(account) })).json();
  assert.equal(profile.data.verificationStatus, 'VERIFIED');
  assert.equal(profile.data.isVerified, true);
  assert.equal((await submit(account)).status, 409);
});

test('admin document links resolve signed and unsigned authenticated assets without treating signature as public id', () => {
  const publicId = 'feelingtrip/identity/synthetic-test-document';
  for (const sign_url of [false, true]) {
    for (const version of [undefined, 1]) {
      const storedUrl = cloudinary.url(publicId, {
        type: 'authenticated', resource_type: 'image', format: 'jpg',
        secure: true, sign_url, ...(version ? { version } : {}),
      });
      if (sign_url) assert.match(storedUrl, /\/s--[A-Za-z0-9_-]+--\//);
      const download = new URL(manual.adminDocumentUrl(storedUrl));
      assert.equal(download.protocol, 'https:');
      assert.equal(download.hostname, 'api.cloudinary.com');
      assert.equal(download.searchParams.get('public_id'), publicId);
      assert.equal(download.searchParams.get('format'), 'jpg');
      assert.equal(download.searchParams.get('type'), 'authenticated');
      assert.ok(download.searchParams.get('signature'));
      assert.ok(!download.toString().includes('test-secret'));
      const expires = Number(download.searchParams.get('expires_at'));
      assert.ok(expires >= Date.now() / 1000 + 590 && expires <= Date.now() / 1000 + 601);
    }
  }
  assert.equal(manual.adminDocumentUrl(null), null);
  assert.equal(manual.adminDocumentUrl('https://res.cloudinary.com/manual-test/image/authenticated/s--abcd1234--/v1/other-folder/image.jpg'), null);
});

test('manual endpoint rejects anonymous, missing images, invalid number and disguised images', async t => {
  const account = await user(); const media = uploads(t);
  assert.equal((await submit(null)).status, 401);
  assert.equal((await submit(account, form => form.delete('selfieImage'))).status, 400);
  assert.equal((await submit(account, form => form.set('cccdNumber', '123'))).status, 400);
  assert.equal((await submit(account, form => form.set('selfieImage', new Blob(['not-an-image']), 'selfie.jpg'))).status, 400);
  assert.equal(media.stored.length, 0);
});

test('automatic routes are paused by default while manual review remains available', async () => {
  const account = await user();
  for (const endpoint of ['/users/ekyc/session', '/users/ekyc-verify']) {
    const response = await fetch(base + endpoint, { method: 'POST', headers: headers(account) });
    assert.equal(response.status, 503);
    assert.match((await response.json()).message, /tạm dừng/);
  }
});

test('partial Cloudinary failure cleans up uploaded images and leaves profile unsubmitted', async t => {
  const account = await user(); const media = uploads(t, 1);
  await assert.rejects(manual.submit({ userId: account.id, cccdNumber: number, files: files() }), { status: 503 });
  assert.deepEqual(media.destroyed, media.stored.map(asset => asset.public_id));
  const { rows: [saved] } = await db.query('SELECT * FROM users WHERE id=$1', [account.id]);
  assert.equal(saved.verification_status, 'UNVERIFIED');
  assert.equal(saved.cccd_front_image, null);
});

test('concurrent submissions accept once and clean losing request images', async t => {
  const account = await user(); const media = uploads(t);
  const results = await Promise.allSettled([0, 1].map(() => manual.submit({ userId: account.id, cccdNumber: number, files: files() })));
  assert.equal(results.filter(item => item.status === 'fulfilled').length, 1);
  assert.equal(results.find(item => item.status === 'rejected').reason.status, 409);
  assert.equal(media.stored.length - media.destroyed.length, 3);
});

test('banned pending accounts cannot be approved', async t => {
  const account = await user(), admin = await user('ADMIN'); uploads(t);
  assert.equal((await submit(account)).status, 200);
  await db.query("UPDATE users SET status='BANNED' WHERE id=$1", [account.id]);
  assert.equal((await review(admin, account.id, true)).status, 409);
});
