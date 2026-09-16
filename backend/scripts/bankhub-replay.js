// Local operator recovery; never expose replay as an unauthenticated HTTP endpoint.
const db = require('../src/config/database');
const { processIpn, processEvent } = require('../src/features/bankhub/bankhub.service');
async function main() {
  const events = await db.query('SELECT xid FROM bankhub_events WHERE processed_at IS NULL ORDER BY received_at LIMIT 100');
  for (const row of events.rows) {
    try { await processEvent(row.xid); console.log('Processed event', row.xid); }
    catch { console.error('Event still pending', row.xid); process.exitCode = 1; }
  }
  const { rows } = await db.query('SELECT transaction_id FROM bankhub_ipn WHERE processed_at IS NULL ORDER BY received_at LIMIT 100');
  for (const row of rows) {
    try { await processIpn(row.transaction_id); console.log('Processed IPN', row.transaction_id); }
    catch { console.error('IPN still pending', row.transaction_id); process.exitCode = 1; }
  }
}
main().catch(() => { process.exitCode = 1; }).finally(() => db.pool.end());
