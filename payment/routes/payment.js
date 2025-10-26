const express = require('express');
const router = express.Router();
const Payment = require('../models/Payment');
const { getLTCPrice } = require('../services/litecoin');
const { generateQRCode } = require('../services/qrcode');
const { generatePaymentAddress } = require('../services/hdwallet');
const { v4: uuidv4 } = require('uuid');

// Plan prices in USD
const PLAN_PRICES = {
  '30_days': parseFloat(process.env.PRICE_30_DAYS) || 5.00,
  '730_days': parseFloat(process.env.PRICE_730_DAYS) || 73.00,
};

/**
 * POST /api/payment/create
 * Create a new payment order
 */
router.post('/create', async (req, res) => {
  try {
    const { email, planType } = req.body;

    // Validation
    if (!email || !planType) {
      return res.status(400).json({ error: 'Email and planType are required' });
    }

    if (!PLAN_PRICES[planType]) {
      return res.status(400).json({ error: 'Invalid plan type' });
    }

    // Get current LTC price in USD
    const ltcPriceUSD = await getLTCPrice();
    const priceUSD = PLAN_PRICES[planType];
    const priceLTC = (priceUSD / ltcPriceUSD).toFixed(8);

    // Generate unique payment address using HD wallet
    const orderId = uuidv4();
    const { address: paymentAddress, index: addressIndex } = await generatePaymentAddress();

    // Calculate expiration time
    const timeoutMinutes = parseInt(process.env.PAYMENT_TIMEOUT_MINUTES) || 30;
    const expiresAt = new Date(Date.now() + timeoutMinutes * 60 * 1000);

    // Create payment record
    const payment = new Payment({
      email,
      orderId,
      planType,
      priceUSD,
      priceLTC: parseFloat(priceLTC),
      paymentAddress,
      addressIndex,
      expiresAt,
      metadata: {
        userAgent: req.headers['user-agent'],
        ipAddress: req.ip,
      },
    });

    await payment.save();

    // Generate QR code for payment address with amount
    const qrCodeData = `litecoin:${paymentAddress}?amount=${priceLTC}&label=Zurtex_${orderId}`;
    const qrCodeImage = await generateQRCode(qrCodeData);

    res.json({
      success: true,
      orderId,
      paymentAddress,
      amount: priceLTC,
      amountUSD: priceUSD,
      planType,
      expiresAt: expiresAt.toISOString(),
      qrCode: qrCodeImage,
      ltcPriceUSD: ltcPriceUSD.toFixed(2),
    });

  } catch (error) {
    console.error('❌ Error creating payment:', error);
    res.status(500).json({ error: 'Failed to create payment order' });
  }
});

/**
 * GET /api/payment/status/:orderId
 * Check payment status
 */
router.get('/status/:orderId', async (req, res) => {
  try {
    const { orderId } = req.params;

    const payment = await Payment.findOne({ orderId });

    if (!payment) {
      return res.status(404).json({ error: 'Payment not found' });
    }

    // Check if expired
    if (payment.isExpired()) {
      await payment.markExpired();
    }

    res.json({
      orderId: payment.orderId,
      status: payment.status,
      amount: payment.priceLTC,
      amountUSD: payment.priceUSD,
      paymentAddress: payment.paymentAddress,
      txHash: payment.txHash,
      confirmations: payment.confirmations,
      amountReceived: payment.amountReceived,
      expiresAt: payment.expiresAt,
      paidAt: payment.paidAt,
      completedAt: payment.completedAt,
    });

  } catch (error) {
    console.error('❌ Error checking payment status:', error);
    res.status(500).json({ error: 'Failed to check payment status' });
  }
});

/**
 * POST /api/payment/refresh/:orderId
 * Manually trigger payment status check
 */
