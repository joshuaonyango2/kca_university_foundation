// backend/src/routes/payments.routes.js
const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const { authMiddleware } = require('../middleware/auth.middleware');

// M-Pesa routes
router.post('/mpesa/initiate', authMiddleware, paymentController.initiateMpesaPayment);
router.post('/mpesa/callback', paymentController.mpesaCallback); // No auth (webhook)

// Payment status
router.get('/status/:donation_id', authMiddleware, paymentController.checkPaymentStatus);

// Bank transfer
router.post('/bank-transfer/confirm', authMiddleware, paymentController.confirmBankTransfer);

module.exports = router;