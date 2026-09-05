const jwt = require('jsonwebtoken');
const env = require('../../config/env');

const generateToken = (payload, expiresIn = env.jwt.expiresIn) => {
  return jwt.sign(payload, env.jwt.secret, { expiresIn });
};

const verifyToken = (token) => {
  return jwt.verify(token, env.jwt.secret);
};

module.exports = {
  generateToken,
  verifyToken,
};
