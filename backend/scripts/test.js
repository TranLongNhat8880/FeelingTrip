const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const { execFileSync, spawnSync } = require('node:child_process');
const { Pool } = require('pg');
const crypto = require('node:crypto');

/**
 * Isolated integration test runner:
 * - Automatically spins up a temporary PostgreSQL instance (if PG_BIN is present and TEST_DATABASE_URL is not set)
 *   or connects to an existing PostgreSQL test database.
 * - Creates an isolated, random ephemeral schema (`ft_test_<hex>`) for the test run.
 * - Injects scoped DATABASE_URL with `search_path = ft_test_<hex>, public`.
 * - Executes native node tests (`node --test test/*.test.js`).
 * - Cleans up the ephemeral schema and temporary files in `finally` block.
 */
async function main() {
  let tempDirectory;
  let pgCtl;
  let adminPool;

  const testSchema = 'ft_test_' + crypto.randomBytes(8).toString('hex');

  try {
    let databaseUrl = process.env.TEST_DATABASE_URL;

    // Spin up local ephemeral PostgreSQL cluster if TEST_DATABASE_URL is not supplied
    if (!databaseUrl) {
      const binDir =
        process.env.PG_BIN ||
        (process.platform === 'win32' ? 'C:/Program Files/PostgreSQL/18/bin' : '');

      if (!binDir) {
        throw new Error('Set TEST_DATABASE_URL to a dedicated test PostgreSQL or set PG_BIN');
      }

      const tmpRoot = path.resolve(__dirname, '../.tmp');
      fs.mkdirSync(tmpRoot, { recursive: true });
      tempDirectory = fs.mkdtempSync(path.join(tmpRoot, 'postgres-'));

      const getExe = (name) =>
        path.join(binDir, name + (process.platform === 'win32' ? '.exe' : ''));

      pgCtl = getExe('pg_ctl');

      // Pick an open ephemeral port
      const port = await new Promise((resolve) => {
        const server = net.createServer().listen(0, '127.0.0.1', () => {
          const assignedPort = server.address().port;
          server.close(() => resolve(assignedPort));
        });
      });

      // Initialize database cluster
      execFileSync(
        getExe('initdb'),
        [
          '-D', tempDirectory,
          '-U', 'postgres',
          '-A', 'trust',
          '--encoding=UTF8',
          '--no-locale',
        ],
        { windowsHide: true, stdio: 'pipe' }
      );

      // Start cluster
      execFileSync(
        pgCtl,
        [
          '-D', tempDirectory,
          '-l', path.join(tempDirectory, 'server.log'),
          '-o', `-h 127.0.0.1 -p ${port}`,
          '-t', '15',
          '-w', 'start',
        ],
        { windowsHide: true, stdio: 'ignore', timeout: 30000 }
      );

      databaseUrl = `postgresql://postgres@127.0.0.1:${port}/postgres`;
    }

    adminPool = new Pool({
      connectionString: databaseUrl,
      connectionTimeoutMillis: 5000,
    });

    // Create isolated test schema
    await adminPool.query(`CREATE SCHEMA ${testSchema}`);

    // Scope search_path to the ephemeral schema
    const scopedUrl = new URL(databaseUrl);
    scopedUrl.searchParams.set('options', `-c search_path=${testSchema},public`);

    const testEnv = {
      ...process.env,
      NODE_ENV: 'test',
      DATABASE_URL: scopedUrl.toString(),
      JWT_SECRET: 'test-only-random-secret-never-for-deployment',
      GEMINI_API_KEY: 'test-key',
      SEPAY_API_KEY: 'test-webhook-key',
      SEPAY_BANK_BINS: '{"MBBank":"970422"}',
      AI_ALLOW_FALLBACK: 'false',
    };

    const testDir = path.join(__dirname, '../test');
    const testFiles = fs
      .readdirSync(testDir)
      .filter((file) => file.endsWith('.test.js'))
      .map((file) => path.join(testDir, file));

    const testResult = spawnSync(
      process.execPath,
      ['--test', ...testFiles],
      { env: testEnv, stdio: 'inherit', windowsHide: true }
    );

    if (testResult.error) {
      throw testResult.error;
    }

    process.exitCode = testResult.status ?? 1;
  } finally {
    // Drop test schema
    if (adminPool) {
      if (!/^ft_test_[a-f0-9]{16}$/.test(testSchema)) {
        throw new Error('Unsafe test schema name encountered');
      }

      await adminPool
        .query(`DROP SCHEMA IF EXISTS ${testSchema} CASCADE`)
        .catch(() => {
          process.exitCode = 1;
        });

      await adminPool.end();
    }

    // Stop ephemeral Postgres cluster and remove temp dir
    if (tempDirectory) {
      try {
        execFileSync(
          pgCtl,
          ['-D', tempDirectory, '-m', 'immediate', '-t', '15', '-w', 'stop'],
          { windowsHide: true, stdio: 'ignore', timeout: 30000 }
        );
      } catch {
        // initdb or start might not have completed
      }

      const tmpRoot = fs.realpathSync(path.resolve(__dirname, '../.tmp'));
      const targetDir = fs.realpathSync(tempDirectory);

      if (
        path.dirname(targetDir) !== tmpRoot ||
        !path.basename(targetDir).startsWith('postgres-')
      ) {
        throw new Error('Unsafe cleanup path');
      }

      fs.rmSync(targetDir, { recursive: true, force: true });
    }
  }
}

main().catch((error) => {
  console.error('Test execution failed:', error.message);
  process.exitCode = 1;
});
