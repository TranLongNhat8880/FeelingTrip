const path = require('node:path');
const fs = require('node:fs');
const root = path.resolve(__dirname, '../../backend');
require(root + '/node_modules/dotenv').config({ path: root + '/.env' });
const db = require(root + '/src/config/database');
db.transaction(client => client.query(fs.readFileSync(path.join(__dirname, 'admin_templates.sql'), 'utf8')))
  .then(() => console.log('Admin template tables are ready.'))
  .catch(error => { console.error(error.message); process.exitCode = 1; })
  .finally(() => db.pool.end());
