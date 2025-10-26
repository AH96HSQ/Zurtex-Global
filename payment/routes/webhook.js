const express = require('express');
const router = express.Router();
const Payment = require('../models/Payment');
const { notifyMainBackend } = require('../services/callback');

/**
 * POST /api/webhook/blockcypher
 * Webhook endpoint for Blockcypher notifications
 */
router.post('/blockcypher', async (req, res) => {
  try {
    const { address, confirmations, value, hash } = req.body;

    console.log('📨 Received Blockcypher webhook:', {
      address,
      confirmations,
      value: value / 100000000, // Convert satoshis to LTC
      hash,
    });

    // Find payment by address
    const payment = await Payment.findOne({ 
      paymentAddress: address,
      status: { $in: ['pending', 'confirming'] }
    });

    if (!payment) {
      console.log('⚠️  No pending payment found for address:', address);
      return res.status(404).json({ error: 'Payment not found' });
    }

    // Convert satoshis to LTC
    const amountLTC = value / 100000000;

    // Check if amount is sufficient
    if (amountLTC < payment.priceLTC * 0.99) { // 1% tolerance
      console.log('⚠️  Insufficient amount received:', {
        expected: payment.priceLTC,
        received: amountLTC,
      });
      return res.json({ status: 'insufficient_amount' });
    }

    // Update payment
    payment.txHash = hash;
    payment.confirmations = confirmations;
    payment.amountReceived = amountLTC;

    const requiredConfirmations = parseInt(process.env.REQUIRED_CONFIRMATIONS) || 2;

    if (confirmations === 0) {
      payment.status = 'confirming';
      payment.paidAt = new Date();
      console.log('💰 Payment received, waiting for confirmations:', payment.orderId);
    } else if (confirmations >= requiredConfirmations) {
      payment.status = 'completed';
      payment.completedAt = new Date();
      console.log('✅ Payment completed:', payment.orderId);

      // Notify main backend
      await notifyMainBackend(payment);
    } else {
      payment.status = 'confirming';
      console.log(`⏳ Payment confirming (${confirmations}/${requiredConfirmations}):`, payment.orderId);
    }

    await payment.save();

    res.json({ status: 'processed', orderId: payment.orderId });

  } catch (error) {
    console.error('❌ Error processing webhook:', error);
    res.status(500).json({ error: 'Failed to process webhook' });
  }
});

/**
 * POST /api/webhook/manual-confirm
 * Manual confirmation endpoint (for testing/admin purposes)
 */
router.post('/manual-confirm', async (req, res) => {
  try {
    const { orderId, txHash } = req.body;

    if (!orderId || !txHash) {
      return res.status(400).json({ error: 'orderId and txHash are required' });
    }

    const payment = await Payment.findOne({ orderId });

    if (!payment) {
      return res.status(404).json({ error: 'Payment not found' });
    }

    if (payment.status === 'completed') {
      return res.json({ message: 'Payment already completed' });
    }

    // Update payment
    payment.txHash = txHash;
    payment.confirmations = 999; // Mark as manually confirmed
    payment.amountReceived = payment.priceLTC;
    payment.status = 'completed';
    payment.paidAt = payment.paidAt || new Date();
    payment.completedAt = new Date();

    await payment.save();

    // Notify main backend
    await notifyMainBackend(payment);

    console.log('✅ Payment manually confirmed:', orderId);

    res.json({ 
      success: true, 
      message: 'Payment manually confirmed',
      orderId: payment.orderId,
    });

  } catch (error) {
    console.error('❌ Error manually confirming payment:', error);
    res.status(500).json({ error: 'Failed to confirm payment' });
  }
});

module.exports = router;
