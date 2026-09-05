const { verifyToken } = require('../utils/token.util');
const { sendError } = require('../utils/response.util');
const HTTP_STATUS = require('../constants/httpStatus');

const authenticate = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return sendError(res, 'No token provided or invalid format', HTTP_STATUS.UNAUTHORIZED);
    }

    const token = authHeader.split(' ')[1];
    const decoded = verifyToken(token);
    req.user = decoded; // { id, email, role }
    next();
  } catch (error) {
    return sendError(res, 'Invalid or expired token', HTTP_STATUS.UNAUTHORIZED);
  }
};

module.exports = authenticate;
