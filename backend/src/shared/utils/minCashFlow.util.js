/**
 * Debt Simplification Algorithm (Min Cash Flow Algorithm)
 * Input:
 *   balances: Object where key is userId, and value is net balance (positive means they should receive, negative means they owe)
 *   Example: { 'userA': -166667, 'userB': 1133333, 'userC': -966667 }
 * Output:
 *   Array of simplified transactions:
 *   [ { from: 'userC', to: 'userB', amount: 966667 }, { from: 'userA', to: 'userB', amount: 166667 } ]
 */
function simplifyDebts(netBalances) {
  const debtors = [];
  const creditors = [];

  for (const [userId, balance] of Object.entries(netBalances)) {
    const rounded = Math.round(balance);
    if (rounded < 0) {
      debtors.push({ userId, amount: -rounded });
    } else if (rounded > 0) {
      creditors.push({ userId, amount: rounded });
    }
  }

  debtors.sort((a, b) => b.amount - a.amount);
  creditors.sort((a, b) => b.amount - a.amount);

  const transactions = [];
  let dIdx = 0;
  let cIdx = 0;

  while (dIdx < debtors.length && cIdx < creditors.length) {
    const debtor = debtors[dIdx];
    const creditor = creditors[cIdx];

    const settledAmount = Math.min(debtor.amount, creditor.amount);

    if (settledAmount > 0) {
      transactions.push({
        fromUserId: debtor.userId,
        toUserId: creditor.userId,
        amount: settledAmount,
      });
    }

    debtor.amount -= settledAmount;
    creditor.amount -= settledAmount;

    if (debtor.amount === 0) dIdx++;
    if (creditor.amount === 0) cIdx++;
  }

  return transactions;
}

module.exports = {
  simplifyDebts,
};
