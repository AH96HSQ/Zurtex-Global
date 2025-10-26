#!/usr/bin/env node
/**
 * Sweep all funds from payment addresses to merchant wallet
 * 
 * This script:
 * 1. Finds all completed payments from MongoDB
 * 2. Checks each payment address for balance
 * 3. Derives private keys for addresses with funds
 * 4. Builds a single transaction to sweep all UTXOs to merchant address
 * 5. Broadcasts the transaction via SoChain
 * 
 * SECURITY NOTES:
 * - Only run this on a secure machine
 * - Keep HD_WALLET_MNEMONIC secret
 * - Use --dry-run first to preview the transaction
 * - Transaction fees will be automatically calculated
 * 
 * Usage:
 *   node sweep-all.js --dry-run    # Preview without broadcasting
 *   node sweep-all.js --execute    # Actually broadcast the transaction
 */

require('dotenv').config();
const mongoose = require('mongoose');
const axios = require('axios');
const bitcoin = require('bitcoinjs-lib');
const { BIP32Factory } = require('bip32');
const bip39 = require('bip39');
const ecc = require('tiny-secp256k1');
const readline = require('readline');

// Import ECPair - handle both CommonJS and ES6 module formats
let ECPair;
try {
  const ecpairModule = require('ecpair');
  ECPair = ecpairModule.ECPairFactory ? ecpairModule.ECPairFactory(ecc) : ecpairModule.default(ecc);
} catch (e) {
  console.error('Failed to load ecpair module:', e.message);
  process.exit(1);
}

const bip32 = BIP32Factory(ecc);

// Litecoin network parameters
const litecoin = {
  messagePrefix: '\x19Litecoin Signed Message:\n',
  bech32: 'ltc',
  bip32: {
    public: 0x019da462,
    private: 0x019d9cfe,
  },
  pubKeyHash: 0x30,
  scriptHash: 0x32,
  wif: 0xb0,
};

// Convert satoshis to LTC
const satoshisToLTC = (satoshis) => satoshis / 100000000;

// Convert LTC to satoshis (unused but kept for reference)
// const ltcToSatoshis = (ltc) => Math.round(ltc * 100000000);

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
 * Derive private key for an address index
 */
