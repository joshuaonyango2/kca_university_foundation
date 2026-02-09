// backend/src/routes/campaigns.routes.js
const express = require('express');
const router = express.Router();
const campaignController = require('../controllers/campaignController');
const { authMiddleware, adminOnly } = require('../middleware/auth.middleware');

// Public routes
router.get('/', campaignController.getAllCampaigns);
router.get('/:id', campaignController.getCampaign);

// Admin routes
router.post('/', authMiddleware, adminOnly, campaignController.createCampaign);
router.put('/:id', authMiddleware, adminOnly, campaignController.updateCampaign);
router.delete('/:id', authMiddleware, adminOnly, campaignController.deleteCampaign);

module.exports = router;