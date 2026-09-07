const Joi = require('joi');
const apiError = require('./apiError.util');
const { MAX_VND } = require('./money.util');
const { PLACE_CATEGORIES } = require('../constants/categories');
const money = Joi.number().integer().min(0).max(MAX_VND);
const itemSchema = Joi.object({
  time: Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/).required(),
  activity: Joi.string().trim().min(1).max(255),
  customName: Joi.string().trim().min(1).max(255),
  category: Joi.string().valid(...Object.values(PLACE_CATEGORIES)).default('OTHER'),
  estimatedCost: money.default(0),
  note: Joi.string().max(2000).allow('', null),
}).or('activity', 'customName');
const daysSchema = Joi.array().min(1).max(14).items(Joi.object({
  dayNumber: Joi.number().integer().min(1).max(14).required(),
  title: Joi.string().trim().min(1).max(255),
  items: Joi.array().min(1).max(24).items(itemSchema).required(),
})).custom((days, helpers) => {
  if (days.some((day, i) => day.dayNumber !== i + 1 ||
    day.items.some((item, j) => j > 0 && item.time < day.items[j - 1].time))) {
    return helpers.error('any.invalid');
  }
  return days;
});
const planSchema = Joi.object({
  tripName: Joi.string().trim().min(2).max(255),
  destination: Joi.string().trim().min(2).max(255),
  durationDays: Joi.number().integer().min(1).max(14),
  estimatedBudget: money,
  travelStyle: Joi.string().max(50),
  summary: Joi.string().max(4000),
  source: Joi.string().valid('gemini', 'fallback'),
  warning: Joi.string().max(1000),
  days: daysSchema.required(),
}).custom((plan, helpers) => plan.durationDays != null && plan.durationDays !== plan.days.length
  ? helpers.error('any.invalid') : plan);
const normalizePlan = input => {
  const { value, error } = planSchema.validate(Array.isArray(input) ? { days: input } : input, { stripUnknown: true });
  if (error) throw apiError(400, 'Lịch trình không hợp lệ: ' + error.message);
  return value;
};
module.exports = { daysSchema, planSchema, normalizePlan };
