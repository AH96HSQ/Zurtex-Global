#!/usr/bin/env node
/**
 * Check sweep status of completed payments
 * Shows which payments have been swept and which haven't
 */

require('dotenv').config();
const mongoose = require('mongoose');

async function main() {
  const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/zurtex_payment';
  
  console.log('🔍 Connecting to MongoDB...');
  await mongoose.connect(mongoUri);

  const Payment = require('./models/Payment');

  console.log('📊 Checking sweep status...\n');

  // Get completed payments
  const completed = await Payment.find({ status: 'completed' }).sort({ completedAt: -1 });
  
  console.log(`Total completed payments: ${completed.length}\n`);

  const swept = completed.filter(p => p.swept);
  const notSwept = completed.filter(p => !p.swept);

  console.log('✅ Swept Payments:');
  console.log('='.repeat(70));
  if (swept.length === 0) {
    console.log('   None');
  } else {
    for (const payment of swept) {
      const sweptDate = payment.sweptAt ? payment.sweptAt.toISOString() : 'Unknown';
      console.log(`   ${payment.paymentAddress}`);
      console.log(`   Order: ${payment.orderId}`);
      console.log(`   Amount: ${payment.priceLTC} LTC`);
      console.log(`   Swept: ${sweptDate}`);
      if (payment.sweptTxHash) {
        console.log(`   Sweep TX: ${payment.sweptTxHash}`);
        console.log(`   View: https://live.blockcypher.com/ltc/tx/${payment.sweptTxHash}/`);
      }
      console.log('');
    }
  }

  console.log('\n⏳ Not Yet Swept:');
  console.log('='.repeat(70));
  if (notSwept.length === 0) {
    console.log('   None - all payments have been swept!');
  } else {
    for (const payment of notSwept) {
      const completedDate = payment.completedAt ? payment.completedAt.toISOString() : 'Unknown';
      console.log(`   ${payment.paymentAddress}`);
      console.log(`   Order: ${payment.orderId}`);
      console.log(`   Amount: ${payment.priceLTC} LTC`);
      console.log(`   Completed: ${completedDate}`);
      console.log('');
    }
  }

  console.log('\n📈 Summary:');
  console.log(`   ✅ Swept: ${swept.length}`);
  console.log(`   ⏳ Pending sweep: ${notSwept.length}`);
  console.log(`   📊 Total: ${completed.length}`);

  await mongoose.disconnect();
}

main().catch(err => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
