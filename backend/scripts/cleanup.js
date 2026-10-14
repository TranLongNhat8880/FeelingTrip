const db = require('../src/config/database');

/**
 * Cleanup job for database housekeeping:
 * 1. Purges expired rate limit counters.
 * 2. Purges expired OTP records (while preserving cooldown window for 60s).
 */
async function cleanupDatabase() {
  await db.transaction(async (client) => {
    const limits = await client.query('DELETE FROM request_limits WHERE expires_at < NOW()');
    const otps = await client.query(
      "DELETE FROM auth_otps WHERE expires_at < NOW() AND sent_at < NOW() - INTERVAL '1 minute'"
    );

    console.log(`Cleanup complete: Purged ${limits.rowCount} rate limits, ${otps.rowCount} expired OTPs.`);
  });
}

if (require.main === module) {
  cleanupDatabase()
    .catch((error) => {
      console.error('Database cleanup failed:', error.message);
      process.exitCode = 1;
    })
    .finally(() => db.pool.end());
}

module.exports = cleanupDatabase;
