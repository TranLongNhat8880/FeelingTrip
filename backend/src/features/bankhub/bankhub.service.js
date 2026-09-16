const crypto = require('crypto');
const Joi = require('joi');
const db = require('../../config/database');
const env = require('../../config/env');
const provider = require('./bankhub.client');
const expensesRepo = require('../expenses/expenses.repository');
const apiError = require('../../shared/utils/apiError.util');
const { MAX_VND } = require('../../shared/utils/money.util');

const uuid = Joi.string().guid().lowercase().required();
const parse = (schema, input) => {
  const { value, error } = schema.validate(input, { stripUnknown: true, convert: false });
  if (error) throw apiError(400, 'Dữ liệu Bank Hub không hợp lệ');
  return value;
};
const authenticateSecret = (actual, expected) => {
  if (!expected) throw apiError(503, 'Chưa cấu hình xác thực Bank Hub');
  const hash = (s) => crypto.createHash('sha256').update(s).digest();
  if (typeof actual !== 'string' || !crypto.timingSafeEqual(hash(actual), hash(expected))) {
    throw apiError(401, 'Xác thực Bank Hub không hợp lệ');
  }
};

const createLink = async (userId, purpose = 'LINK_BANK_ACCOUNT', accountId) => {
  if (!env.bankhub.eventSecret || !env.bankhub.ipnKey) {
    throw apiError(503, 'Cần cấu hình webhook và IPN Bank Hub trước khi liên kết');
  }
  // Serialize provisioning per user; an uncertain provider create is recovered by
  // its deterministic name on the next request, rather than creating duplicates.
  const companyId = await db.transaction(async (client) => {
    await client.query('SELECT id FROM users WHERE id = $1 FOR UPDATE', [userId]);
    const { rows: [existing] } = await client.query(
      'SELECT company_xid FROM bankhub_companies WHERE user_id = $1', [userId]);
    if (existing) return existing.company_xid;
    const name = `FeelingTrip-${userId}`;
    const found = await provider.call('/company?' + new URLSearchParams({ q: name, per_page: '100' }));
    if (!Array.isArray(found.data)) throw apiError(502, 'Phản hồi Bank Hub không hợp lệ');
    let company = found.data.find((c) => c.full_name === name);
    if (!company) company = (await provider.call('/company/create', { full_name: name, status: 'Active' })).data;
    const xid = parse(uuid, company?.xid);
    await client.query('INSERT INTO bankhub_companies(user_id, company_xid) VALUES ($1,$2)', [userId, xid]);
    return xid;
  });
  const body = { company_xid: companyId, purpose, is_mobile_app: 1, language: 'vi' };
  if (purpose !== 'LINK_BANK_ACCOUNT') {
    const { rows: [account] } = await db.query(
      'SELECT xid FROM bankhub_accounts WHERE xid=$1 AND user_id=$2', [accountId, userId]);
    if (!account) throw apiError(404, 'Không tìm thấy tài khoản ngân hàng');
    body.bank_account_xid = account.xid;
  }
  if (env.bankhub.redirectUri) body.completion_redirect_uri = env.bankhub.redirectUri;
  const link = await provider.call('/link-token/create', body);
  const xid = parse(uuid, link.xid);
  let url;
  try { url = new URL(link.hosted_link_url); } catch { throw apiError(502, 'Link Bank Hub không hợp lệ'); }
  if (url.protocol !== 'https:' || !url.hostname.endsWith('.sepay.vn') || url.username || url.password) {
    throw apiError(502, 'Link Bank Hub không hợp lệ');
  }
  await db.query('INSERT INTO bankhub_links(xid,user_id,purpose) VALUES ($1,$2,$3)', [xid,userId,purpose]);
  return { hostedLinkUrl: url.href, expiresAt: link.expires_at };
};

