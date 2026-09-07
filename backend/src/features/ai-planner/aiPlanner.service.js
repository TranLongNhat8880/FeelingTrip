const aiPlannerRepository = require('./aiPlanner.repository');
const { generateItineraryWithGemini } = require('../../shared/services/gemini.service');

// ============================================================================
// SERVICE: AI Travel Planner
// Logic sinh lịch trình AI và chuyển đổi sang chuyến đi thực tế trong hệ thống
// ============================================================================

/**
 * 1. Gọi AI sinh lịch trình du lịch thông minh
 */
const generateItinerary = async ({
  destination,
  durationDays,
  estimatedBudget,
  travelStyle,
  preferences,
}) => {
  return await generateItineraryWithGemini({
    destination,
    durationDays,
    estimatedBudget,
    travelStyle,
    preferences,
  });
};

/**
 * 2. Lưu lịch trình AI gợi ý thành chuyến đi thực tế trong Database
 */
const saveAiItinerary = async ({
  userId,
  tripName,
  destination,
  startDate,
  estimatedBudget,
  itineraryData,
}) => {
  // Chuẩn hóa dữ liệu ngày và hoạt động
  let days = [];
  if (Array.isArray(itineraryData)) {
    days = itineraryData;
  } else if (itineraryData && Array.isArray(itineraryData.days)) {
    days = itineraryData.days;
  }

  if (days.length === 0) {
    const error = new Error('Dữ liệu lịch trình (itineraryData) không chứa thông tin ngày nào');
    error.status = 400;
    throw error;
  }

  // Tính toán ngày kết thúc (endDate)
  const durationDays = days.length;
  const start = new Date(startDate);
  const end = new Date(start);
  end.setDate(start.getDate() + durationDays - 1);
  const endDate = end.toISOString().split('T')[0];

  const result = await aiPlannerRepository.saveAiItineraryToDb({
    userId,
    tripName,
    destination,
    startDate: start.toISOString().split('T')[0],
    endDate,
    estimatedBudget: estimatedBudget || (itineraryData.estimatedBudget || 0),
    days,
  });

  return {
    ...result,
    message: 'Lưu lịch trình AI vào chuyến đi thành công!',
  };
};

module.exports = {
  generateItinerary,
  saveAiItinerary,
};
