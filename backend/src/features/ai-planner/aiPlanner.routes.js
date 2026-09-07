const express = require('express');
const router = express.Router();
const rateLimit = require('../../shared/middlewares/rateLimit.middleware');
const aiPlannerController = require('./aiPlanner.controller');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const {
  generateItinerarySchema,
  saveAiItinerarySchema,
} = require('./aiPlanner.validation');

// ============================================================================
// ROUTES: AI Travel Planner (/api/v1/ai-planner)
// Tự động sinh lịch trình thông minh qua Gemini AI và lưu thành chuyến đi thật
// ============================================================================

// 1. Khởi tạo lịch trình du lịch thông minh bằng Google Gemini AI
router.post(
  '/generate',
  authenticate,
  rateLimit('ai-generate', 10, 3600),
  validate(generateItinerarySchema),
  aiPlannerController.generateItinerary
);

// 2. Lưu lịch trình do AI gợi ý vào cơ sở dữ liệu Supabase
router.post(
  '/save',
  authenticate,
  validate(saveAiItinerarySchema),
  aiPlannerController.saveItinerary
);

module.exports = router;
