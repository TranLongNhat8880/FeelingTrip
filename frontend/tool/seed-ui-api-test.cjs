const path = require('path');
const root = path.resolve(__dirname, '../../backend');
const db = require(path.join(root, 'src/config/database'));
const bcrypt = require(path.join(root, 'node_modules/bcryptjs'));
const fs = require('fs');
(async () => {
  const columns = await db.query("SELECT column_name FROM information_schema.columns WHERE table_name='users'");
  if (!columns.rows.some(r => r.column_name === 'token_version')) throw Error('Database chưa có migration token_version');
  const password = 'LocalApiTest@2026';
  const hash = await bcrypt.hash(password, 10);
  const users = {};
  const runId = Date.now();
  for (const [key, role, verified, verification, status] of [
    ['admin','ADMIN',true,'VERIFIED','ACTIVE'],
    ['leader','USER',true,'VERIFIED','ACTIVE'],
    ['member','USER',true,'VERIFIED','ACTIVE'],
    ['pending','USER',false,'PENDING','ACTIVE'],
    ['reject','USER',false,'PENDING','ACTIVE'],
    ['banned','USER',false,'UNVERIFIED','BANNED'],
  ]) {
    const email = `api.${key}.${runId}@example.com`;
    const existing = await db.query('SELECT id FROM users WHERE email=$1',[email]);
    if (existing.rowCount) throw Error(`Tài khoản test đã tồn tại: ${key}; tránh ghi đè`);
    const row = await db.query(`INSERT INTO users (email,password_hash,full_name,role,status,is_email_verified,is_verified,verification_status,cccd_number)
      VALUES ($1,$2,$3,$4,$5,true,$6,$7,$8) RETURNING id`,
      [email, hash, `API Test ${key}`, role,status,verified,verification, verification==='PENDING'?'TEST-ONLY-0001':null]);
    users[key] = {id:row.rows[0].id,email};
  }
  const row = await db.query(`INSERT INTO trips (creator_id,name,destination,start_date,end_date,estimated_budget,privacy_type)
    VALUES ($1,'API Test - Hành trình Hội An','Hội An, Quảng Nam','2026-11-01','2026-11-04',3500000,'PUBLIC') RETURNING id`,[users.leader.id]);
  const tripId = row.rows[0].id;
  await db.query("INSERT INTO trip_members(trip_id,user_id,role) VALUES($1,$2,'LEADER')",[tripId,users.leader.id]);
  const fixture = {password,users,tripId};
  const directory = path.resolve(root, '../frontend/.tmp');
  fs.mkdirSync(directory,{recursive:true});
  fs.writeFileSync(path.join(directory, 'api-fixture.json'),JSON.stringify(fixture));
  console.log('Đã tạo 6 tài khoản và 1 chuyến đi test riêng. Fixture lưu tại frontend/.tmp/api-fixture.json');
})().catch(e=>{console.error(e.message);process.exitCode=1}).finally(()=>db.pool.end());
