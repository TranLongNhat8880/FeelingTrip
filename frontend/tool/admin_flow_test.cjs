const {test,before,beforeEach,after}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const root=path.resolve(__dirname,'../../backend');
require(root+'/node_modules/dotenv').config({path:root+'/.env'});
const env=require(root+'/src/config/env');
const {Pool}=require(root+'/node_modules/pg');
const config=env.db;
const connection=config.connectionString||`postgresql://${encodeURIComponent(config.user)}:${encodeURIComponent(config.password)}@${config.host}:${config.port}/${encodeURIComponent(config.name)}`;
const schema='ft_admin_'+crypto.randomBytes(8).toString('hex');
const adminPool=new Pool({connectionString:connection});
let db,server,base,token,ids;
before(async()=>{
  const client=await adminPool.connect();
  try{
    await client.query(`CREATE SCHEMA ${schema}`);
    await client.query(`SET search_path TO ${schema},public`);
    await client.query(fs.readFileSync(root+'/database/schema.sql','utf8'));
    for(const file of fs.readdirSync(root+'/database/migrations').filter(f=>f.endsWith('.sql')).sort())await client.query(fs.readFileSync(root+'/database/migrations/'+file,'utf8'));
    await client.query(fs.readFileSync(__dirname+'/admin_templates.sql','utf8'));
  }finally{client.release();}
  const url=new URL(connection);url.searchParams.set('options',`-c search_path=${schema},public`);process.env.DATABASE_URL=url.toString();
  env.db.connectionString=process.env.DATABASE_URL;
  db=require(root+'/src/config/database');
  token=require(root+'/src/shared/utils/token.util').generateToken;
  server=require(root+'/src/app').listen(0,'127.0.0.1');await new Promise(r=>server.once('listening',r));base=`http://127.0.0.1:${server.address().port}/api/v1`;
});
beforeEach(async()=>{
  await db.query('TRUNCATE admin_template_uses,admin_itinerary_templates,users CASCADE');
  ids={admin:crypto.randomUUID(),leader:crypto.randomUUID(),other:crypto.randomUUID(),trip:crypto.randomUUID(),trip2:crypto.randomUUID()};
  for(const role of ['admin','leader','other'])await db.query(`INSERT INTO users(id,email,full_name,password_hash,is_email_verified,is_verified,verification_status,role) VALUES($1,$2,$3,'test-only',true,true,'VERIFIED',$4)`,[ids[role],`${ids[role]}@test.local`,role,role==='admin'?'ADMIN':'USER']);
  for(const id of [ids.trip,ids.trip2]){
    await db.query(`INSERT INTO trips(id,creator_id,name,destination,start_date,end_date) VALUES($1,$2,'Test template target','Hanoi','2026-11-01','2026-11-02')`,[id,ids.leader]);
    await db.query("INSERT INTO trip_members(trip_id,user_id,role) VALUES($1,$2,'LEADER')",[id,ids.leader]);
  }
});
after(async()=>{
  if(server)await new Promise(r=>server.close(r));
  if(db)await db.pool.end();
  assert.match(schema,/^ft_admin_[0-9a-f]{16}$/);
  await adminPool.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);await adminPool.end();
});
async function req(endpoint,method='GET',body,role='admin'){
  const res=await fetch(base+endpoint,{method,headers:{'Content-Type':'application/json',...(role?{authorization:'Bearer '+token({id:ids[role],tokenVersion:1})}:{})},body:body===undefined?undefined:JSON.stringify(body)});
  return {status:res.status,data:await res.json()};
}
const draft=()=>({name:'Hai ngày khám phá Hà Nội',destination:'Hanoi',durationDays:2,estimatedBudget:500000,description:'Lịch trình gợi ý cho người dùng.',days:[1,2].map(n=>({dayNumber:n,title:'Ngày '+n,items:[{customName:'Tham quan '+n,category:'ATTRACTION',startTime:'09:00',endTime:'10:00',estimatedCost:100000,note:'Giày đi bộ'}]}))});
async function create(data=draft()){const r=await req('/admin/templates','POST',data);assert.equal(r.status,201,JSON.stringify(r.data));return r.data.data;}
test('reports: role checks, required notes, two admins resolve once and private notes stay internal',async()=>{
  const report=(await db.query(`INSERT INTO user_reports(reporter_id,reported_user_id,reason) VALUES($1,$2,'Test báo cáo vi phạm') RETURNING id`,[ids.leader,ids.other])).rows[0];
  assert.equal((await req('/admin/reports','GET',undefined,null)).status,401);
  assert.equal((await req('/admin/reports','GET',undefined,'leader')).status,403);
  assert.equal((await req('/admin/reports/'+report.id)).data.data.status,'PENDING');
  assert.equal((await req('/admin/reports/'+report.id+'/resolve','PUT',{action:'RESOLVED',adminNotes:''})).status,400);
  const results=await Promise.all([req('/admin/reports/'+report.id+'/resolve','PUT',{action:'RESOLVED',adminNotes:'Nội bộ: đã kiểm tra bằng chứng'}),req('/admin/reports/'+report.id+'/resolve','PUT',{action:'DISMISSED',adminNotes:'Kết luận khác'})]);
  assert.deepEqual(results.map(r=>r.status).sort(),[200,409]);
  const notices=(await db.query('SELECT * FROM notifications WHERE user_id=$1',[ids.leader])).rows;
  assert.equal(notices.length,1);assert.ok(!JSON.stringify(notices[0]).includes('Nội bộ'));
  assert.equal((await db.query('SELECT status FROM users WHERE id=$1',[ids.other])).rows[0].status,'ACTIVE');
});
test('templates: validation, CRUD, optimistic version checks and hidden public access',async()=>{
  assert.equal((await req('/admin/templates','POST',draft(),'leader')).status,403);
  const invalid=draft();invalid.days[1].dayNumber=3;assert.equal((await req('/admin/templates','POST',invalid)).status,400);
  const overlap=draft();overlap.days[0].items.push({...overlap.days[0].items[0],startTime:'09:30',endTime:'11:00'});assert.equal((await req('/admin/templates','POST',overlap)).status,400);
  const negative=draft();negative.days[0].items[0].estimatedCost=-1;assert.equal((await req('/admin/templates','POST',negative)).status,400);
  const t=await create();assert.equal((await req('/admin/library','GET',undefined,'leader')).data.data.items.length,1);
  const changed=await req('/admin/templates/'+t.id,'PUT',{...draft(),name:'Mẫu đã chỉnh sửa',expectedVersion:t.version});assert.equal(changed.status,200);
  assert.equal((await req('/admin/templates/'+t.id,'PUT',{...draft(),expectedVersion:t.version})).status,409);
  const hidden=await req('/admin/templates/'+t.id+'/status','PUT',{isActive:false,expectedVersion:changed.data.data.version});assert.equal(hidden.status,200);
  assert.equal((await req('/admin/library/templates/'+t.id,'GET',undefined,'leader')).status,404);
  assert.equal((await req('/admin/library','GET',undefined,'leader')).data.data.items.length,0);
  assert.equal((await req('/admin/templates/'+t.id+'?expectedVersion='+hidden.data.data.version,'DELETE')).status,200);
});
test('apply template: only leader, no overwrite, concurrent apply once, snapshots and delete guard',async()=>{
  const t=await create();const endpoint='/admin/library/templates/'+t.id+'/apply';
  assert.equal((await req(endpoint,'POST',{tripId:ids.trip},'other')).status,403);
  const applied=await Promise.all([req(endpoint,'POST',{tripId:ids.trip},'leader'),req(endpoint,'POST',{tripId:ids.trip},'leader')]);assert.deepEqual(applied.map(r=>r.status).sort(),[200,409]);
  assert.equal((await db.query('SELECT COUNT(*)::int AS n FROM itineraries WHERE trip_id=$1',[ids.trip])).rows[0].n,2);
  assert.equal((await db.query('SELECT COUNT(*)::int AS n FROM admin_template_uses WHERE template_id=$1',[t.id])).rows[0].n,1);
  const current=(await req('/admin/templates/'+t.id)).data.data;
  assert.equal((await req('/admin/templates/'+t.id+'?expectedVersion='+current.version,'DELETE')).status,409);
  const changed=draft();changed.days[0].items[0].customName='Nội dung mới';assert.equal((await req('/admin/templates/'+t.id,'PUT',{...changed,expectedVersion:current.version})).status,200);
  assert.equal((await db.query(`SELECT custom_name FROM itinerary_items item JOIN itineraries day ON day.id=item.itinerary_id WHERE day.trip_id=$1 AND day.day_number=1`,[ids.trip])).rows[0].custom_name,'Tham quan 1');
  const live=(await req('/admin/templates/'+t.id)).data.data;
  assert.equal((await req('/admin/templates/'+t.id+'/status','PUT',{isActive:false,expectedVersion:live.version})).status,200);
  assert.equal((await req(endpoint,'POST',{tripId:ids.trip2},'leader')).status,404);
});
test('apply: wrong duration rejected; insert failure rolls back days and use record',async()=>{
  const t=await create();await db.query("UPDATE trips SET end_date='2026-11-03' WHERE id=$1",[ids.trip]);
  assert.equal((await req('/admin/library/templates/'+t.id+'/apply','POST',{tripId:ids.trip},'leader')).status,400);
  const fail=draft();fail.days[1].items[0].customName='ForceFail';const f=await create(fail);
  await db.query(`CREATE OR REPLACE FUNCTION force_admin_test_failure() RETURNS trigger AS $$ BEGIN IF NEW.custom_name='ForceFail' THEN RAISE EXCEPTION 'Test insert failure'; END IF; RETURN NEW; END; $$ LANGUAGE plpgsql;
    CREATE TRIGGER force_admin_test_failure BEFORE INSERT ON itinerary_items FOR EACH ROW EXECUTE FUNCTION force_admin_test_failure()`);
  try{assert.equal((await req('/admin/library/templates/'+f.id+'/apply','POST',{tripId:ids.trip2},'leader')).status,500);
    assert.equal((await db.query('SELECT COUNT(*)::int AS n FROM itineraries WHERE trip_id=$1',[ids.trip2])).rows[0].n,0);
    assert.equal((await db.query('SELECT COUNT(*)::int AS n FROM admin_template_uses WHERE template_id=$1',[f.id])).rows[0].n,0);
  }finally{await db.query('DROP TRIGGER force_admin_test_failure ON itinerary_items; DROP FUNCTION force_admin_test_failure()');}
});
test('community: list metrics, independent imported template, preserved costs and apply to existing trip',async()=>{
  const source=crypto.randomUUID();await db.query(`INSERT INTO trips(id,creator_id,name,destination,start_date,end_date,status,privacy_type,estimated_budget) VALUES($1,$2,'Community source','Hanoi','2026-10-01','2026-10-02','COMPLETED','PUBLIC',600000)`,[source,ids.leader]);
  await db.query("INSERT INTO trip_members(trip_id,user_id,role) VALUES($1,$2,'LEADER')",[source,ids.leader]);
  for(let i=1;i<=2;i++){const day=(await db.query('INSERT INTO itineraries(trip_id,day_number,title,trip_date) VALUES($1,$2,$3,$4) RETURNING id',[source,i,'Ngày '+i,'2026-10-0'+i])).rows[0];await db.query("INSERT INTO itinerary_items(itinerary_id,custom_name,category,start_time,end_time,estimated_cost) VALUES($1,'Điểm cộng đồng','ATTRACTION','09:00','10:00',150000)",[day.id]);}
  await db.query('INSERT INTO trip_reviews(trip_id,reviewer_id,rating) VALUES($1,$2,4)',[source,ids.leader]);
  const listed=(await req('/admin/library?source=COMMUNITY&sortBy=rating','GET',undefined,'leader')).data.data.items;assert.equal(listed[0].averageRating,4);assert.equal(listed[0].reviewCount,1);
  const imported=await req('/admin/templates/from-community/'+source,'POST');assert.equal(imported.status,201);assert.equal(imported.data.data.sourceTripId,source);assert.equal(imported.data.data.days[0].items[0].estimatedCost,150000);
  assert.equal(imported.data.data.reviewCount,0);
  assert.equal((await req('/admin/library/community/'+source+'/apply','POST',{tripId:ids.trip},'leader')).status,200);
  assert.equal((await db.query('SELECT clone_count FROM trips WHERE id=$1',[source])).rows[0].clone_count,1);
  await db.query("UPDATE trips SET privacy_type='PRIVATE' WHERE id=$1",[source]);assert.equal((await req('/admin/library/community/'+source+'/apply','POST',{tripId:ids.trip2},'leader')).status,404);
});

