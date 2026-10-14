const router = require('express').Router();
const Joi = require('joi');
const service = require('./bankhub.service');
const authenticate = require('../../shared/middlewares/auth.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const rateLimit = require('../../shared/middlewares/rateLimit.middleware');
const { sendSuccess } = require('../../shared/utils/response.util');
const wrap = (work) => async (req,res,next) => { try { await work(req,res); } catch (error) { next(error); } };

router.post('/events', wrap(async (req,res) => res.json(await service.handleEvent(req.body,req.get('X-Secret-Key')))));
router.post('/ipn', wrap(async (req,res) => res.json(await service.handleIpn(req.body,req.get('Authorization')))));
router.get('/accounts', authenticate, wrap(async (req,res) => sendSuccess(res,await service.listAccounts(req.user.id))));
router.post('/link', authenticate, rateLimit('bankhub_link',10), validate(Joi.object({
  purpose: Joi.string().valid('LINK_BANK_ACCOUNT','UNLINK_BANK_ACCOUNT','REACTIVATE_BANK_ACCOUNT').default('LINK_BANK_ACCOUNT'),
  accountId: Joi.string().guid().when('purpose', { is: 'LINK_BANK_ACCOUNT', then: Joi.forbidden(), otherwise: Joi.required() }),
})), wrap(async (req,res) => sendSuccess(res,await service.createLink(req.user.id,req.body.purpose,req.body.accountId))));
module.exports = router;
