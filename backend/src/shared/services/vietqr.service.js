/**
 * VietQR Open Standard Service
 * Generates direct payment QR URL conforming to NAPAS standard
 */
const generateVietQRUrl = ({ bankBin, accountNumber, amount, description, template = 'compact2' }) => {
  if (!bankBin || !accountNumber) {
    throw new Error('Bank BIN and account number are required to generate VietQR');
  }

  const encodedDesc = encodeURIComponent(description || 'FeelingTrip Thanh Toan');
  const roundedAmount = Math.round(amount || 0);

  return `https://img.vietqr.io/image/${bankBin}-${accountNumber}-${template}.png?amount=${roundedAmount}&addInfo=${encodedDesc}`;
};

module.exports = {
  generateVietQRUrl,
};
