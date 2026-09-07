const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const db = require('../src/config/database');
const email = require('../src/shared/services/email.service');
const sentEmails = new Map();
email.sendOtpEmail = async (address, otp) => sentEmails.set(address, otp);

const auth = require('../src/features/auth/auth.service');
const expenses = require('../src/features/expenses/expenses.service');
const ai = require('../src/features/ai-planner/aiPlanner.service');
const app = require('../src/app');
const { hashPassword } = require('../src/shared/utils/hash.util');
const { generateToken } = require('../src/shared/utils/token.util');
const env = require('../src/config/env');
const migrate = require('../scripts/migrate');

let server;
let baseUrl;
let userA;
let userB;
let outsiderUser;
let tripId;
let defaultPasswordHash;

const joinTasks = async (tasks) => {
  const results = await Promise.allSettled(tasks);
  const failed = results.find((r) => r.status === 'rejected');
  if (failed) throw failed.reason;
  return results.map((r) => r.value);
};

const createAuthToken = (userId) => generateToken({ id: userId, tokenVersion: 1 });

const request = async (url, method = 'GET', body, user = userA, headers = {}) => {
  const response = await fetch(`${baseUrl}/api/v1${url}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(user ? { authorization: `Bearer ${createAuthToken(user)}` } : {}),
      ...headers,
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
};

const createBillPayload = (overrides = {}) => ({
  tripId,
  payerId: userA,
  title: 'Dinner',
  amount: 100000,
  splits: [userA, userB],
  ...overrides,
});

const createDebt = async () => {
  await expenses.createExpense(createBillPayload(), userA);
  const settlements = await expenses.settleTripDebts(tripId, userA);
  return settlements[0];
};

const createWebhookPayload = (debt) => ({
  id: 123,
  gateway: 'MBBank',
  accountNumber: '123456789',
  transferType: 'in',
  transferAmount: debt.amount,
  content: `FT ${debt.id.replaceAll('-', '').toUpperCase()}`,
});

const webhookKey = 'Apikey test-webhook-key';

before(async () => {
  // Ensure we are operating within an ephemeral test schema
  const { rows } = await db.query('SELECT current_schema() AS s');
  assert.match(rows[0].s, /^ft_test_/);

  const schemaSql = fs.readFileSync(path.join(__dirname, '../database/schema.sql'), 'utf8');
  await db.query(schemaSql);

  // Verify migrations are idempotent
  await migrate();
  await migrate();

  // Fresh schema can be re-run safely without duplicate trigger errors
  await db.query(schemaSql);

  defaultPasswordHash = await hashPassword('Password123');

  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

beforeEach(async () => {
  await db.query('TRUNCATE users, request_limits CASCADE');
  sentEmails.clear();

  [userA, userB, outsiderUser, tripId] = Array.from({ length: 4 }, () => crypto.randomUUID());

  for (const id of [userA, userB, outsiderUser]) {
    await db.query(
      `INSERT INTO users (id, email, full_name, password_hash, is_email_verified, bank_bin, bank_account_number)
       VALUES ($1, $2, 'Test', $3, TRUE, '970422', '123456789')`,
      [id, `${id}@test.local`, defaultPasswordHash]
    );
  }

  await db.query(
    `INSERT INTO trips (id, creator_id, name, destination, start_date, end_date)
     VALUES ($1, $2, 'Test', 'Hanoi', '2026-09-07', '2026-09-08')`,
    [tripId, userA]
  );

  for (const id of [userA, userB]) {
    await db.query(
      'INSERT INTO trip_members (trip_id, user_id, role) VALUES ($1, $2, $3)',
      [tripId, id, id === userA ? 'LEADER' : 'MEMBER']
    );
  }
});

after(async () => {
  if (server) {
    await new Promise((resolve) => server.close(resolve));
  }
  await db.pool.end();
});

test('registration, OTP activation, login, reset and revocation work through HTTP', async () => {
  const address = 'new@test.local';

  // 1. Register new account
  const regRes = await request(
    '/auth/register',
    'POST',
    { email: address, password: 'Password123', fullName: 'New User' },
    null
  );
  assert.equal(regRes.status, 201);

  // 2. Unverified login should be blocked
  const loginBlocked = await request(
    '/auth/login',
    'POST',
    { email: address, password: 'Password123' },
    null
  );
  assert.equal(loginBlocked.status, 403);

  // 3. Verify OTP
  const otp = sentEmails.get(address);
  assert.match(otp, /^\d{6}$/);

  const verified = await request(
    '/auth/verify-otp',
    'POST',
    { email: address, otp },
    null
  );
  assert.equal(verified.status, 200);
  const oldToken = verified.body.data.token;

  // Reusing same OTP must fail
  const reVerify = await request(
    '/auth/verify-otp',
    'POST',
    { email: address, otp },
    null
  );
  assert.equal(reVerify.status, 400);

  // 4. Login after verification
  const loginSuccess = await request(
    '/auth/login',
    'POST',
    { email: address, password: 'Password123' },
    null
  );
  assert.equal(loginSuccess.status, 200);

  // 5. Password reset revokes previous tokens
  await request('/auth/forgot-password', 'POST', { email: address }, null);
  const resetRes = await request(
    '/auth/reset-password',
    'POST',
    { email: address, otp: sentEmails.get(address), newPassword: 'NewPassword123' },
    null
  );
  assert.equal(resetRes.status, 200);

  // Old token is invalidated
  const protectedRes = await request(
    `/expenses/trip/${tripId}`,
    'GET',
    undefined,
    null,
    { authorization: `Bearer ${oldToken}` }
  );
  assert.equal(protectedRes.status, 401);
});

test('OTP failures are persisted, limited to five attempts and sending has a cooldown', async () => {
  await auth.register({ email: 'otp@test.local', password: 'Password123', fullName: 'OTP User' });
  const otp = sentEmails.get('otp@test.local');

  // Cooldown rejected
  await assert.rejects(auth.resendOtp({ email: 'otp@test.local' }), { status: 429 });

  // 5 invalid attempts
  for (let i = 0; i < 5; i++) {
    await assert.rejects(
      auth.verifyOtp({ email: 'otp@test.local', otp: '000000' }),
      { status: 400 }
    );
  }

  // 6th attempt with correct OTP is locked out
  await assert.rejects(auth.verifyOtp({ email: 'otp@test.local', otp }), { status: 400 });

  const { rows } = await db.query('SELECT attempts FROM auth_otps');
  assert.equal(rows[0].attempts, 5);
});

test('expired OTP cannot activate the user', async () => {
  await auth.register({ email: 'expired@test.local', password: 'Password123', fullName: 'Expired User' });
  await db.query("UPDATE auth_otps SET expires_at = NOW() - INTERVAL '1 second'");
  await assert.rejects(
    auth.verifyOtp({ email: 'expired@test.local', otp: sentEmails.get('expired@test.local') }),
    { status: 400 }
  );
});

test('new passwords cannot exceed the bcrypt UTF-8 byte limit', async () => {
  const result = await request(
    '/auth/register',
    'POST',
    {
      email: 'long@test.local',
      fullName: 'Long Password',
      password: 'ậ'.repeat(30),
    },
    null
  );
  assert.equal(result.status, 400);

  const { rows } = await db.query("SELECT COUNT(*)::int AS n FROM users WHERE email='long@test.local'");
  assert.equal(rows[0].n, 0);
});

test('ban, unban and current role invalidate or constrain existing JWTs', async () => {
  await db.query("UPDATE users SET status = 'BANNED' WHERE id = $1", [userA]);
  assert.equal((await request(`/expenses/trip/${tripId}`)).status, 401);

  await db.query("UPDATE users SET status = 'ACTIVE' WHERE id = $1", [userA]);
  assert.equal((await request(`/expenses/trip/${tripId}`)).status, 401);
});

test('auth rate limit is enforced across requests', async () => {
  for (let i = 0; i < 40; i++) {
    await request('/auth/login', 'POST', {}, null);
  }
  const blocked = await request('/auth/login', 'POST', {}, null);
  assert.equal(blocked.status, 429);
});

test('outsiders cannot read, create or settle another trip', async () => {
  for (const suffix of ['', '/balances']) {
    const res = await request(`/expenses/trip/${tripId}${suffix}`, 'GET', undefined, outsiderUser);
    assert.equal(res.status, 403);
  }

  const createRes = await request('/expenses', 'POST', createBillPayload(), outsiderUser);
  assert.equal(createRes.status, 403);

  const settleRes = await request(`/expenses/trip/${tripId}/settle`, 'POST', {}, outsiderUser);
  assert.equal(settleRes.status, 403);

  const { rows } = await db.query('SELECT COUNT(*)::int AS n FROM expenses');
  assert.equal(rows[0].n, 0);
});

test('payerId survives validation; member checks and notifications are transactional', async () => {
  const response = await request('/expenses', 'POST', createBillPayload({ payerId: userB }));
  assert.equal(response.status, 201);
  assert.equal(response.body.data.expense.payer_id, userB);

  const notifCount = await db.query('SELECT COUNT(*)::int AS n FROM notifications');
  assert.equal(notifCount.rows[0].n, 2);

  // Including an outsider in splits must roll back entire transaction
  const invalidSplitRes = await request(
    '/expenses',
    'POST',
    createBillPayload({ splits: [userA, outsiderUser] })
  );
  assert.equal(invalidSplitRes.status, 403);

  const expenseCount = await db.query('SELECT COUNT(*)::int AS n FROM expenses');
  assert.equal(expenseCount.rows[0].n, 1);
});

test('bad splits, duplicate members, fractions and mismatched exact totals are rejected', async () => {
  const invalidInputs = [
    { splits: [{}] },
    { splits: [userA, userA] },
    { amount: 1.5 },
    { splitType: 'EXACT', amount: 100, splits: [{ userId: userA, amountOwed: 99 }] },
    { splitType: 'EXACT', splits: [{ userId: userA, amountOwed: -1 }] },
    { splitType: 'PERCENTAGE', splits: [{ userId: userA, percentage: 99 }] },
  ];

  for (const input of invalidInputs) {
    const res = await request('/expenses', 'POST', createBillPayload(input));
    assert.equal(res.status, 400);
  }
});

test('percentage rounding never makes a zero-percent member owe a negative amount', async () => {
  await db.query('INSERT INTO trip_members (trip_id, user_id) VALUES ($1, $2)', [tripId, outsiderUser]);

  const result = await expenses.createExpense(
    createBillPayload({
      amount: 1,
      splitType: 'PERCENTAGE',
      splits: [
        { userId: userA, percentage: 0 },
        { userId: userB, percentage: 50 },
        { userId: outsiderUser, percentage: 50 },
      ],
    }),
    userA
  );

  assert.deepEqual(
    result.splits.map((s) => Number(s.amount_owed)),
    [0, 1, 0]
  );
});

test('report and receiver confirmation are separate; paid debt is not generated again', async () => {
  const debt = await createDebt();

  // Receiver cannot confirm before debtor reports
  await assert.rejects(expenses.confirmSettlement(debt.id, userA), { status: 409 });

  // Receiver cannot report on behalf of debtor
  await assert.rejects(expenses.markSettlementPaid(debt.id, userA), { status: 403 });

  // Debtor reports payment
  const reported = await expenses.markSettlementPaid(debt.id, userB);
  assert.equal(reported.settlement.status, 'REPORTED');

  // Debtor cannot confirm their own payment
  await assert.rejects(expenses.confirmSettlement(debt.id, userB), { status: 403 });

  // Re-settling is locked while a payment is REPORTED
  await assert.rejects(expenses.settleTripDebts(tripId, userA), { status: 409 });

  // Creditor confirms payment
  const confirmed = await expenses.confirmSettlement(debt.id, userA);
  assert.equal(confirmed.settlement.status, 'PAID');

  // Paid debts are not regenerated
  assert.deepEqual(await expenses.settleTripDebts(tripId, userA), []);

  const balances = await expenses.getTripBalances(tripId, userA);
  assert.ok(balances.every((u) => u.netBalance === 0));
});

test('concurrent settlement generation preserves one set of QR ids', async () => {
  await expenses.createExpense(createBillPayload(), userA);

  const results = await joinTasks(
    Array.from({ length: 4 }, () => expenses.settleTripDebts(tripId, userA))
  );

  assert.equal(new Set(results.map((r) => r[0].id)).size, 1);

  const { rows } = await db.query('SELECT COUNT(*)::int AS n FROM settlements');
  assert.equal(rows[0].n, 1);
});

test('former members keep their financial balance', async () => {
  await expenses.createExpense(createBillPayload(), userA);
  await db.query('DELETE FROM trip_members WHERE trip_id = $1 AND user_id = $2', [tripId, userB]);

  const balances = await expenses.getTripBalances(tripId, userA);
  const memberB = balances.find((u) => u.userId === userB);
  assert.equal(memberB.netBalance, -50000);
});

test('budget updates require the leader role', async () => {
  const memberAttempt = await request(
    `/expenses/trip/${tripId}/budget`,
    'PUT',
    { estimatedBudget: 200000 },
    userB
  );
  assert.equal(memberAttempt.status, 403);

  const leaderAttempt = await request(
    `/expenses/trip/${tripId}/budget`,
    'PUT',
    { estimatedBudget: 200000 },
    userA
  );
  assert.equal(leaderAttempt.status, 200);

  await expenses.createExpense(createBillPayload(), userA);
  const tripSummary = await expenses.getTripExpenses(tripId, userA);
  assert.equal(tripSummary.summary.remainingBudget, 100000);
});

test('SePay requires authentication, valid amount, matching bank and recipient', async () => {
  const debt = await createDebt();

  // Missing authentication
  await assert.rejects(expenses.handleSepayWebhook(createWebhookPayload(debt)), { status: 401 });

  // Hardcoded fallback keys rejected
  await assert.rejects(
    expenses.handleSepayWebhook(
      createWebhookPayload(debt),
      'Apikey feelingtrip_sepay_webhook_secret_key_2026'
    ),
    { status: 401 }
  );

  // Malformed or mismatched payload values
  const invalidPayloads = [
    { transferAmount: undefined },
    { transferAmount: 'NaN' },
    { transferAmount: 1 },
    { accountNumber: 'wrong' },
  ];

  for (const override of invalidPayloads) {
    await assert.rejects(
      expenses.handleSepayWebhook(
        { ...createWebhookPayload(debt), ...override },
        webhookKey
      ),
      { status: 400 }
    );
  }

  // Outgoing transfers are ignored
  const outResult = await expenses.handleSepayWebhook(
    { ...createWebhookPayload(debt), transferType: 'out' },
    webhookKey
  );
  assert.equal(outResult.processed, false);

  const { rows } = await db.query('SELECT status FROM settlements');
  assert.equal(rows[0].status, 'PENDING');
});

test('SePay retry/concurrency credits exactly once and then balances reach zero', async () => {
  const debt = await createDebt();

  const results = await joinTasks([
    expenses.handleSepayWebhook(createWebhookPayload(debt), webhookKey),
    expenses.handleSepayWebhook(createWebhookPayload(debt), webhookKey),
  ]);

  assert.equal(results.filter((r) => r.processed).length, 1);

  const eventCount = await db.query('SELECT COUNT(*)::int AS n FROM sepay_events');
  assert.equal(eventCount.rows[0].n, 1);

  assert.deepEqual(await expenses.settleTripDebts(tripId, userA), []);
});

test('outdated QR cannot credit a recalculated settlement', async () => {
  const oldDebt = await createDebt();

  // Add new expense to trigger debt recalculation
  await expenses.createExpense(createBillPayload(), userA);
  const currentDebt = (await expenses.settleTripDebts(tripId, userA))[0];

  assert.notEqual(currentDebt.id, oldDebt.id);

  const oldWebhookResult = await expenses.handleSepayWebhook(
    createWebhookPayload(oldDebt),
    webhookKey
  );
  assert.equal(oldWebhookResult.processed, false);

  const { rows } = await db.query('SELECT status FROM settlements WHERE id = $1', [currentDebt.id]);
  assert.equal(rows[0].status, 'PENDING');
});

test('paying one debt leaves only the unpaid balance and preserves its QR', async () => {
  await db.query('INSERT INTO trip_members (trip_id, user_id) VALUES ($1, $2)', [tripId, outsiderUser]);
  await expenses.createExpense(
    createBillPayload({ amount: 300, splits: [userA, userB, outsiderUser] }),
    userA
  );

  const debts = await expenses.settleTripDebts(tripId, userA);
  const debtB = debts.find((s) => s.fromUser.id === userB);
  const debtOutsider = debts.find((s) => s.fromUser.id === outsiderUser);

  await expenses.markSettlementPaid(debtB.id, userB);
  await expenses.confirmSettlement(debtB.id, userA);

  const remainingDebts = await expenses.settleTripDebts(tripId, userA);
  assert.equal(remainingDebts.length, 1);
  assert.equal(remainingDebts[0].id, debtOutsider.id);
  assert.equal(remainingDebts[0].amount, 100);
});

test('one webhook transaction cannot be reused to credit a second settlement', async () => {
  const firstDebt = await createDebt();
  await expenses.handleSepayWebhook(createWebhookPayload(firstDebt), webhookKey);

  await expenses.createExpense(createBillPayload(), userA);
  const secondDebt = (await expenses.settleTripDebts(tripId, userA))[0];

  const replayResult = await expenses.handleSepayWebhook(
    createWebhookPayload(secondDebt),
    webhookKey
  );
  assert.equal(replayResult.processed, false);

  const { rows } = await db.query('SELECT status FROM settlements WHERE id = $1', [secondDebt.id]);
  assert.equal(rows[0].status, 'PENDING');
});

test('QR can be issued after adding bank details and then keeps its bank snapshot', async () => {
  // Start without bank account
  await db.query('UPDATE users SET bank_bin = NULL, bank_account_number = NULL WHERE id = $1', [userA]);
  const debt = await createDebt();
  assert.equal(debt.vietqrUrl, null);

  // Add bank account
  await db.query(
    "UPDATE users SET bank_bin = '970422', bank_account_number = '123456789' WHERE id = $1",
    [userA]
  );
  const qr = await expenses.getSettlementVietQR(debt.id, userA);
  assert.ok(qr.vietqrUrl);

  // Changing bank account later does not mutate already-issued settlement snapshot
  await db.query(
    "UPDATE users SET bank_account_number = '987654321' WHERE id = $1",
    [userA]
  );
  const unchangedQr = await expenses.getSettlementVietQR(debt.id, userA);
  assert.equal(unchangedQr.vietqrUrl, qr.vietqrUrl);

  const webhookResult = await expenses.handleSepayWebhook(
    createWebhookPayload(debt),
    webhookKey
  );
  assert.equal(webhookResult.processed, true);

  await assert.rejects(expenses.getSettlementVietQR(debt.id, outsiderUser), { status: 403 });
});

test('AI save validates day order, times and cost; valid plan saves all rows', async () => {
  const validPlan = {
    tripName: 'AI Trip',
    destination: 'Hanoi',
    startDate: '2026-09-07',
    estimatedBudget: 0,
    itineraryData: {
      estimatedBudget: 100,
      days: [
        {
          dayNumber: 1,
          items: [
            {
              activity: 'Walk',
              time: '08:30',
              estimatedCost: 0,
              category: 'NATURE',
            },
          ],
        },
      ],
    },
  };

  const invalidDays = [
    { dayNumber: 10, items: validPlan.itineraryData.days[0].items },
    { dayNumber: 1, items: [{ activity: 'Bad', time: '25:00' }] },
    { dayNumber: 1, items: [{ activity: 'Bad', time: '08:00', estimatedCost: -1 }] },
  ];

  for (const day of invalidDays) {
    const res = await request('/ai-planner/save', 'POST', {
      ...validPlan,
      itineraryData: { days: [day] },
    });
    assert.equal(res.status, 400);
  }

  const invalidDateRes = await request('/ai-planner/save', 'POST', {
    ...validPlan,
    startDate: '2026-02-30',
  });
  assert.equal(invalidDateRes.status, 400);

  const saveRes = await request('/ai-planner/save', 'POST', validPlan);
  assert.equal(saveRes.status, 201);

  const savedData = saveRes.body.data;
  assert.equal(Number(savedData.trip.estimated_budget), 0);
  assert.match(savedData.trip.invite_code, /^[A-F0-9]{6}$/);
  assert.equal(savedData.itineraries[0].items[0].category, 'NATURE');
  assert.equal(savedData.itineraries[0].items[0].start_time, '08:30:00');
});

test('Gemini provider failure is explicit; opt-in fallback is labeled', async () => {
  const originalFetch = global.fetch;

  try {
    global.fetch = async () => ({
      ok: false,
      status: 503,
      text: async () => 'unavailable',
    });

    const input = {
      destination: 'Hanoi',
      durationDays: 2,
      estimatedBudget: 100000,
      travelStyle: 'CHILL',
    };

    await assert.rejects(ai.generateItinerary(input), { status: 503 });

    env.aiAllowFallback = true;
    const fallbackResult = await ai.generateItinerary(input);
    assert.equal(fallbackResult.source, 'fallback');
    assert.equal(fallbackResult.days.length, 2);
  } finally {
    global.fetch = originalFetch;
    env.aiAllowFallback = false;
  }
});

test('Gemini malformed output is rejected instead of returning success', async () => {
  const originalFetch = global.fetch;

  try {
    global.fetch = async () => ({
      ok: true,
      json: async () => ({
        candidates: [
          {
            content: {
              parts: [{ text: '{"days":[{"dayNumber":10,"items":[]}]}' }],
            },
          },
        ],
      }),
    });

    await assert.rejects(
      ai.generateItinerary({ destination: 'Hanoi', durationDays: 1 }),
      { status: 503 }
    );
  } finally {
    global.fetch = originalFetch;
  }
});

test('valid Gemini response uses configured model, header key and timeout', async () => {
  const originalFetch = global.fetch;

  try {
    global.fetch = async (url, options) => {
      assert.ok(url.includes(env.geminiModel));
      assert.ok(!url.includes('key='));
      assert.equal(options.headers['x-goog-api-key'], env.geminiApiKey);
      assert.ok(options.signal);

      return {
        ok: true,
        json: async () => ({
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      days: [
                        {
                          dayNumber: 1,
                          items: [{ activity: 'Walk', time: '08:00', estimatedCost: 0 }],
                        },
                      ],
                    }),
                  },
                ],
              },
            },
          ],
        }),
      };
    };

    const result = await ai.generateItinerary({
      destination: 'Hanoi',
      durationDays: 1,
      estimatedBudget: 0,
    });

    assert.equal(result.source, 'gemini');
    assert.equal(result.estimatedBudget, 0);
  } finally {
    global.fetch = originalFetch;
  }
});

test('AI repository rolls back the entire trip when a day insert fails', async () => {
  const aiRepo = require('../src/features/ai-planner/aiPlanner.repository');

  await assert.rejects(
    aiRepo.saveAiItineraryToDb({
      userId: userA,
      tripName: 'Invalid',
      destination: 'Hanoi',
      startDate: '2026-09-07',
      endDate: '2026-09-08',
      days: [
        { dayNumber: 1, items: [] },
        { dayNumber: 1, items: [] }, // Duplicate dayNumber violates UNIQUE constraint
      ],
    }),
    { code: '23505' }
  );

  const tripCount = await db.query('SELECT COUNT(*)::int AS n FROM trips');
  assert.equal(tripCount.rows[0].n, 1);

  const itineraryCount = await db.query('SELECT COUNT(*)::int AS n FROM itineraries');
  assert.equal(itineraryCount.rows[0].n, 0);
});
