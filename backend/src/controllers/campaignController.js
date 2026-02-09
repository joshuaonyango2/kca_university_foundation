// backend/src/controllers/campaignController.js
const pool = require('../config/database');

class CampaignController {
  async getAllCampaigns(req, res) {
    try {
      const { category, status = 'active', featured } = req.query;

      let query = `
        SELECT campaign_id, title, slug, description, category, 
               goal_amount, current_amount, currency, start_date, end_date,
               status, featured, image_url, created_at,
               ROUND((current_amount / goal_amount) * 100, 2) as progress_percentage
        FROM campaigns WHERE status = $1
      `;
      const params = [status];
      let paramCount = 1;

      if (category) {
        paramCount++;
        query += ` AND category = $${paramCount}`;
        params.push(category);
      }

      if (featured === 'true') query += ` AND featured = true`;
      query += ` ORDER BY featured DESC, created_at DESC`;

      const result = await pool.query(query, params);

      res.json({
        success: true,
        count: result.rows.length,
        data: result.rows
      });
    } catch (error) {
      console.error('Get campaigns error:', error);
      res.status(500).json({ success: false, message: 'Failed to retrieve campaigns' });
    }
  }

  async getCampaign(req, res) {
    try {
      const { id } = req.params;

      const query = `
        SELECT c.*, ROUND((c.current_amount / c.goal_amount) * 100, 2) as progress_percentage,
               COUNT(DISTINCT d.donation_id) as total_donors,
               u.first_name || ' ' || u.last_name as created_by_name
        FROM campaigns c
        LEFT JOIN donations d ON c.campaign_id = d.campaign_id AND d.donation_status = 'completed'
        LEFT JOIN users u ON c.created_by = u.user_id
        WHERE c.campaign_id = $1 OR c.slug = $1
        GROUP BY c.campaign_id, u.first_name, u.last_name
      `;

      const result = await pool.query(query, [id]);

      if (result.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Campaign not found' });
      }

      const recentDonations = await pool.query(
        `SELECT d.amount, d.created_at, d.is_anonymous,
                u.first_name || ' ' || u.last_name as donor_name
         FROM donations d
         LEFT JOIN users u ON d.user_id = u.user_id
         WHERE d.campaign_id = $1 AND d.donation_status = 'completed'
         ORDER BY d.created_at DESC LIMIT 10`,
        [result.rows[0].campaign_id]
      );

      const campaign = result.rows[0];
      campaign.recent_donations = recentDonations.rows;

      res.json({ success: true, data: campaign });
    } catch (error) {
      console.error('Get campaign error:', error);
      res.status(500).json({ success: false, message: 'Failed to retrieve campaign' });
    }
  }

  async createCampaign(req, res) {
    try {
      const { title, slug, description, category, goal_amount, start_date, end_date, image_url, featured } = req.body;

      const result = await pool.query(
        `INSERT INTO campaigns (title, slug, description, category, goal_amount,
          start_date, end_date, image_url, featured, created_by, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'active')
         RETURNING *`,
        [title, slug, description, category, goal_amount, start_date || null, end_date || null, 
         image_url || null, featured || false, req.user.user_id]
      );

      res.status(201).json({
        success: true,
        message: 'Campaign created successfully',
        data: result.rows[0]
      });
    } catch (error) {
      console.error('Create campaign error:', error);
      if (error.code === '23505') {
        return res.status(409).json({ success: false, message: 'Campaign with this slug already exists' });
      }
      res.status(500).json({ success: false, message: 'Failed to create campaign' });
    }
  }

  async updateCampaign(req, res) {
    try {
      const { id } = req.params;
      const updates = req.body;

      const allowedFields = ['title', 'description', 'category', 'goal_amount', 'start_date', 'end_date', 
                            'status', 'featured', 'image_url'];
      
      const setClause = [];
      const values = [];
      let paramCount = 1;

      for (const [key, value] of Object.entries(updates)) {
        if (allowedFields.includes(key)) {
          setClause.push(`${key} = $${paramCount}`);
          values.push(value);
          paramCount++;
        }
      }

      if (setClause.length === 0) {
        return res.status(400).json({ success: false, message: 'No valid fields to update' });
      }

      values.push(id);
      const query = `UPDATE campaigns SET ${setClause.join(', ')}, updated_at = CURRENT_TIMESTAMP
                     WHERE campaign_id = $${paramCount} RETURNING *`;

      const result = await pool.query(query, values);

      if (result.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Campaign not found' });
      }

      res.json({ success: true, message: 'Campaign updated successfully', data: result.rows[0] });
    } catch (error) {
      console.error('Update campaign error:', error);
      res.status(500).json({ success: false, message: 'Failed to update campaign' });
    }
  }

  async deleteCampaign(req, res) {
    try {
      const { id } = req.params;

      const result = await pool.query(
        `UPDATE campaigns SET status = 'archived', updated_at = CURRENT_TIMESTAMP
         WHERE campaign_id = $1 RETURNING campaign_id, title`,
        [id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Campaign not found' });
      }

      res.json({ success: true, message: 'Campaign archived successfully', data: result.rows[0] });
    } catch (error) {
      console.error('Delete campaign error:', error);
      res.status(500).json({ success: false, message: 'Failed to delete campaign' });
    }
  }
}

module.exports = new CampaignController();