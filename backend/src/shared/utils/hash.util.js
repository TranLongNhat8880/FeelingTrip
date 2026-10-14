const bcrypt = require('bcryptjs');
const apiError = require('./apiError.util');

const hashPassword = async (password) => {
  if (Buffer.byteLength(password, 'utf8') > 72) {
    throw apiError(400, 'Mật khẩu không được vượt quá 72 byte UTF-8');
  }
  const salt = await bcrypt.genSalt(10);
  return bcrypt.hash(password, salt);
};

const comparePassword = async (candidatePassword, hashedPassword) => {
  return bcrypt.compare(candidatePassword, hashedPassword);
};

module.exports = {
  hashPassword,
  comparePassword,
};