const listAccounts = async (userId) => {
  const { rows } = await db.query(`SELECT a.xid AS id, a.brand_name AS "bankName",
    a.account_number AS "accountNumber", a.account_holder_name AS "accountHolderName",
    a.active AS "isLinked", (u.bank_bin=a.bank_bin AND u.bank_account_number=a.account_number) AS "isDefault"
    FROM bankhub_accounts a JOIN users u ON u.id=a.user_id WHERE a.user_id=$1`, [userId]);
  return rows;
};

const processEvent = async (id) => {
  const { rows: [saved] } = await db.query('SELECT * FROM bankhub_events WHERE xid=$1', [id]);
  if (!saved) throw apiError(404, 'Không tìm thấy sự kiện Bank Hub');
  if (saved.processed_at) return { success: true };
  const event = saved.payload;
  const supported = ['BANK_ACCOUNT_LINKED','BANK_ACCOUNT_REACTIVATED','BANK_ACCOUNT_UNLINKED',
    'BANK_ACCOUNT_INACTIVED','BANK_ACCOUNT_INACTIVATED'];
  if (!supported.includes(event.event)) {
    await db.query('UPDATE bankhub_events SET processed_at=NOW() WHERE xid=$1', [id]);
    return { success: true };
  }
  const accountId = parse(uuid, event.metadata.bank_account_xid);
  // Query provider state: do not trust browser redirects or accept an arbitrary account ID.
  const account = (await provider.call(`/bank-account/${accountId}`)).data;
  if (!account || account.xid !== accountId) throw apiError(502, 'Không xác minh được tài khoản ngân hàng');
  return db.transaction(async (client) => {
    const { rows: [locked] } = await client.query('SELECT processed_at FROM bankhub_events WHERE xid=$1 FOR UPDATE', [id]);
    if (locked.processed_at) return { success: true };
    await client.query('UPDATE bankhub_events SET processed_at=NOW() WHERE xid=$1', [id]);
    const { rows: [owner] } = await client.query(
      'SELECT user_id FROM bankhub_companies WHERE company_xid=$1', [parse(uuid, account.company_xid)]);
    if (!owner) throw apiError(409, 'Không tìm thấy người dùng liên kết');
    await client.query('SELECT id FROM users WHERE id=$1 FOR UPDATE', [owner.user_id]);
    const { rows: [old] } = await client.query('SELECT * FROM bankhub_accounts WHERE xid=$1 FOR UPDATE', [accountId]);
    if (old && Number(old.event_timestamp) > event.timestamp) return { success: true };
    if (old && old.user_id !== owner.user_id) throw apiError(409, 'Tài khoản đã thuộc người dùng khác');
    const bin = String(env.sepayBankBins[account.brand_name] || '');
    if (!/^\d{6}$/.test(bin)) throw apiError(503, 'Chưa cấu hình BIN của ngân hàng này');
    if (!/^[a-zA-Z0-9]{1,50}$/.test(account.account_number || '') || !account.account_holder_name) {
      throw apiError(502, 'Thông tin tài khoản Bank Hub không hợp lệ');
    }
    const active = ['BANK_ACCOUNT_LINKED','BANK_ACCOUNT_REACTIVATED'].includes(event.event)
      && String(account.active) === '1' && String(account.bank_api_connected) === '1';
    await client.query(`INSERT INTO bankhub_accounts(xid,user_id,bank_bin,brand_name,account_number,
      account_holder_name,active,event_timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
      ON CONFLICT(xid) DO UPDATE SET active=EXCLUDED.active,event_timestamp=EXCLUDED.event_timestamp`,
    [accountId,owner.user_id,bin,account.brand_name,account.account_number,account.account_holder_name,active,event.timestamp]);
    if (active) {
      await client.query(`UPDATE users SET bank_bin=$2,bank_name=$3,bank_account_number=$4,bank_account_name=$5 WHERE id=$1`,
        [owner.user_id,bin,account.brand_name,account.account_number,account.account_holder_name]);
    } else {
      await client.query(`UPDATE users SET bank_bin=NULL,bank_name=NULL,bank_account_number=NULL,bank_account_name=NULL
        WHERE id=$1 AND bank_bin=$2 AND bank_account_number=$3`, [owner.user_id,bin,account.account_number]);
    }
    return { success: true };
  });
};

