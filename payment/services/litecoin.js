const axios = require('axios');

/**
 * Get current LTC price in USD using CoinGecko API (no auth required)
 */
async function getLTCPrice() {
  try {
    const response = await axios.get('https://api.coingecko.com/api/v3/simple/price', {
      params: {
        ids: 'litecoin',
        vs_currencies: 'usd',
      },
    });

    const price = response.data.litecoin.usd;
    console.log(`💵 Current LTC price: $${price}`);
    return price;

  } catch (error) {
    console.error('❌ Error fetching LTC price:', error.message);
    // Fallback to approximate price if API fails
    return 85.0; // Approximate LTC price as fallback
  }
}

/**
 * Check transaction confirmations using Blockcypher API
 */
async function checkTransaction(txHash) {
  try {
    const token = process.env.BLOCKCYPHER_TOKEN;
    const url = `https://api.blockcypher.com/v1/ltc/main/txs/${txHash}`;
    
    const params = token ? { token } : {};
    const response = await axios.get(url, { params });

    return {
      confirmations: response.data.confirmations || 0,
      value: response.data.total / 100000000, // Convert satoshis to LTC
      blockHeight: response.data.block_height,
      received: response.data.received,
    };

  } catch (error) {
    console.error('❌ Error checking transaction:', error.message);
    throw error;
  }
}

/**
 * Get address balance and transactions using Blockcypher API
 */
async function getAddressInfo(address) {
  try {
    const token = process.env.BLOCKCYPHER_TOKEN;
    const url = `https://api.blockcypher.com/v1/ltc/main/addrs/${address}`;
    
    const params = token ? { token } : {};
    const response = await axios.get(url, { params });

    return {
      balance: response.data.balance / 100000000, // Convert satoshis to LTC
      totalReceived: response.data.total_received / 100000000,
      totalSent: response.data.total_sent / 100000000,
      txCount: response.data.n_tx,
      txrefs: response.data.txrefs || [],
    };

  } catch (error) {
    console.error('❌ Error fetching address info:', error.message);
    throw error;
  }
}

/**
 * Create webhook for address monitoring
 * This allows Blockcypher to notify us when transactions occur
 */
async function createWebhook(address, callbackUrl) {
  try {
    const token = process.env.BLOCKCYPHER_TOKEN;
    
    if (!token) {
      console.warn('⚠️  BLOCKCYPHER_TOKEN not set, webhook creation skipped');
      return null;
    }

    const response = await axios.post(
      `https://api.blockcypher.com/v1/ltc/main/hooks?token=${token}`,
      {
        event: 'tx-confirmation',
        address: address,
        url: callbackUrl,
        confirmations: 1,
      }
    );

    console.log('✅ Webhook created for address:', address);
    return response.data;

  } catch (error) {
    // Webhook might already exist, which is fine
    if (error.response?.status === 400) {
      console.log('ℹ️  Webhook already exists for address:', address);
      return null;
    }
    console.error('❌ Error creating webhook:', error.message);
    throw error;
  }
}

/**
 * Generate payment address
 * In production, use HD wallet derivation for unique addresses
 * For now, returns merchant address (requires manual reconciliation)
 */
function generatePaymentAddress() {
  return process.env.MERCHANT_LTC_ADDRESS;
}

module.exports = {
  getLTCPrice,
  checkTransaction,
  getAddressInfo,
  createWebhook,
  generatePaymentAddress,
};
