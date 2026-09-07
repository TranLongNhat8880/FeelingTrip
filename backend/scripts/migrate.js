const fs = require('node:fs');
const path = require('node:path');
const db = require('../src/config/database');

/**
 * Migration runner:
 * - Uses PostgreSQL transaction advisory lock (`pg_advisory_xact_lock`) to ensure single-runner execution.
 * - Tracks applied files in `schema_migrations`.
 * - Executes unapplied `.sql` scripts in lexicographical order.
 */
async function migrate() {
  await db.transaction(async (client) => {
    // Acquire exclusive advisory lock for the duration of this transaction
    await client.query('SELECT pg_advisory_xact_lock(741825)');

    // Ensure migrations ledger table exists
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        name TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    const directory = path.join(__dirname, '../database/migrations');
    if (!fs.existsSync(directory)) return;

    const migrationFiles = fs
      .readdirSync(directory)
      .filter((file) => file.endsWith('.sql'))
      .sort();

    for (const filename of migrationFiles) {
      const { rowCount } = await client.query(
        'SELECT 1 FROM schema_migrations WHERE name = $1',
        [filename]
      );

      if (rowCount > 0) continue;

      const sqlContent = fs.readFileSync(path.join(directory, filename), 'utf8');
      await client.query(sqlContent);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [filename]);

      console.log(`Applied migration: ${filename}`);
    }
  });
}

if (require.main === module) {
  migrate()
    .then(() => {
      console.log('Database migrations up to date.');
    })
    .catch((error) => {
      console.error('Migration failed:', error.message);
      process.exitCode = 1;
    })
    .finally(() => db.pool.end());
}

module.exports = migrate;
