const { sendError } = require('../utils/response.util');
const HTTP_STATUS = require('../constants/httpStatus');

const authorize = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return sendError(
        res,
        'Access denied: You do not have permission to perform this action',
        HTTP_STATUS.FORBIDDEN
      );
    }
    next();
  };
};

module.exports = authorize;