test('multipart: template cover uploads to Cloudinary and days are parsed from form data', {skip:process.env.TEST_CLOUDINARY!=='true',timeout:60000},async()=>{
  const form=new FormData();const data=draft();for(const [key,value] of Object.entries(data))form.append(key,Array.isArray(value)?JSON.stringify(value):String(value));
  const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jgAAAAABJRU5ErkJggg==','base64');
  form.append('coverImage',new Blob([png],{type:'image/png'}),'admin-test.png');
  const response=await fetch(base+'/admin/templates',{method:'POST',headers:{authorization:'Bearer '+token({id:ids.admin,tokenVersion:1})},body:form});
  const body=await response.json();assert.equal(response.status,201,JSON.stringify(body));
  const url=body.data.coverImageUrl;assert.match(url,/^https:\/\/res\.cloudinary\.com\//);
  const publicId=decodeURIComponent(url.split('/upload/')[1].replace(/^v\d+\//,'').replace(/\.[^/.]+$/,''));
  assert.ok(publicId.startsWith('feelingtrip_uploads/'));
  try{assert.equal(body.data.days.length,2);}finally{await require(root+'/src/config/cloudinary').uploader.destroy(publicId);}
});

test('catalog links: trusted snapshot, persisted placeId, hidden/missing places and community import',async()=>{
  const place=(await db.query(`INSERT INTO places(name,destination,address,category,latitude,longitude) VALUES('Hồ Hoàn Kiếm','Hanoi','Hoàn Kiếm, Hà Nội','ATTRACTION',21.0285,105.8542) RETURNING id`)).rows[0];
  const data=draft();data.days[0].items[0].placeId=place.id.toUpperCase();data.days[0].items[0].customName='Tên giả';data.days[0].items[0].category='OTHER';
  const t=await create(data);assert.equal(t.days[0].items[0].placeId,place.id);assert.equal(t.days[0].items[0].customName,'Hồ Hoàn Kiếm');assert.equal(t.days[0].items[0].category,'ATTRACTION');
  assert.equal((await req('/admin/library/templates/'+t.id+'/apply','POST',{tripId:ids.trip},'leader')).status,200);
  const linked=(await db.query('SELECT item.place_id FROM itinerary_items item JOIN itineraries day ON day.id=item.itinerary_id WHERE day.trip_id=$1 AND day.day_number=1',[ids.trip])).rows[0];assert.equal(linked.place_id,place.id);
  const detail=(await req('/itineraries/trips/'+ids.trip,'GET',undefined,'leader')).data.data;assert.equal(detail.days[0].items[0].placeId,place.id);
  await db.query("UPDATE trips SET status='COMPLETED',privacy_type='PUBLIC' WHERE id=$1",[ids.trip]);
  const imported=await req('/admin/templates/from-community/'+ids.trip,'POST');assert.equal(imported.status,201);assert.equal(imported.data.data.days[0].items[0].placeId,place.id);
  await db.query('UPDATE places SET is_active=false WHERE id=$1',[place.id]);
  assert.equal((await req('/admin/library/templates/'+t.id+'/apply','POST',{tripId:ids.trip2},'leader')).status,409);
  assert.equal((await db.query('SELECT COUNT(*)::int AS n FROM itineraries WHERE trip_id=$1',[ids.trip2])).rows[0].n,0);
  assert.equal((await req('/admin/templates','POST',data)).status,409);
  const missing=draft();missing.days[0].items[0].placeId=crypto.randomUUID();assert.equal((await req('/admin/templates','POST',missing)).status,409);
  const free=draft();free.days[0].items[0].placeId=null;assert.equal((await req('/admin/templates','POST',free)).status,201);
});

async function companionPost(){
 const response=await req('/companions/posts','POST',{tripId:ids.trip,title:'Tìm bạn đồng hành test',content:'Nội dung kiểm thử đầy đủ',targetMembersCount:3},'leader');
 assert.equal(response.status,201);
 return response.data.data.id;
}
test('companion lifecycle: edit, sent requests privacy, cancellation persistence and close',async()=>{
 const post=await companionPost();
 assert.equal((await req('/companions/my-posts','GET',undefined,'leader')).data.data[0].id,post);
 assert.equal((await req('/companions/my-posts','GET',undefined,'other')).data.data.length,0);
 assert.equal((await req('/companions/posts/'+post,'PATCH',{title:'Tiêu đề đã sửa'},'other')).status,403);
 assert.equal((await req('/companions/posts/'+post,'PATCH',{title:'Tiêu đề đã sửa'},'leader')).status,200);
 assert.equal((await req('/companions/join-request','POST',{postId:post,introduction:'Xin tham gia chuyến đi'},'other')).status,201);
 const detail=(await req('/companions/posts/'+post,'GET',undefined,'other')).data.data;
 assert.equal(detail.myRequestStatus,'PENDING');assert.ok(detail.myRequestId);
 const sent=(await req('/companions/sent-requests','GET',undefined,'other')).data.data.requests;
 assert.equal(sent.length,1);assert.equal(sent[0].id,detail.myRequestId);
 assert.equal((await req('/companions/sent-requests','GET',undefined,'leader')).data.data.requests.length,0);
 assert.equal((await req('/companions/sent-requests','GET',undefined,null)).status,401);
 assert.equal((await req('/companions/requests/'+detail.myRequestId,'DELETE',undefined,'leader')).status,403);
 assert.equal((await req('/companions/requests/'+detail.myRequestId,'DELETE',undefined,'other')).status,200);
 assert.equal((await req('/companions/posts/'+post,'GET',undefined,'other')).data.data.myRequestStatus,null);
 assert.equal((await req('/companions/sent-requests','GET',undefined,'other')).data.data.requests.length,0);
 assert.equal((await req('/companions/posts/'+post,'DELETE',undefined,'leader')).status,200);
 assert.equal((await req('/companions/posts/'+post,'GET',undefined,'other')).status,404);
});
test('moderation: report context, admin permissions, reason, warning, hide and blocked acceptance',async()=>{
 const post=await companionPost();
 const report=(await db.query("INSERT INTO user_reports(reporter_id,reported_user_id,reported_trip_id,reason) VALUES($1,$2,$3,'Nội dung cần xem xét') RETURNING id",[ids.other,ids.leader,ids.trip])).rows[0];
 const context=(await req('/admin/reports/'+report.id)).data.data.context;
 assert.equal(context.user.id,ids.leader);assert.equal(context.trip.id,ids.trip);assert.equal(context.posts[0].id,post);
 assert.ok(!JSON.stringify(context).includes('password_hash'));assert.ok(!JSON.stringify(context).includes('bank_account'));
 assert.equal((await req('/admin/moderation/posts','GET',undefined,'other')).status,403);
 const items=(await req('/admin/moderation/posts')).data.data.items;
 assert.equal(items[0].report_count,1);
 assert.equal((await req('/admin/moderation/posts/'+post,'PUT',{action:'HIDE',reason:''})).status,400);
 assert.equal((await req('/admin/moderation/posts/'+post,'PUT',{action:'WARN',reason:'Kiểm tra thông tin tuyển thành viên'})).status,200);
 assert.equal((await req('/companions/posts/'+post,'GET',undefined,'other')).status,200);
 assert.equal((await req('/companions/join-request','POST',{postId:post,introduction:'Xin tham gia chuyến đi'},'other')).status,201);
 const request=(await req('/companions/posts/'+post,'GET',undefined,'other')).data.data.myRequestId;
 assert.equal((await req('/admin/moderation/posts/'+post,'PUT',{action:'HIDE',reason:'Thông tin bài tuyển vi phạm'})).status,200);
 assert.equal((await req('/companions/requests/'+request,'PUT',{status:'ACCEPTED'},'leader')).status,400);
 assert.equal((await req('/admin/moderation/posts/'+post,'PUT',{action:'HIDE',reason:'Ẩn lần hai'})).status,409);
 assert.equal((await db.query('SELECT status FROM trips WHERE id=$1',[ids.trip])).rows[0].status,'UPCOMING');
 const warnings=await Promise.all([req('/admin/reports/'+report.id+'/warn','PUT',{reason:'Đã kiểm tra và gửi cảnh cáo'}),req('/admin/reports/'+report.id+'/warn','PUT',{reason:'Cảnh cáo trùng'})]);
 assert.deepEqual(warnings.map(r=>r.status).sort(),[200,409]);
 assert.equal((await req('/admin/reports/'+report.id)).data.data.status,'RESOLVED');
});
