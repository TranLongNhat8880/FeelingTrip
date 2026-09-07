const { requireVnd } = require('../utils/money.util');
const apiError = require('../utils/apiError.util');
const generateVietQRUrl = ({ bankBin, accountNumber, amount, description, template = 'compact2' }) => {
  if (!/^\d{6}$/.test(bankBin || '') || !/^[a-zA-Z0-9]{1,50}$/.test(accountNumber || '') ||
      !['compact', 'compact2', 'qr_only', 'print'].includes(template)) {
    throw apiError(400, 'Thông tin ngân hàng VietQR không hợp lệ');
  }
  const query = new URLSearchParams({ amount: String(requireVnd(amount)), addInfo: description || 'FeelingTrip Thanh Toan' });
  return 'https://img.vietqr.io/image/' + bankBin + '-' + accountNumber + '-' + template + '.png?' + query;
};
module.exports = { generateVietQRUrl };
