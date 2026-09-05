const { sendError } = require('../utils/response.util');
const HTTP_STATUS = require('../constants/httpStatus');

const errorHandler = (err, req, res, next) => {
  console.error('Error occurred:', err.stack || err.message);

  const statusCode = err.statusCode || HTTP_STATUS.INTERNAL_SERVER_ERROR;
  const message = err.message || 'An unexpected error occurred';

  return sendError(res, message, statusCode, process.env.NODE_ENV === 'development' ? err.stack : null);
};

module.exports = errorHandler;
