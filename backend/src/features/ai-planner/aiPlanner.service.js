const aiPlannerRepository = require('./aiPlanner.repository');
const { normalizePlan } = require('../../shared/utils/itinerary.util');
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
  const plan = normalizePlan(itineraryData);
  const days = plan.days;

  // Tính toán ngày kết thúc (endDate)
  const durationDays = days.length;
  const start = new Date(startDate);
  const end = new Date(start);
  end.setUTCDate(start.getUTCDate() + durationDays - 1);
  const endDate = end.toISOString().split('T')[0];

  const result = await aiPlannerRepository.saveAiItineraryToDb({
    userId,
    tripName,
    destination,
    startDate: start.toISOString().split('T')[0],
    endDate,
    estimatedBudget: estimatedBudget ?? plan.estimatedBudget ?? 0,
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
