const { test } = require('node:test');
const assert = require('node:assert/strict');
const { simplifyDebts } = require('../src/shared/utils/minCashFlow.util');
const { generateVietQRUrl } = require('../src/shared/services/vietqr.service');

test('exact solver minimizes the known greedy counterexample', () => {
  // A standard case where naive greedy takes 4 transactions, but exact partition takes only 3
  const balances = { A: -8, B: -7, C: -5, D: 12, E: 8 };
  const transactions = simplifyDebts(balances);

  assert.equal(transactions.length, 3);

  // Verify debt conservation: All net balances must reach exactly zero
  for (const t of transactions) {
    balances[t.fromUserId] += t.amount;
    balances[t.toUserId] -= t.amount;
  }
  assert.ok(Object.values(balances).every((val) => val === 0));
});

test('solver rejects unbalanced/fractional debts instead of discarding money', () => {
  assert.throws(
    () => simplifyDebts({ A: -10, B: 9 }),
    /Công nợ không cân bằng/
  );
  assert.throws(
    () => simplifyDebts({ A: -0.5, B: 0.5 }),
    /Công nợ không cân bằng/
  );
});

test('all generated transactions conserve balances across many group sizes', () => {
  for (let size = 2; size <= 20; size++) {
    const balances = {};
    for (let i = 0; i < size - 1; i++) {
      balances[i] = (i % 2 ? 1 : -1) * (i + 1) * 7;
    }
    balances[size - 1] = -Object.values(balances).reduce((a, b) => a + b, 0);

    const transactions = simplifyDebts(balances);

    for (const t of transactions) {
      assert.ok(t.amount > 0);
      balances[t.fromUserId] += t.amount;
      balances[t.toUserId] -= t.amount;
    }

    assert.ok(Object.values(balances).every((val) => val === 0));
  }
});

test('VietQR validates whole VND and bank path components', () => {
  // Fractional amounts must be rejected
  assert.throws(() =>
    generateVietQRUrl({ bankBin: '970422', accountNumber: '123', amount: 1.5 })
  );

  // Path traversal in bankBin must be rejected
  assert.throws(() =>
    generateVietQRUrl({ bankBin: '../bad', accountNumber: '123', amount: 1 })
  );

  // Valid VietQR query parameters
  const url = new URL(
    generateVietQRUrl({
      bankBin: '970422',
      accountNumber: '123',
      amount: 10,
      description: 'FT ABC',
    })
  );

  assert.equal(url.searchParams.get('amount'), '10');
  assert.equal(url.searchParams.get('addInfo'), 'FT ABC');
});