router.post('/refresh/:orderId', async (req, res) => {
  try {
    const { orderId } = req.params;

    const payment = await Payment.findOne({ orderId });

    if (!payment) {
      return res.status(404).json({ error: 'Payment not found' });
    }

    // Import monitor function
    const { getAddressInfo, checkTransaction } = require('../services/litecoin');

    console.log(`🔄 Manual refresh requested for payment ${orderId}`);

    // Check address for transactions
    const addressInfo = await getAddressInfo(payment.paymentAddress);

    // Combine confirmed and unconfirmed transactions
    const allTxs = [
      ...(addressInfo.unconfirmed_txrefs || []),
      ...(addressInfo.txrefs || [])
    ];

    if (allTxs.length > 0) {
      const relevantTxs = allTxs.filter(tx => {
        const txDate = new Date(tx.received || tx.confirmed);
        return txDate > payment.createdAt;
      });

      if (relevantTxs.length > 0) {
        const latestTx = relevantTxs[0];
        const txDetails = await checkTransaction(latestTx.tx_hash);

        const amountLTC = txDetails.value;
        const confirmations = txDetails.confirmations;

        // Update received amount
        payment.txHash = latestTx.tx_hash;
        payment.amountReceived = amountLTC;

        // Check amount with 3% tolerance
        const expectedAmount = payment.priceLTC;
        const minAcceptable = expectedAmount * 0.97;

        if (amountLTC < minAcceptable) {
          payment.status = 'underpaid';
          payment.confirmations = confirmations;
          payment.paidAt = payment.paidAt || new Date();
        } else {
          payment.confirmations = confirmations;
          const requiredConfirmations = parseInt(process.env.REQUIRED_CONFIRMATIONS) || 2;

          if (confirmations === 0) {
            payment.status = 'confirming';
            payment.paidAt = payment.paidAt || new Date();
          } else if (confirmations >= requiredConfirmations) {
            if (payment.status !== 'completed') {
              payment.status = 'completed';
              payment.completedAt = new Date();
              
              // Notify main backend
              const { notifyMainBackend } = require('../services/callback');
              await notifyMainBackend(payment);
            }
          } else {
            payment.status = 'confirming';
          }
        }

        await payment.save();
      }
    }

    // Return updated status
    res.json({
      success: true,
      orderId: payment.orderId,
      status: payment.status,
      amount: payment.priceLTC,
      amountReceived: payment.amountReceived,
      confirmations: payment.confirmations,
      txHash: payment.txHash,
    });

  } catch (error) {
    console.error('❌ Error refreshing payment status:', error);
    res.status(500).json({ error: 'Failed to refresh payment status' });
  }
});

/**
 * GET /api/payment/user/:email
 * Get all payments for a user
 */
router.get('/user/:email', async (req, res) => {
  try {
    const { email } = req.params;

    const payments = await Payment.find({ email })
      .sort({ createdAt: -1 })
      .limit(20);

    res.json({
      success: true,
      payments: payments.map(p => ({
        orderId: p.orderId,
        planType: p.planType,
        status: p.status,
        amount: p.priceLTC,
        amountUSD: p.priceUSD,
        createdAt: p.createdAt,
        paidAt: p.paidAt,
        completedAt: p.completedAt,
      })),
    });

  } catch (error) {
    console.error('❌ Error fetching user payments:', error);
    res.status(500).json({ error: 'Failed to fetch payments' });
  }
});

/**
 * GET /api/payment/plans
 * Get available plans and prices
 */
router.get('/plans', async (req, res) => {
  try {
    const ltcPriceUSD = await getLTCPrice();

    const plans = Object.entries(PLAN_PRICES).map(([type, priceUSD]) => ({
      type,
      priceUSD,
      priceLTC: (priceUSD / ltcPriceUSD).toFixed(8),
      days: parseInt(type.split('_')[0]),
    }));

    res.json({
      success: true,
      ltcPriceUSD: ltcPriceUSD.toFixed(2),
      plans,
    });

  } catch (error) {
    console.error('❌ Error fetching plans:', error);
    res.status(500).json({ error: 'Failed to fetch plans' });
  }
});

module.exports = router;
