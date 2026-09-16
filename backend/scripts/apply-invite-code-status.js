// Applies ONLY migration 003 to the configured Supabase database.
require('dotenv').config();
const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');

async function main() {
  const url = new URL(process.env.DATABASE_URL);
  if (!/\.supabase\.(co|com)$/.test(url.hostname)) throw new Error('Expected configured Supabase database');
  const client = new Client({ connectionString: url.toString(), connectionTimeoutMillis:10000, statement_timeout:30000 });
  try {
    await client.connect();
    await client.query('BEGIN');
    await client.query('SET LOCAL search_path TO public');
    await client.query("SET LOCAL lock_timeout = '5s'");
    await client.query('SELECT pg_advisory_xact_lock(741825)');
    const migration = '003_invite_code_status.sql';
    const { rowCount } = await client.query('SELECT 1 FROM schema_migrations WHERE name=$1',[migration]);
    if (!rowCount) {
      await client.query(fs.readFileSync(path.join(__dirname,'../database/migrations',migration),'utf8'));
      await client.query('INSERT INTO schema_migrations(name) VALUES ($1)',[migration]);
    }
    const { rows } = await client.query('SELECT invite_code_status,COUNT(*)::int AS trips FROM trips GROUP BY invite_code_status');
    const { rows: checks } = await client.query(`SELECT conname FROM pg_constraint
      WHERE conrelid='trips'::regclass AND conname='trips_invite_code_state_check'`);
    if (checks.length !== 1) throw new Error('Constraint verification failed');
    await client.query('COMMIT');
    console.log(JSON.stringify({ migration, applied:!rowCount, states:rows, verified:true }));
  } catch (error) {
    await client.query('ROLLBACK').catch(()=>{});
    throw error;
  } finally { await client.end(); }
}
main().catch((error)=>{
  // Avoid printing connection URLs or database row details on failures.
  console.error('Invite status migration failed:', error.code || error.name);
  process.exitCode=1;
});
