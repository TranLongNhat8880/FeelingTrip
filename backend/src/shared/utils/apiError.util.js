/**
 * Custom API Error utility
 * Provides consistent error construction with HTTP status codes.
 * Compatible with both functional calls `apiError(status, message)`
 * and class instantiation `new ApiError(status, message)`.
 */
class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.statusCode = status;
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}

const createApiError = (status, message) => new ApiError(status, message);
createApiError.ApiError = ApiError;

module.exports = createApiError;
