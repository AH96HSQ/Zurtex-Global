const Payment = require('../models/Payment');
const { getAddressInfo, checkTransaction } = require('./litecoin');
const { notifyMainBackend } = require('./callback');

// Monitor interval in milliseconds (10 seconds for faster updates)
const MONITOR_INTERVAL = 10 * 1000;

// Debug mode for more verbose logging
const DEBUG_MODE = process.env.PAYMENT_DEBUG === 'true';

/**
 * Monitor pending payments for incoming transactions
 */
async function monitorPendingPayments() {
  try {
    // Find all pending or confirming payments
    const payments = await Payment.find({
      status: { $in: ['pending', 'confirming'] },
      expiresAt: { $gt: new Date() },
    });

    if (payments.length === 0) {
      return;
    }

    if (DEBUG_MODE || payments.length > 0) {
      console.log(`🔍 Monitoring ${payments.length} pending payment(s)...`);
    }

    for (const payment of payments) {
      try {
        if (DEBUG_MODE) {
          console.log(`🔎 Checking address: ${payment.paymentAddress} (orderId: ${payment.orderId})`);
        }
        
        // Check address for transactions
        const addressInfo = await getAddressInfo(payment.paymentAddress);
        
        if (DEBUG_MODE) {
          console.log(`📊 Address info:`, {
            balance: addressInfo.balance,
            totalReceived: addressInfo.totalReceived,
            txCount: addressInfo.txCount,
            confirmedTxs: addressInfo.txrefs?.length || 0,
            unconfirmedTxs: addressInfo.unconfirmed_txrefs?.length || 0
          });
        }

        // Combine confirmed and unconfirmed transactions
        const allTxs = [
          ...(addressInfo.unconfirmed_txrefs || []),
          ...(addressInfo.txrefs || [])
        ];

        // Check if there are any recent transactions
        if (allTxs.length > 0) {
          console.log(`📝 Found ${allTxs.length} transaction(s) for ${payment.paymentAddress} (${addressInfo.unconfirmed_txrefs?.length || 0} unconfirmed, ${addressInfo.txrefs?.length || 0} confirmed)`);
          
          const relevantTxs = allTxs.filter(tx => {
            // Only process transactions after payment creation
            // Use 'received' for unconfirmed or 'confirmed' for confirmed transactions
            const txDate = new Date(tx.received || tx.confirmed);
            const isRelevant = txDate > payment.createdAt;
            if (DEBUG_MODE) {
              console.log(`  TX ${tx.tx_hash.substring(0, 8)}... - Date: ${txDate.toISOString()}, Payment created: ${payment.createdAt.toISOString()}, Relevant: ${isRelevant}, Confirmations: ${tx.confirmations || 0}`);
            }
            return isRelevant;
          });

          if (relevantTxs.length > 0) {
            console.log(`✅ Processing ${relevantTxs.length} relevant transaction(s)`);
            // Process the most recent transaction
            const latestTx = relevantTxs[0];
            await processTransaction(payment, latestTx);
          } else if (DEBUG_MODE) {
            console.log(`⚠️  No relevant transactions (all are before payment creation)`);
          }
        } else if (DEBUG_MODE) {
          console.log(`⚠️  No transactions found for ${payment.paymentAddress}`);
        }

      } catch (error) {
        console.error(`❌ Error monitoring payment ${payment.orderId}:`, error.message);
      }
    }

  } catch (error) {
    console.error('❌ Error in payment monitor:', error);
  }
}

/**
 * Process a transaction for a payment
 */
async function processTransaction(payment, tx) {
  try {
    // Get full transaction details
    const txDetails = await checkTransaction(tx.tx_hash);

    const amountLTC = txDetails.value;
    const confirmations = txDetails.confirmations;

    // Update received amount regardless of whether it's sufficient
    payment.txHash = tx.tx_hash;
    payment.amountReceived = amountLTC;

    // Check if amount is sufficient (with 3% tolerance in either direction)
    const expectedAmount = payment.priceLTC;
    const minAcceptable = expectedAmount * 0.97;
    const maxAcceptable = expectedAmount * 1.03;

    if (amountLTC < minAcceptable) {
      // Underpaid - track but don't complete
      payment.status = 'underpaid';
      payment.confirmations = confirmations;
      payment.paidAt = payment.paidAt || new Date();
      await payment.save();
      
      console.log(`⚠️  Underpaid for ${payment.orderId}:`, {
        expected: expectedAmount,
        received: amountLTC,
        shortage: (expectedAmount - amountLTC).toFixed(8),
        percentPaid: ((amountLTC / expectedAmount) * 100).toFixed(2) + '%'
      });
      return;
    }

    if (amountLTC > maxAcceptable) {
      console.log(`ℹ️  Overpaid for ${payment.orderId}:`, {
        expected: expectedAmount,
        received: amountLTC,
        excess: (amountLTC - expectedAmount).toFixed(8),
        percentPaid: ((amountLTC / expectedAmount) * 100).toFixed(2) + '%'
      });
      // Continue processing - overpayment is acceptable
    }

    // Update payment
    payment.confirmations = confirmations;

    const requiredConfirmations = parseInt(process.env.REQUIRED_CONFIRMATIONS) || 2;

    if (confirmations === 0) {
      payment.status = 'confirming';
      payment.paidAt = payment.paidAt || new Date();
      console.log(`💰 Payment received for ${payment.orderId}, waiting for confirmations`);
    } else if (confirmations >= requiredConfirmations) {
      if (payment.status !== 'completed') {
        payment.status = 'completed';
        payment.completedAt = new Date();
        console.log(`✅ Payment completed: ${payment.orderId}`);

        // Notify main backend
        await notifyMainBackend(payment);
      }
    } else {
      payment.status = 'confirming';
      console.log(`⏳ Payment confirming (${confirmations}/${requiredConfirmations}): ${payment.orderId}`);
    }

    await payment.save();

  } catch (error) {
    console.error('❌ Error processing transaction:', error);
  }
}

/**
 * Mark expired payments
 */
async function markExpiredPayments() {
  try {
    const result = await Payment.updateMany(
      {
        status: 'pending',
        expiresAt: { $lt: new Date() },
      },
      {
        $set: { status: 'expired' },
      }
    );

    if (result.modifiedCount > 0) {
      console.log(`⏰ Marked ${result.modifiedCount} payment(s) as expired`);
    }

  } catch (error) {
    console.error('❌ Error marking expired payments:', error);
  }
}

/**
 * Start the payment monitoring service
 */
function startPaymentMonitor() {
  console.log('🚀 Starting payment monitor...');
  console.log(`⏱️  Monitor interval: ${MONITOR_INTERVAL / 1000} seconds`);
  console.log(`🔍 Debug mode: ${DEBUG_MODE ? 'enabled' : 'disabled'}`);
  console.log(`✅ Required confirmations: ${process.env.REQUIRED_CONFIRMATIONS || 2}`);

  // Run immediately on startup
  console.log('🔄 Running initial payment check...');
  monitorPendingPayments();
  markExpiredPayments();

  // Then run at intervals
  setInterval(() => {
    monitorPendingPayments();
    markExpiredPayments();
  }, MONITOR_INTERVAL);

  console.log('✅ Payment monitor started successfully');
}

module.exports = {
  startPaymentMonitor,
};
