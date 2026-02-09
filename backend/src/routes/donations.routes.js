// backend/src/routes/donations.routes.js
const express = require('express');
const router = express.Router();
const donationController = require('../controllers/donationController');
const { authMiddleware } = require('../middleware/auth.middleware');

// All donation routes require authentication
router.use(authMiddleware);

router.post('/initiate', donationController.initiateDonation);
router.get('/my-donations', donationController.getMyDonations);
router.get('/:id', donationController.getDonation);
router.put('/:id/cancel', donationController.cancelDonation);

module.exports = router;