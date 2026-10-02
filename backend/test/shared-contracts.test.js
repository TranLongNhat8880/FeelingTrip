const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const db = require('../src/config/database');

const migration = fs.readFileSync(
  path.join(__dirname, '../database/migrations/004_member_feature_contracts.sql'), 'utf8');

// Temp tables shadow application tables only on this connection. Every fixture is rolled back.
async function legacyFixture(work) {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`
      CREATE TEMP TABLE users (id INT PRIMARY KEY, verification_status TEXT) ON COMMIT DROP;
      CREATE TEMP TABLE places (id INT PRIMARY KEY, name TEXT) ON COMMIT DROP;
      CREATE TEMP TABLE sos_alerts (id INT PRIMARY KEY, status TEXT NOT NULL DEFAULT 'ACTIVE'
        CONSTRAINT sos_alerts_status_check CHECK (status IN ('ACTIVE','RESOLVED'))) ON COMMIT DROP;
      CREATE TEMP TABLE user_reports (id INT PRIMARY KEY, reason TEXT) ON COMMIT DROP;
      CREATE TEMP TABLE trip_reviews (
        id INT PRIMARY KEY, trip_id INT NOT NULL, reviewer_id INT NOT NULL, reviewee_id INT,
        rating INT NOT NULL, comment TEXT) ON COMMIT DROP;
      INSERT INTO users VALUES (1, 'REJECTED');
      INSERT INTO places VALUES (1, 'Existing place');
      INSERT INTO sos_alerts VALUES (1, 'RESOLVED');
      INSERT INTO user_reports VALUES (1, 'Existing report');
      INSERT INTO trip_reviews VALUES (1, 10, 1, NULL, 4, 'Existing review');
    `);
    await work(client);
  } finally {
    await client.query('ROLLBACK');
    client.release();
  }
}

async function expectSqlError(client, sql, params, code) {
  await client.query('SAVEPOINT expected_error');
  try {
    await assert.rejects(client.query(sql, params), { code });
  } finally {
    await client.query('ROLLBACK TO SAVEPOINT expected_error');
    await client.query('RELEASE SAVEPOINT expected_error');
  }
}

before(async () => {
  assert.match((await db.query('SELECT current_schema() AS name')).rows[0].name, /^ft_test_/);
});
after(() => db.pool.end());

test('migration 004 preserves legacy data, persists new fields and can run twice', async () => {
  await legacyFixture(async (client) => {
    await client.query(migration);
    assert.deepEqual((await client.query('SELECT * FROM users')).rows,
      [{ id: 1, verification_status: 'REJECTED', verification_rejection_reason: null }]);
    assert.deepEqual((await client.query('SELECT * FROM places')).rows,
      [{ id: 1, name: 'Existing place', is_active: true }]);
    assert.deepEqual((await client.query('SELECT * FROM user_reports')).rows,
      [{ id: 1, reason: 'Existing report', evidence_image_url: null }]);
    await client.query('UPDATE users SET verification_rejection_reason=$1', ['Ảnh CCCD bị mờ']);
    await client.query('UPDATE places SET is_active=FALSE');
    await client.query("UPDATE sos_alerts SET status='FALSE_ALARM', message=$1", ['Đã báo nhầm']);
    await client.query('UPDATE user_reports SET evidence_image_url=$1', ['https://example.com/evidence.jpg']);
    await client.query(migration);
    assert.equal((await client.query('SELECT verification_rejection_reason FROM users')).rows[0]
      .verification_rejection_reason, 'Ảnh CCCD bị mờ');
    assert.equal((await client.query('SELECT is_active FROM places')).rows[0].is_active, false);
    assert.deepEqual((await client.query('SELECT status,message FROM sos_alerts')).rows,
      [{ status: 'FALSE_ALARM', message: 'Đã báo nhầm' }]);
    assert.equal((await client.query('SELECT evidence_image_url FROM user_reports')).rows[0]
      .evidence_image_url, 'https://example.com/evidence.jpg');
    assert.equal((await client.query('SELECT comment FROM trip_reviews')).rows[0].comment, 'Existing review');
    // Hide/restore affects the marker, not the place row or its history.
    await client.query('UPDATE places SET is_active=TRUE');
    assert.equal((await client.query('SELECT is_active FROM places')).rows[0].is_active, true);
    await expectSqlError(client, 'UPDATE places SET is_active=NULL', [], '23502');
    await expectSqlError(client, "UPDATE sos_alerts SET status='UNKNOWN'", [], '23514');
    await expectSqlError(client, 'UPDATE sos_alerts SET message=$1', ['a'.repeat(501)], '22001');
    await expectSqlError(client, 'UPDATE users SET verification_rejection_reason=$1', ['a'.repeat(501)], '22001');
  });
});

