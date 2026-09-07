const apiError = require('./apiError.util');

/**
 * Maximum supported VND amount: 9,999,999,999,999 VND (~10 trillion VND).
 * Fits safely within JavaScript Number.MAX_SAFE_INTEGER (9,007,199,254,740,991).
 */
const MAX_VND = 9999999999999;

/**
 * Validates that an input is a safe, whole integer VND amount.
 * Prevents fractional amounts, negative amounts, overflow, and NaN.
 *
 * @param {unknown} value - Amount to validate
 * @param {boolean} [allowZero=false] - Whether 0 VND is allowed (e.g. for empty balances/budgets)
 * @returns {number} The validated integer amount
 */
const requireVnd = (value, allowZero = false) => {
  const amount = Number(value);
  const minAllowed = allowZero ? 0 : 1;

  if (
    value == null ||
    !Number.isSafeInteger(amount) ||
    amount < minAllowed ||
    amount > MAX_VND
  ) {
    throw apiError(400, 'Số tiền phải là số nguyên VND hợp lệ');
  }

  return amount;
};

module.exports = {
  MAX_VND,
  requireVnd,
};
