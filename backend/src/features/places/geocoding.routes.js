const express = require('express');
const Joi = require('joi');
const authenticate = require('../../shared/middlewares/auth.middleware');
const authorize = require('../../shared/middlewares/role.middleware');
const validate = require('../../shared/middlewares/validate.middleware');
const { ROLES } = require('../../shared/constants/roles');
const { sendSuccess } = require('../../shared/utils/response.util');
const service = require('./geocoding.service');

const router = express.Router();
router.use(authenticate);
const canUseGeocoding = authorize(ROLES.USER, ROLES.ADMIN);

const action = work => async (req, res, next) => {
  try { await work(req, res); } catch (error) { next(error); }
};

router.get('/configuration', canUseGeocoding, action(async (req, res) => {
  res.set('Cache-Control', 'no-store');
  sendSuccess(res, { configured: service.isConfigured() });
}));
router.get('/search', canUseGeocoding, validate({
  query: Joi.object({
    text: Joi.string().trim().min(3).max(255).required(),
  })
}), action(async (req, res) => {
  sendSuccess(res, await service.search(req.query.text));
}));
router.get('/reverse', canUseGeocoding, validate({
  query: Joi.object({
    lat: Joi.number().min(-90).max(90).required(),
    lon: Joi.number().min(-180).max(180).required(),
  })
}), action(async (req, res) => {
  sendSuccess(res, await service.reverse(req.query.lat, req.query.lon));
}));
router.get('/tiles/:z/:x/:y.png', canUseGeocoding, validate({
  params: Joi.object({
    z: Joi.number().integer().min(0).max(20).required(),
    x: Joi.number().integer().min(0).required(),
    y: Joi.number().integer().min(0).required(),
  })
}), action(async (req, res) => {
  const bytes = await service.tile(req.params.z, req.params.x, req.params.y);
  res.set('Cache-Control', 'private, max-age=300');
  res.set('Cross-Origin-Resource-Policy', 'cross-origin');
  res.type('png').send(bytes);
}));

module.exports = router;
