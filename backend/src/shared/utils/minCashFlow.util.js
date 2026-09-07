const apiError = require('./apiError.util');

/**
 * Greedy debt settlement for a single group with zero net balance.
 * Pairs largest debtor with largest creditor iteratively.
 *
 * @param {Array<[string, number]>} group - Array of [userId, netBalance]
 * @returns {Array<{ fromUserId: string, toUserId: string, amount: number }>}
 */
const settleSingleGroup = (group) => {
  const debtors = group
    .filter(([, balance]) => balance < 0)
    .map(([id, balance]) => ({ id, amount: -balance }))
    .sort((a, b) => b.amount - a.amount);

  const creditors = group
    .filter(([, balance]) => balance > 0)
    .map(([id, balance]) => ({ id, amount: balance }))
    .sort((a, b) => b.amount - a.amount);

  const transactions = [];
  let d = 0;
  let c = 0;

  while (d < debtors.length && c < creditors.length) {
    const transferAmount = Math.min(debtors[d].amount, creditors[c].amount);

    transactions.push({
      fromUserId: debtors[d].id,
      toUserId: creditors[c].id,
      amount: transferAmount,
    });

    debtors[d].amount -= transferAmount;
    creditors[c].amount -= transferAmount;

    if (debtors[d].amount === 0) d++;
    if (creditors[c].amount === 0) c++;
  }

  return transactions;
};

/**
 * Simplifies a network of debts across trip members to minimize transaction count.
 *
 * Strategy:
 * 1. Checks integrity: All amounts must be safe integers and total sum must be 0 (debt conservation).
 * 2. If <= 15 nonzero balances: Uses Bitmask Dynamic Programming to partition the group into
 *    the maximum number of independent zero-sum subsets (k). The minimum number of transactions
 *    is guaranteed to be exactly (n - k).
 * 3. If > 15 members: Falls back to deterministic greedy matching to prevent exponential latency.
 *
 * @param {Record<string, number>} netBalances - Map of userId -> net balance (VND)
 * @returns {Array<{ fromUserId: string, toUserId: string, amount: number }>}
 */
function simplifyDebts(netBalances) {
  const entries = Object.entries(netBalances).filter(([, balance]) => balance !== 0);

  if (
    entries.some(([, balance]) => !Number.isSafeInteger(balance)) ||
    entries.reduce((sum, [, balance]) => sum + BigInt(balance), 0n) !== 0n
  ) {
    throw apiError(409, 'Công nợ không cân bằng hoặc không phải số nguyên VND');
  }

  // Large groups fallback to deterministic greedy solver
  if (entries.length > 15) {
    return settleSingleGroup(entries);
  }

  // Bitmask Subset-Sum DP to find maximum number of zero-sum partitions
  const n = entries.length;
  const size = 1 << n;
  const subsetSums = Array(size).fill(0n);
  const maxPartitions = new Int16Array(size);
  const prevElement = new Int16Array(size);

  for (let mask = 1; mask < size; mask++) {
    const lowestBit = mask & -mask;
    const lowestIndex = 31 - Math.clz32(lowestBit);

    subsetSums[mask] = subsetSums[mask ^ lowestBit] + BigInt(entries[lowestIndex][1]);
    maxPartitions[mask] = -1;

    for (let i = 0; i < n; i++) {
      if (!(mask & (1 << i))) continue;

      const rest = mask ^ (1 << i);
      const partitionCount = maxPartitions[rest] + (subsetSums[mask] === 0n ? 1 : 0);

      if (partitionCount > maxPartitions[mask]) {
        maxPartitions[mask] = partitionCount;
        prevElement[mask] = i;
      }
    }
  }

  // Reconstruct the optimal subsets and settle each subset independently
  const result = [];
  let mask = size - 1;
  let currentGroup = [];

  while (mask > 0) {
    const itemIndex = prevElement[mask];
    currentGroup.push(entries[itemIndex]);
    mask ^= 1 << itemIndex;

    if (subsetSums[mask] === 0n) {
      result.push(...settleSingleGroup(currentGroup));
      currentGroup = [];
    }
  }

  return result;
}

module.exports = {
  simplifyDebts,
};
