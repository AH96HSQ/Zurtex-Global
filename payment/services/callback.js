const axios = require('axios');

/**
 * Notify main Zurtex backend when payment is completed
 */
async function notifyMainBackend(payment) {
  try {
    const backendUrl = process.env.MAIN_BACKEND_URL;

    if (!backendUrl) {
      console.warn('⚠️  MAIN_BACKEND_URL not configured, skipping notification');
      return;
    }

    const payload = {
      email: payment.email,
      orderId: payment.orderId,
      planType: payment.planType,
      amountLTC: payment.priceLTC,
      amountUSD: payment.priceUSD,
      txHash: payment.txHash,
      paidAt: payment.paidAt,
      completedAt: payment.completedAt,
    };

    console.log('📤 Notifying main backend:', backendUrl);

    const response = await axios.post(backendUrl, payload, {
      timeout: 30000, // 30 seconds - backend needs time to process
      headers: {
        'Content-Type': 'application/json',
      },
    });

    console.log('✅ Main backend notified successfully:', response.data);
    return response.data;

  } catch (error) {
    console.error('❌ Error notifying main backend:', error.message);
    // Don't throw - payment is still valid even if notification fails
    // You may want to implement a retry mechanism here
  }
}

module.exports = {
  notifyMainBackend,
};