function derivePrivateKey(index, mnemonic) {
  const seed = bip39.mnemonicToSeedSync(mnemonic);
  const root = bip32.fromSeed(seed, litecoin);
  const path = `m/44'/2'/0'/0/${index}`;
  const child = root.derivePath(path);
  return child;
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

/**
 * Get current recommended fee rate from SoChain
 */
async function getFeeRate() {
  // SoChain doesn't provide fee estimates, use a conservative default
  return 50; // 50 sat/byte - reasonable for Litecoin
}

/**
 * Broadcast raw transaction via BlockCypher
 */
async function broadcastTransaction(rawTxHex) {
  return retryWithBackoff(async () => {
    try {
      const token = process.env.BLOCKCYPHER_TOKEN;
      const url = 'https://api.blockcypher.com/v1/ltc/main/txs/push';
      const params = token ? { token } : {};
      
      const response = await axios.post(url, { tx: rawTxHex }, { params });
      return response.data.tx.hash;
    } catch (error) {
      console.error('❌ Broadcast error:', error.response?.data || error.message);
      throw error;
    }
  });
}

/**
 * Ask user for confirmation
 */
function confirm(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(question + ' (yes/no): ', (answer) => {
      rl.close();
      resolve(answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y');
    });
  });
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const execute = args.includes('--execute');

  if (!dryRun && !execute) {
    console.log('Usage:');
    console.log('  node sweep-all.js --dry-run    # Preview transaction');
    console.log('  node sweep-all.js --execute    # Broadcast transaction');
    process.exit(1);
  }

  // Check environment
  const mnemonic = process.env.HD_WALLET_MNEMONIC;
  const merchantAddress = process.env.MERCHANT_LTC_ADDRESS;
  const mongoUri = process.env.MONGODB_URI;

  if (!mnemonic || !merchantAddress || !mongoUri) {
    console.error('❌ Missing required environment variables:');
    console.error('   HD_WALLET_MNEMONIC, MERCHANT_LTC_ADDRESS, MONGODB_URI');
    process.exit(1);
  }

  if (!bip39.validateMnemonic(mnemonic)) {
    console.error('❌ Invalid HD_WALLET_MNEMONIC');
    process.exit(1);
  }

  console.log('🔍 Connecting to MongoDB...');
  await mongoose.connect(mongoUri);

  const Payment = require('./models/Payment');

  console.log('🔍 Finding completed payments...');
  const payments = await Payment.find({ 
    status: 'completed',
    addressIndex: { $exists: true },
    swept: { $ne: true } // Only get payments that haven't been swept
  }).sort({ addressIndex: 1 });

  console.log(`📊 Found ${payments.length} completed payment(s) not yet swept`);

  if (payments.length === 0) {
    console.log('✅ No payments to sweep');
    await mongoose.disconnect();
    process.exit(0);
  }

  // Check each address for balance
  console.log('\n🔍 Checking addresses for funds...\n');
  
  const addressesWithFunds = [];
  let totalBalance = 0;

  for (let i = 0; i < payments.length; i++) {
    const payment = payments[i];
    
    try {
      const addressInfo = await getAddressInfo(payment.paymentAddress);
      
      if (addressInfo && addressInfo.balance > 0) {
        const balanceLTC = satoshisToLTC(addressInfo.balance);
        console.log(`💰 ${payment.paymentAddress}: ${balanceLTC.toFixed(8)} LTC (${addressInfo.txrefs?.length || 0} UTXOs)`);
        
        addressesWithFunds.push({
          address: payment.paymentAddress,
          index: payment.addressIndex,
          balance: addressInfo.balance,
          balanceLTC,
          txrefs: addressInfo.txrefs || [],
          paymentId: payment._id, // Store payment ID for updating later
        });
        
        totalBalance += addressInfo.balance;
      } else {
        console.log(`   ${payment.paymentAddress}: 0 LTC (already swept)`);
      }
    } catch (error) {
      console.error(`❌ Error checking ${payment.paymentAddress}:`, error.message);
    }
    
    // Add delay to avoid rate limiting (BlockCypher: 200 req/hour, ~18 seconds between requests safe)
    if (i < payments.length - 1) {
      await new Promise(resolve => setTimeout(resolve, 2000)); // 2 seconds between requests
    }
  }

  console.log('\n' + '='.repeat(70));
  console.log(`💵 Total balance: ${satoshisToLTC(totalBalance).toFixed(8)} LTC`);
  console.log(`📍 Addresses with funds: ${addressesWithFunds.length}`);
  console.log(`🎯 Destination: ${merchantAddress}`);
  console.log('='.repeat(70) + '\n');

  if (addressesWithFunds.length === 0) {
    console.log('✅ All addresses already swept');
    await mongoose.disconnect();
    process.exit(0);
  }

  // Get fee rate
  const feeRate = await getFeeRate();
  console.log(`📊 Fee rate: ${feeRate} sat/byte`);

  // Build transaction
  console.log('\n🔨 Building transaction...\n');

  const psbt = new bitcoin.Psbt({ network: litecoin });
  let inputCount = 0;

  // Add all UTXOs as inputs
  for (const addrData of addressesWithFunds) {
    for (const utxo of addrData.txrefs) {
      if (utxo.tx_output_n === undefined) continue;
      
      // Fetch full transaction to get witness data
      try {
        const txData = await retryWithBackoff(async () => {
          const token = process.env.BLOCKCYPHER_TOKEN;
          const txUrl = `https://api.blockcypher.com/v1/ltc/main/txs/${utxo.tx_hash}?includeHex=true`;
          const params = token ? { token } : {};
          
          const txResponse = await axios.get(txUrl, { params });
          return txResponse.data;
        });
        
        const output = txData.outputs[utxo.tx_output_n];
        
        psbt.addInput({
          hash: utxo.tx_hash,
          index: utxo.tx_output_n,
          witnessUtxo: {
            script: Buffer.from(output.script, 'hex'),
            value: utxo.value,
          },
        });
        
        inputCount++;
        console.log(`  ✅ Input ${inputCount}: ${utxo.tx_hash.substring(0, 8)}.../${utxo.tx_output_n} (${satoshisToLTC(utxo.value).toFixed(8)} LTC)`);
        
        // Add delay to avoid rate limiting (BlockCypher: 200 req/hour)
        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (error) {
        console.error(`  ❌ Failed to add UTXO ${utxo.tx_hash}:`, error.message);
      }
    }
  }

  if (inputCount === 0) {
    console.error('❌ No valid UTXOs found');
    await mongoose.disconnect();
    process.exit(1);
  }

  // Estimate transaction size (bytes)
  // P2WPKH input: ~68 bytes, output: ~31 bytes, overhead: ~10 bytes
  const estimatedSize = (inputCount * 68) + 31 + 10;
  const estimatedFee = estimatedSize * feeRate;
  const amountToSend = totalBalance - estimatedFee;

  console.log(`\n📊 Transaction details:`);
  console.log(`   Inputs: ${inputCount}`);
  console.log(`   Estimated size: ${estimatedSize} bytes`);
  console.log(`   Fee: ${satoshisToLTC(estimatedFee).toFixed(8)} LTC (${feeRate} sat/byte)`);
  console.log(`   Amount to send: ${satoshisToLTC(amountToSend).toFixed(8)} LTC`);

  if (amountToSend <= 0) {
    console.error('❌ Amount too small to cover fees');
    await mongoose.disconnect();
    process.exit(1);
  }

  // Add output
  psbt.addOutput({
    address: merchantAddress,
    value: amountToSend,
  });

  // Sign all inputs
  console.log('\n🔐 Signing inputs...');
  let inputIndex = 0;
  for (const addrData of addressesWithFunds) {
    const child = derivePrivateKey(addrData.index, mnemonic);
    const keyPair = ECPair.fromPrivateKey(child.privateKey, { network: litecoin });
    
    for (let j = 0; j < addrData.txrefs.length; j++) {
      try {
        psbt.signInput(inputIndex, keyPair);
        inputIndex++;
      } catch (error) {
        console.error(`  ❌ Failed to sign input ${inputIndex}:`, error.message);
        inputIndex++;
      }
    }
  }

  psbt.finalizeAllInputs();
  const rawTx = psbt.extractTransaction();
  const txHex = rawTx.toHex();
  const actualSize = txHex.length / 2;
  const actualFee = totalBalance - amountToSend;

  console.log(`\n✅ Transaction built successfully`);
  console.log(`   Actual size: ${actualSize} bytes`);
  console.log(`   Actual fee: ${satoshisToLTC(actualFee).toFixed(8)} LTC`);
  console.log(`   Raw TX (first 100 chars): ${txHex.substring(0, 100)}...`);

  if (dryRun) {
    console.log('\n🔍 DRY RUN MODE - Transaction NOT broadcasted');
    console.log('\nTo broadcast this transaction, run:');
    console.log('  node sweep-all.js --execute');
    await mongoose.disconnect();
    process.exit(0);
  }

  // Execute mode - ask for confirmation
  console.log('\n⚠️  EXECUTE MODE - Transaction will be broadcasted!');
  console.log(`   Sweeping ${satoshisToLTC(amountToSend).toFixed(8)} LTC to ${merchantAddress}`);
  console.log(`   Fee: ${satoshisToLTC(actualFee).toFixed(8)} LTC`);
  
  const confirmed = await confirm('\n⚠️  Are you sure you want to broadcast this transaction?');
  
  if (!confirmed) {
    console.log('❌ Transaction cancelled');
    await mongoose.disconnect();
    process.exit(0);
  }

  console.log('\n📡 Broadcasting transaction...');
  
  try {
    const txHash = await broadcastTransaction(txHex);
    console.log('\n✅ Transaction broadcasted successfully!');
    console.log(`   TX Hash: ${txHash}`);
    console.log(`   View: https://live.blockcypher.com/ltc/tx/${txHash}/`);
    
    // Mark all swept addresses as swept in database
    console.log('\n💾 Updating database...');
    const paymentIds = addressesWithFunds.map(a => a.paymentId);
    const updateResult = await Payment.updateMany(
      { _id: { $in: paymentIds } },
      { 
        $set: {
          swept: true,
          sweptAt: new Date(),
          sweptTxHash: txHash
        }
      }
    );
    console.log(`✅ Marked ${updateResult.modifiedCount} payment(s) as swept`);
    
  } catch (error) {
    console.error('\n❌ Failed to broadcast transaction:', error.message);
    await mongoose.disconnect();
    process.exit(1);
  }

  await mongoose.disconnect();
  console.log('\n✅ Done!');
}

main().catch(err => {
  console.error('❌ Fatal error:', err);
  process.exit(1);
});
