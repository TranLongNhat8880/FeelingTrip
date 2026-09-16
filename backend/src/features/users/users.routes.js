const express = require('express');
const router = express.Router();
const usersController = require('./users.controller');
router.use('/me/bank', require('../bankhub/bankhub.routes'));

// ==========================================
// ROUTES: User Profile & eKYC
// Định nghĩa các endpoint API tại đây
// ==========================================

module.exports = router;
