#!/usr/bin/env node
/**
 * Simple sweep script - uses WIF for compatibility
 */

require('dotenv').config();
const mongoose = require('mongoose');
const axios = require('axios');

const BLOCKCYPHER_API = 'https://api.blockcypher.com/v1/ltc/main';

async function getAddressInfo(address) {
  try {
    const token = process.env.BLOCKCYPHER_TOKEN;
    const url = `${BLOCKCYPHER_API}/addrs/${address}`;
    const params = token ? { token, unspentOnly: true } : { unspentOnly: true };
    const response = await axios.get(url, { params });
    return response.data;
  } catch (err) {
    if (err.response?.status === 404) return null;
    throw err;
  }
}


async function main() {
  const args = process.argv.slice(2);
  if (!args.includes('--list')) {
    console.log('Usage: node sweep-simple.js --list');
    process.exit(1);
  }

  const mongoUri = process.env.MONGODB_URI;
  const merchantAddress = process.env.MERCHANT_LTC_ADDRESS;

  console.log('🔍 Connecting to MongoDB...');
  await mongoose.connect(mongoUri);

  const Payment = require('./models/Payment');
  const payments = await Payment.find({ 
    status: 'completed',
    addressIndex: { $exists: true }
  }).sort({ addressIndex: 1 });

  console.log(`📊 Found ${payments.length} completed payment(s)\n`);

  if (payments.length === 0) {
    console.log('✅ No payments to check');
    await mongoose.disconnect();
    process.exit(0);
  }

  let totalBalance = 0;
  const addressesWithFunds = [];

  for (const payment of payments) {
    try {
      const addressInfo = await getAddressInfo(payment.paymentAddress);
      
      if (addressInfo && addressInfo.balance > 0) {
        const balanceLTC = addressInfo.balance / 100000000;
        console.log(`💰 Index ${payment.addressIndex}: ${payment.paymentAddress}`);
        console.log(`   Balance: ${balanceLTC.toFixed(8)} LTC`);
        
        addressesWithFunds.push({
          address: payment.paymentAddress,
          index: payment.addressIndex,
          balance: addressInfo.balance,
          balanceLTC,
        });
        
        totalBalance += addressInfo.balance;
      }
    } catch (error) {
      console.error(`❌ Error checking ${payment.paymentAddress}:`, error.message);
    }
  }

  console.log('\n' + '='.repeat(70));
  console.log(`💵 Total balance: ${(totalBalance / 100000000).toFixed(8)} LTC`);
  console.log(`🎯 Destination: ${merchantAddress}`);
  console.log('='.repeat(70));

  if (addressesWithFunds.length === 0) {
    console.log('\n✅ All addresses already swept');
    await mongoose.disconnect();
    process.exit(0);
  }

  console.log('\n📋 To sweep these funds, use one of these methods:\n');
  console.log('Method 1: Manual sweep with Electrum-LTC (recommended)');
  console.log('  - Import your HD_WALLET_MNEMONIC into Electrum-LTC');
  console.log('  - Use Tools > Sweep to send all funds to merchant address\n');
  
  console.log('Method 2: Get WIF for each address');
  console.log('  - Run: node extract-wif.js <index>');
  console.log('  - Import WIF into wallet and send funds\n');

  for (const addr of addressesWithFunds) {
    console.log(`  node extract-wif.js ${addr.index}  # ${addr.balanceLTC.toFixed(8)} LTC`);
  }

  await mongoose.disconnect();
}

main().catch(err => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