const handleEvent = async (input, secret) => {
  authenticateSecret(secret, env.bankhub.eventSecret);
  const event = parse(Joi.object({ xid: uuid, timestamp: Joi.number().integer().min(0).required(),
    event: Joi.string().max(100).required(), metadata: Joi.object().unknown(true).required() }), input);
  await db.query(`INSERT INTO bankhub_events(xid,payload) VALUES ($1,$2) ON CONFLICT(xid) DO NOTHING`,
    [event.xid, JSON.stringify(event)]);
  return processEvent(event.xid);
};

const ipnSchema = Joi.object({ transaction_id: Joi.string().max(150).required(), bank_account_xid: uuid,
  gateway: Joi.string().max(100).required(), account_number: Joi.string().max(50).required(),
  transfer_type: Joi.string().valid('credit','debit').required(),
  amount: Joi.number().integer().min(0).max(MAX_VND).required(),
  content: Joi.string().max(2000).allow('').required() });

const processIpn = (transactionId) => db.transaction(async (client) => {
  const { rows: [inbox] } = await client.query('SELECT * FROM bankhub_ipn WHERE transaction_id=$1 FOR UPDATE', [transactionId]);
  if (!inbox) throw apiError(404, 'Không tìm thấy IPN');
  if (inbox.processed_at) return { success: true };
  const event = inbox.payload;
  const finish = async (result) => {
    await client.query('UPDATE bankhub_ipn SET processed_at=NOW(),result=$2 WHERE transaction_id=$1', [transactionId,result]);
    return { success: true };
  };
  if (event.transfer_type !== 'credit') return finish('IGNORED_DEBIT');
  const refs = [...event.content.matchAll(/\bFT\s*([a-f0-9]{32})\b/gi)];
  if (refs.length !== 1) return finish('UNMATCHED_REFERENCE');
  const initial = await expensesRepo.findSettlementByReference(refs[0][1], client);
  if (!initial) return finish('UNMATCHED_SETTLEMENT');
  await expensesRepo.lockTrip(client, initial.trip_id);
  const settlement = await expensesRepo.findSettlementById(initial.id, client);
  const { rows: [account] } = await client.query('SELECT * FROM bankhub_accounts WHERE xid=$1', [event.bank_account_xid]);
  if (!account) throw apiError(409, 'Chưa nhận được kết quả liên kết ngân hàng; cần xử lý lại IPN');
  // Historical links still identify valid delayed payments after unlinking.
  if (account.user_id !== settlement.to_user_id || account.brand_name !== event.gateway ||
      account.account_number !== event.account_number || settlement.bank_bin !== account.bank_bin ||
      settlement.bank_account_number !== event.account_number || Number(settlement.amount) !== event.amount) {
    return finish('MISMATCH_REQUIRES_REVIEW');
  }
  if (settlement.status === 'CANCELLED') return finish('CANCELLED_REQUIRES_REVIEW');
  if (settlement.status === 'PAID') return finish('ALREADY_PAID');
  await expensesRepo.updateSettlementStatus(settlement.id, 'PAID', client);
  return finish('PAID');
});

const handleIpn = async (input, authorization) => {
  authenticateSecret(authorization, env.bankhub.ipnKey ? `Apikey ${env.bankhub.ipnKey}` : null);
  const event = parse(ipnSchema, input);
  await db.query(`INSERT INTO bankhub_ipn(transaction_id,payload) VALUES ($1,$2)
    ON CONFLICT(transaction_id) DO NOTHING`, [event.transaction_id,JSON.stringify(event)]);
  return processIpn(event.transaction_id);
};

module.exports = { createLink, listAccounts, handleEvent, handleIpn, processIpn, processEvent, authenticateSecret };
