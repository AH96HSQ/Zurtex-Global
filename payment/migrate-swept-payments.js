#!/usr/bin/env node
/**
 * Migration script to mark already-swept payments
 * Checks blockchain for each completed payment and marks as swept if balance is 0
 */

require('dotenv').config();
const mongoose = require('mongoose');
const axios = require('axios');

/**
 * Retry wrapper with exponential backoff for transient errors
 */
async function retryWithBackoff(fn, maxRetries = 3, baseDelay = 2000) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      const isRetriable = error.response?.status >= 500 || error.code === 'ECONNRESET' || error.code === 'ETIMEDOUT';
      
      if (!isRetriable || attempt === maxRetries) {
        throw error;
      }
      
      const delay = baseDelay * Math.pow(2, attempt - 1);
      console.log(`   ⚠️  Attempt ${attempt} failed (${error.response?.status || error.code}), retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

/**
 * Get address info from BlockCypher (free tier: 200 req/hour)
 */
async function getAddressInfo(address) {
  return retryWithBackoff(async () => {
    try {
      const token = process.env.BLOCKCYPHER_TOKEN;
      const url = `https://api.blockcypher.com/v1/ltc/main/addrs/${address}`;
      const params = token ? { token, unspentOnly: true } : { unspentOnly: true };
      
      const response = await axios.get(url, { params });
      
      const balance = response.data.balance || 0;
      const txrefs = response.data.txrefs || [];
      
      return { balance, txrefs };
    } catch (err) {
      if (err.response?.status === 404) {
        return { balance: 0, txrefs: [] }; // Address never used
      }
      throw err;
    }
  });
}

async function main() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/zurtex_payment';
  
  console.log('🔍 Connecting to MongoDB...');
  await mongoose.connect(mongoUri);

  const Payment = require('./models/Payment');

  console.log('🔍 Finding completed payments not yet marked as swept...');
  const payments = await Payment.find({ 
    status: 'completed',
    addressIndex: { $exists: true },
    swept: { $ne: true }
  }).sort({ addressIndex: 1 });

  console.log(`📊 Found ${payments.length} payment(s) to check\n`);

  if (payments.length === 0) {
    console.log('✅ No payments to check - all are already marked');
    await mongoose.disconnect();
    process.exit(0);
  }

  let sweptCount = 0;
  let notSweptCount = 0;

  for (let i = 0; i < payments.length; i++) {
    const payment = payments[i];
    
    try {
      console.log(`Checking ${i + 1}/${payments.length}: ${payment.paymentAddress}`);
      
      const addressInfo = await getAddressInfo(payment.paymentAddress);
      
      if (addressInfo.balance === 0) {
        // Address has been swept (or never received funds)
        console.log(`   ✅ Balance: 0 LTC - Marking as swept`);
        
        payment.swept = true;
        payment.sweptAt = payment.completedAt || new Date(); // Use completion date as estimate
        payment.sweptTxHash = null; // Unknown sweep transaction
        await payment.save();
        
        sweptCount++;
      } else {
        // Address still has funds
        const balanceLTC = addressInfo.balance / 100000000;
        console.log(`   💰 Balance: ${balanceLTC.toFixed(8)} LTC - Needs sweep`);
        notSweptCount++;
      }
      
      // Add delay to avoid rate limiting (BlockCypher: 200 req/hour)
      if (i < payments.length - 1) {
        await new Promise(resolve => setTimeout(resolve, 2000)); // 2 seconds between requests
      }
      
    } catch (error) {
      console.error(`   ❌ Error checking ${payment.paymentAddress}:`, error.message);
    }
  }

  console.log('\n' + '='.repeat(70));
  console.log('📊 Migration Summary:');
  console.log(`   ✅ Marked as swept: ${sweptCount}`);
  console.log(`   💰 Still has funds: ${notSweptCount}`);
  console.log(`   ❌ Errors: ${payments.length - sweptCount - notSweptCount}`);
  console.log('='.repeat(70));

  await mongoose.disconnect();
  console.log('\n✅ Migration complete!');
}

main().catch(err => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