test('unique review indexes distinguish trip and member targets including NULL reviewee', async () => {
  await legacyFixture(async (client) => {
    await client.query(migration);
    const insert = 'INSERT INTO trip_reviews VALUES ($1,$2,$3,$4,5,NULL)';
    await expectSqlError(client, insert, [2, 10, 1, null], '23505');
    await client.query(insert, [2, 10, 1, 2]);
    await expectSqlError(client, insert, [3, 10, 1, 2], '23505');
    await client.query(insert, [3, 10, 1, 3]); // Different member.
    await client.query(insert, [4, 10, 2, null]); // Different reviewer.
    await client.query(insert, [5, 11, 1, null]); // Different trip.
    assert.equal((await client.query('SELECT COUNT(*)::INT AS count FROM trip_reviews')).rows[0].count, 5);
  });
});

for (const reviewee of [null, 2]) {
  test(`migration refuses legacy duplicate ${reviewee === null ? 'trip' : 'member'} reviews and rolls back all DDL`, async () => {
    await legacyFixture(async (client) => {
      await client.query('UPDATE trip_reviews SET reviewee_id=$1', [reviewee]);
      await client.query('INSERT INTO trip_reviews VALUES (2,10,1,$1,2,$2)', [reviewee, 'Keep both']);
      await client.query('SAVEPOINT before_migration');
      await assert.rejects(client.query(migration), (error) =>
        error.code === '23505' && error.message.includes('004_member_feature_contracts') &&
        error.message.includes('No reviews were deleted') && error.hint.includes('HAVING COUNT(*) > 1'));
      await client.query('ROLLBACK TO SAVEPOINT before_migration');
      assert.deepEqual((await client.query('SELECT comment FROM trip_reviews ORDER BY id')).rows,
        [{ comment: 'Existing review' }, { comment: 'Keep both' }]);
      // Column additions and relaxed SOS check are rolled back together.
      await expectSqlError(client, 'SELECT verification_rejection_reason FROM users', [], '42703');
      await expectSqlError(client, 'SELECT is_active FROM places', [], '42703');
      await expectSqlError(client, 'SELECT message FROM sos_alerts', [], '42703');
      await expectSqlError(client, 'SELECT evidence_image_url FROM user_reports', [], '42703');
      await expectSqlError(client, "UPDATE sos_alerts SET status='FALSE_ALARM'", [], '23514');
    });
  });
}

test('fresh schema contains the same shared contract as upgraded databases', async () => {
  const client = await db.pool.connect();
  const schema = 'ft_contract_' + crypto.randomBytes(8).toString('hex');
  try {
    await client.query('BEGIN');
    await client.query(`CREATE SCHEMA ${schema}`);
    await client.query(`SET LOCAL search_path TO ${schema}, public`);
    await client.query(fs.readFileSync(path.join(__dirname, '../database/schema.sql'), 'utf8'));
    const columns = (await client.query(`SELECT table_name,column_name,data_type,is_nullable,column_default
      FROM information_schema.columns WHERE table_schema=$1 AND column_name IN
      ('verification_rejection_reason','is_active','message','evidence_image_url')`, [schema])).rows;
    for (const [table, column] of [
      ['users', 'verification_rejection_reason'], ['places', 'is_active'],
      ['sos_alerts', 'message'], ['user_reports', 'evidence_image_url'],
    ]) assert.ok(columns.some((row) => row.table_name === table && row.column_name === column));
    const active = columns.find((row) => row.table_name === 'places');
    assert.equal(active.is_nullable, 'NO');
    assert.equal(active.column_default, 'true');
    const { rows: [sosCheck] } = await client.query(`SELECT pg_get_constraintdef(oid) AS definition
      FROM pg_constraint WHERE conrelid='sos_alerts'::regclass AND conname='sos_alerts_status_check'`);
    assert.ok(sosCheck.definition.includes('FALSE_ALARM'));
    const indexes = (await client.query(`SELECT indexname,indexdef FROM pg_indexes WHERE schemaname=$1
      AND tablename='trip_reviews' AND indexname LIKE 'idx_trip_reviews_%_unique'`, [schema])).rows;
    assert.equal(indexes.length, 2);
    assert.ok(indexes.every((row) => row.indexdef.includes('UNIQUE')));
    // Existing migrations still run in sequence on the new bootstrap schema.
    for (const file of fs.readdirSync(path.join(__dirname, '../database/migrations')).sort()) {
      if (file.endsWith('.sql')) await client.query(fs.readFileSync(path.join(__dirname, '../database/migrations', file), 'utf8'));
    }
    assert.ok((await client.query(`SELECT pg_get_constraintdef(oid) AS definition FROM pg_constraint
      WHERE conrelid='sos_alerts'::regclass AND conname='sos_alerts_status_check'`)).rows[0].definition.includes('FALSE_ALARM'));
  } finally {
    await client.query('ROLLBACK');
    client.release();
  }
});
