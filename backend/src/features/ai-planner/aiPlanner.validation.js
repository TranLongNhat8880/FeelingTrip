const Joi = require('joi');
const { daysSchema, planSchema } = require('../../shared/utils/itinerary.util');
const { MAX_VND } = require('../../shared/utils/money.util');

// ============================================================================
// VALIDATION SCHEMAS: AI Travel Planner (src/features/ai-planner/)
// Quy tắc kiểm tra tham số sinh lịch trình tự động qua Gemini AI và lưu thành chuyến đi
// ============================================================================

const TRAVEL_STYLES = ['CHILL', 'ADVENTURE', 'CULTURE', 'FOOD', 'LUXURY', 'BUDGET', 'FAMILY'];

/**
 * Sinh lịch trình du lịch thông minh bằng Gemini AI
 */
const generateItinerarySchema = Joi.object({
  destination: Joi.string().trim().min(2).max(255).required().messages({
    'string.empty': 'Điểm đến không được để trống',
    'any.required': 'Điểm đến (destination) là bắt buộc',
  }),
  durationDays: Joi.number().integer().min(1).max(14).required().messages({
    'number.min': 'Số ngày du lịch tối thiểu là 1 ngày',
    'number.max': 'Số ngày du lịch tối đa cho AI tạo là 14 ngày',
    'any.required': 'Số ngày du lịch (durationDays) là bắt buộc',
  }),
  estimatedBudget: Joi.number().integer().min(0).max(MAX_VND).allow(null).messages({
    'number.min': 'Ngân sách dự kiến không được âm',
  }),
  travelStyle: Joi.string()
    .valid(...TRAVEL_STYLES)
    .default('CHILL')
    .messages({
      'any.only': `Phong cách du lịch phải là một trong: ${TRAVEL_STYLES.join(', ')}`,
    }),
  preferences: Joi.array().items(Joi.string().trim().max(50)).max(10).allow(null),
});

/**
 * Lưu lịch trình AI vừa gợi ý thành chuyến đi thực tế
 */
const saveAiItinerarySchema = Joi.object({
  tripName: Joi.string().trim().min(2).max(255).required().messages({
    'string.empty': 'Tên chuyến đi không được để trống',
    'any.required': 'Tên chuyến đi là bắt buộc',
  }),
  destination: Joi.string().trim().min(2).max(255).required().messages({
    'string.empty': 'Điểm đến không được để trống',
    'any.required': 'Điểm đến là bắt buộc',
  }),
  startDate: Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).custom((date, helpers) => {
    const parsed = new Date(date);
    return Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0,10) !== date ? helpers.error('any.invalid') : date;
  }).required().messages({
    'date.format': 'Ngày khởi hành phải đúng chuẩn ISO (YYYY-MM-DD)',
    'any.required': 'Ngày khởi hành là bắt buộc',
  }),
  estimatedBudget: Joi.number().integer().min(0).max(MAX_VND).allow(null),
  itineraryData: Joi.alternatives().try(planSchema, daysSchema).required().messages({
    'any.required': 'Dữ liệu lịch trình (itineraryData) là bắt buộc',
  }),
});

module.exports = {
  generateItinerarySchema,
  saveAiItinerarySchema,
};
