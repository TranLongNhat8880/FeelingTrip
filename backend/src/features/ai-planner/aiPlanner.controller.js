const aiPlannerService = require('./aiPlanner.service');
const { sendSuccess, sendError } = require('../../shared/utils/response.util');
const HTTP_STATUS = require('../../shared/constants/httpStatus');

// ============================================================================
// CONTROLLER: AI Travel Planner
// Tiếp nhận Request từ Client, gọi Service xử lý và trả Response chuẩn hóa
// ============================================================================

/**
 * [POST] /api/v1/ai-planner/generate
 * Sinh lịch trình du lịch thông minh bằng Google Gemini AI
 */
const generateItinerary = async (req, res, next) => {
  try {
    const { destination, durationDays, estimatedBudget, travelStyle, preferences } = req.body;
    const result = await aiPlannerService.generateItinerary({
      destination,
      durationDays,
      estimatedBudget,
      travelStyle,
      preferences,
    });
    return sendSuccess(res, result, result.source === 'fallback' ? 'Lịch trình mẫu cục bộ' : 'Sinh lịch trình du lịch AI thành công', HTTP_STATUS.OK);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

/**
 * [POST] /api/v1/ai-planner/save
 * Lưu lịch trình do AI gợi ý vào chuyến đi thật trong Database
 */
const saveItinerary = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { tripName, destination, startDate, estimatedBudget, itineraryData } = req.body;

    const result = await aiPlannerService.saveAiItinerary({
      userId,
      tripName,
      destination,
      startDate,
      estimatedBudget,
      itineraryData,
    });

    return sendSuccess(res, result, result.message, HTTP_STATUS.CREATED);
  } catch (error) {
    if (error.status) {
      return sendError(res, error.message, error.status);
    }
    next(error);
  }
};

module.exports = {
  generateItinerary,
  saveItinerary,
};
