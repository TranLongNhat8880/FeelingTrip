const db = require('../../config/database');
const service = require('./bankhub.service');

async function retryPending() {
  // Fixed table names only; user input never participates in SQL identifiers.
  for (const [table,key,process] of [
    ['bankhub_events','xid',service.processEvent],
    ['bankhub_ipn','transaction_id',service.processIpn],
  ]) {
    const { rows } = await db.query(`SELECT ${key} AS id FROM ${table}
      WHERE processed_at IS NULL AND retry_at<=NOW() ORDER BY retry_at LIMIT 20`);
    for (const row of rows) {
      try { await process(row.id); }
      catch {
        await db.query(`UPDATE ${table} SET attempts=attempts+1,
          retry_at=NOW()+LEAST(3600,15*POWER(2,LEAST(attempts,8)))*INTERVAL '1 second'
          WHERE ${key}=$1 AND processed_at IS NULL`,[row.id]);
      }
    }
  }
}
function startWorker() {
  let running = false;
  const timer = setInterval(async () => {
    if (running) return;
    running = true;
    try { await retryPending(); }
    catch { console.error('Bank Hub recovery failed; check migration/database availability'); }
    finally { running = false; }
  },15000);
  timer.unref();
  return () => clearInterval(timer);
}
module.exports = { retryPending, startWorker };
