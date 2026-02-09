// backend/src/controllers/paymentController.js
const pool = require('../config/database');
const mpesaService = require('../services/mpesa.service');

class PaymentController {
  async initiateMpesaPayment(req, res) {
    const client = await pool.connect();
    try {
      const { donation_id, phone_number } = req.body;

      const donationResult = await client.query(
        `SELECT d.donation_id, d.amount, d.user_id, d.campaign_id, c.title as campaign_title
         FROM donations d
         JOIN campaigns c ON d.campaign_id = c.campaign_id
         WHERE d.donation_id = $1 AND d.donation_status = 'pending'`,
        [donation_id]
      );

      if (donationResult.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Donation not found or already processed' });
      }

      const donation = donationResult.rows[0];

      if (!mpesaService.isValidKenyanPhone(phone_number)) {
        return res.status(400).json({ success: false, message: 'Invalid Kenyan phone number' });
      }

      const stkResult = await mpesaService.stkPush(
        phone_number,
        donation.amount,
        donation_id,
        `Donation to ${donation.campaign_title}`
      );

      if (!stkResult.success) {
        return res.status(400).json({ success: false, message: stkResult.error || 'Failed to initiate payment' });
      }

      await client.query(
        `INSERT INTO payments (donation_id, provider, provider_reference, amount, 
          payment_phone, confirmation_status, provider_response)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [donation_id, 'mpesa', stkResult.checkoutRequestId, donation.amount, phone_number, 'pending', JSON.stringify(stkResult)]
      );

      await client.query(
        `UPDATE donations 
         SET donation_status = 'processing', transaction_reference = $1, updated_at = CURRENT_TIMESTAMP
         WHERE donation_id = $2`,
        [stkResult.checkoutRequestId, donation_id]
      );

      res.json({
        success: true,
        message: 'Payment initiated. Please check your phone to complete payment.',
        data: {
          checkoutRequestId: stkResult.checkoutRequestId,
          customerMessage: stkResult.customerMessage
        }
      });
    } catch (error) {
      console.error('M-Pesa initiation error:', error);
      res.status(500).json({ success: false, message: 'Failed to initiate payment' });
    } finally {
      client.release();
    }
  }

  async mpesaCallback(req, res) {
    try {
      console.log('📥 M-Pesa callback received');
      res.json({ ResultCode: 0, ResultDesc: 'Accepted' });
      await mpesaService.handleCallback(req.body);
    } catch (error) {
      console.error('Callback processing error:', error);
      res.json({ ResultCode: 1, ResultDesc: 'Failed' });
    }
  }

  async checkPaymentStatus(req, res) {
    try {
      const { donation_id } = req.params;

      const result = await pool.query(
        `SELECT p.payment_id, p.provider, p.confirmation_status, 
                p.provider_reference, d.donation_status, d.amount
         FROM payments p
         JOIN donations d ON p.donation_id = d.donation_id
         WHERE p.donation_id = $1
         ORDER BY p.created_at DESC LIMIT 1`,
        [donation_id]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Payment not found' });
      }

      res.json({ success: true, data: result.rows[0] });
    } catch (error) {
      console.error('Check status error:', error);
      res.status(500).json({ success: false, message: 'Failed to check payment status' });
    }
  }

  async confirmBankTransfer(req, res) {
    const client = await pool.connect();
    try {
      const { donation_id, transaction_reference, receipt_image_url } = req.body;

      await client.query('BEGIN');

      await client.query(
        `INSERT INTO payments (donation_id, provider, provider_reference, 
          confirmation_status, provider_response)
         VALUES ($1, $2, $3, $4, $5)`,
        [donation_id, 'bank_transfer', transaction_reference, 'pending', JSON.stringify({ receipt_image_url })]
      );

      await client.query(
        `UPDATE donations 
         SET donation_status = 'processing', transaction_reference = $1
         WHERE donation_id = $2`,
        [transaction_reference, donation_id]
      );

      const adminQuery = await client.query(
        "SELECT user_id FROM users WHERE role IN ('admin', 'finance')"
      );

      for (const admin of adminQuery.rows) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, message, action_url)
           VALUES ($1, 'bank_transfer_pending', 'Bank Transfer Pending', 
                   'New bank transfer requires reconciliation', 
                   '/admin/reconciliation?donation_id=${donation_id}')`,
          [admin.user_id]
        );
      }

      await client.query('COMMIT');

      res.json({
        success: true,
        message: 'Bank transfer details submitted. Awaiting confirmation.',
        data: { donation_id, status: 'processing' }
      });
    } catch (error) {
      await client.query('ROLLBACK');
      console.error('Bank transfer confirmation error:', error);
      res.status(500).json({ success: false, message: 'Failed to confirm bank transfer' });
    } finally {
      client.release();
    }
  }
}

module.exports = new PaymentController();