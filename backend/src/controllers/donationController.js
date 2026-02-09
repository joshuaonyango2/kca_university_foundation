// backend/src/controllers/donationController.js
const pool = require('../config/database');
const { v4: uuidv4 } = require('uuid');

class DonationController {
  async initiateDonation(req, res) {
    const client = await pool.connect();
    try {
      const { campaign_id, amount, payment_method, is_recurring, recurrence_frequency, is_anonymous, dedication_message } = req.body;

      const campaignResult = await client.query(
        'SELECT campaign_id, title, status FROM campaigns WHERE campaign_id = $1',
        [campaign_id]
      );

      if (campaignResult.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Campaign not found' });
      }

      if (campaignResult.rows[0].status !== 'active') {
        return res.status(400).json({ success: false, message: 'Campaign is not active' });
      }

      let payment_fee = 0;
      if (payment_method === 'card') payment_fee = amount * 0.02;
      const net_amount = amount - payment_fee;

      await client.query('BEGIN');

      const donationResult = await client.query(
        `INSERT INTO donations (user_id, campaign_id, amount, payment_method, 
          is_recurring, recurrence_frequency, is_anonymous, dedication_message, 
          payment_fee, net_amount, donation_status, transaction_reference)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'pending', $11)
         RETURNING donation_id, amount, payment_fee, net_amount, created_at`,
        [req.user.user_id, campaign_id, amount, payment_method, is_recurring || false,
         recurrence_frequency || null, is_anonymous || false, dedication_message || null,
         payment_fee, net_amount, uuidv4()]
      );

      const donation = donationResult.rows[0];

      if (is_recurring && recurrence_frequency) {
        const nextPaymentDate = this.calculateNextPaymentDate(recurrence_frequency);
        await client.query(
          `INSERT INTO recurring_schedules (user_id, campaign_id, original_donation_id, amount,
            frequency, payment_method, status, next_payment_date, start_date)
           VALUES ($1, $2, $3, $4, $5, $6, 'active', $7, CURRENT_DATE)`,
          [req.user.user_id, campaign_id, donation.donation_id, amount, recurrence_frequency, payment_method, nextPaymentDate]
        );
      }

      await client.query('COMMIT');

      res.status(201).json({
        success: true,
        message: 'Donation initiated successfully',
        data: donation
      });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Initiate donation error:', error);
      res.status(500).json({ success: false, message: 'Failed to initiate donation' });
    } finally {
      client.release();
    }
  }

  async getMyDonations(req, res) {
    try {
      const { status, page = 1, limit = 20 } = req.query;
      const offset = (page - 1) * limit;

      let query = `
        SELECT d.donation_id, d.amount, d.donation_status, d.payment_method,
               d.is_recurring, d.created_at, d.completed_at,
               c.title as campaign_title, c.slug as campaign_slug, c.image_url as campaign_image
        FROM donations d
        JOIN campaigns c ON d.campaign_id = c.campaign_id
        WHERE d.user_id = $1
      `;
      const params = [req.user.user_id];

      if (status) {
        params.push(status);
        query += ` AND d.donation_status = $${params.length}`;
      }

      query += ` ORDER BY d.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
      params.push(limit, offset);

      const result = await pool.query(query, params);

      const countResult = await pool.query(
        'SELECT COUNT(*) FROM donations WHERE user_id = $1',
        [req.user.user_id]
      );

      res.json({
        success: true,
        data: result.rows,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: parseInt(countResult.rows[0].count)
        }
      });
    } catch (error) {
      console.error('Get donations error:', error);
      res.status(500).json({ success: false, message: 'Failed to retrieve donations' });
    }
  }

  async getDonation(req, res) {
    try {
      const { id } = req.params;

      const result = await pool.query(
        `SELECT d.*, c.title as campaign_title, c.slug as campaign_slug,
                p.provider_reference, p.confirmation_status
         FROM donations d
         JOIN campaigns c ON d.campaign_id = c.campaign_id
         LEFT JOIN payments p ON d.donation_id = p.donation_id
         WHERE d.donation_id = $1 AND d.user_id = $2`,
        [id, req.user.user_id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Donation not found' });
      }

      res.json({ success: true, data: result.rows[0] });
    } catch (error) {
      console.error('Get donation error:', error);
      res.status(500).json({ success: false, message: 'Failed to retrieve donation' });
    }
  }

  async cancelDonation(req, res) {
    try {
      const { id } = req.params;

      const result = await pool.query(
        `UPDATE donations 
         SET donation_status = 'failed', updated_at = CURRENT_TIMESTAMP
         WHERE donation_id = $1 AND user_id = $2 AND donation_status = 'pending'
         RETURNING donation_id`,
        [id, req.user.user_id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Donation not found or cannot be cancelled' });
      }

      res.json({ success: true, message: 'Donation cancelled successfully' });
    } catch (error) {
      console.error('Cancel donation error:', error);
      res.status(500).json({ success: false, message: 'Failed to cancel donation' });
    }
  }

  calculateNextPaymentDate(frequency) {
    const now = new Date();
    switch (frequency) {
      case 'monthly': return new Date(now.setMonth(now.getMonth() + 1));
      case 'quarterly': return new Date(now.setMonth(now.getMonth() + 3));
      case 'yearly': return new Date(now.setFullYear(now.getFullYear() + 1));
      default: return null;
    }
  }
}

module.exports = new DonationController();