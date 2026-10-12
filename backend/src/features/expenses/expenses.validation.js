const Joi = require('joi');
const { MAX_VND } = require('../../shared/utils/money.util');
const { EXPENSE_CATEGORIES } = require('../../shared/constants/categories');
const uuid = Joi.string().guid({ version: ['uuidv4', 'uuidv5'] }).lowercase();
const money = Joi.number().integer().min(0).max(MAX_VND);
const member = Joi.object({ userId: uuid.required() });
const createExpenseSchema = Joi.object({
  tripId: uuid.required(), payerId: uuid,
  itineraryItemId: uuid.allow(null),
  title: Joi.string().trim().min(1).max(255).required(),
  amount: money.min(1).required(),
  category: Joi.string().valid(...Object.values(EXPENSE_CATEGORIES)).default('OTHER'),
  receiptImageUrl: Joi.string().uri().allow(null, ''),
  expenseDate: Joi.date().iso().allow(null),
  splitType: Joi.string().valid('EQUAL', 'EXACT', 'PERCENTAGE').default('EQUAL'),
  splits: Joi.array().min(1).max(100).required().when('splitType', {
    switch: [
      { is: 'EXACT', then: Joi.array().items(member.keys({ amountOwed: money.required() })) },
      { is: 'PERCENTAGE', then: Joi.array().items(member.keys({ percentage: Joi.number().min(0).max(100).precision(2).strict().required() })) },
    ],
    otherwise: Joi.array().items(Joi.alternatives().try(uuid, member)),
  }).unique((a, b) => (typeof a === 'string' ? a : a.userId) === (typeof b === 'string' ? b : b.userId)),
});
const tripIdParamSchema = Joi.object({ tripId: uuid.required() });
const settlementIdParamSchema = Joi.object({ id: uuid.required() });
const budgetSchema = Joi.object({ estimatedBudget: money.required() });
const linkExpenseSchema = Joi.object({ itineraryItemId: uuid.required() });
const webhookSchema = Joi.object({
  id: Joi.number().integer().min(0).required(),
  gateway: Joi.string().trim().max(100).allow(null, '').default(''),
  accountNumber: Joi.string().trim().allow(null, '').default(''),
  transferType: Joi.string().valid('in', 'out').allow(null, '').default('in'),
  transferAmount: money.min(0).default(0),
  content: Joi.string().max(2000).allow(null, ''),
  description: Joi.string().max(2000).allow(null, ''),
});
module.exports = { createExpenseSchema, tripIdParamSchema, settlementIdParamSchema, budgetSchema, webhookSchema, linkExpenseSchema };
