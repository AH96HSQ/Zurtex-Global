const bitcoin = require('bitcoinjs-lib');
const { BIP32Factory } = require('bip32');
const bip39 = require('bip39');
const ecc = require('tiny-secp256k1');

// Initialize BIP32 with tiny-secp256k1
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

/**
 * Generate a deterministic Litecoin address from an index
 * @param {number} index - The derivation index (0, 1, 2, ...)
 * @returns {string} Litecoin address
 */
function generateAddress(index) {
  try {
    // Get mnemonic from environment (you should have this set)
    const mnemonic = process.env.HD_WALLET_MNEMONIC;
    
    if (!mnemonic) {
      throw new Error('HD_WALLET_MNEMONIC not set in environment variables');
    }

    // Validate mnemonic
    if (!bip39.validateMnemonic(mnemonic)) {
      throw new Error('Invalid mnemonic phrase');
    }

    // Generate seed from mnemonic
    const seed = bip39.mnemonicToSeedSync(mnemonic);

    // Create master key
    const root = bip32.fromSeed(seed, litecoin);

    // Derive child key using BIP44 path for Litecoin
    // m/44'/2'/0'/0/index
    // 44' = BIP44
    // 2' = Litecoin coin type
    // 0' = Account 0
    // 0 = External chain (receiving addresses)
    // index = Address index
    const path = `m/44'/2'/0'/0/${index}`;
    const child = root.derivePath(path);

    // Generate P2WPKH address (native SegWit, starts with ltc1)
    const { address } = bitcoin.payments.p2wpkh({
      pubkey: child.publicKey,
      network: litecoin,
    });

    return address;
  } catch (error) {
    console.error('❌ Error generating address:', error);
    throw error;
  }
}

/**
 * Generate a new mnemonic phrase (run once to create your wallet)
 * @returns {string} 12-word mnemonic phrase
 */
function generateMnemonic() {
  return bip39.generateMnemonic();
}

/**
 * Get the next available address index from the database
 * This ensures we don't reuse addresses
 */
async function getNextAddressIndex() {
  const Payment = require('../models/Payment');
  
  try {
    // Find the highest index used so far
    const lastPayment = await Payment.findOne({
      addressIndex: { $exists: true },
    }).sort({ addressIndex: -1 });

    if (!lastPayment) {
      return 0; // Start from index 0
    }

    return lastPayment.addressIndex + 1;
  } catch (error) {
    console.error('❌ Error getting next address index:', error);
    throw error;
  }
}

/**
 * Generate a unique payment address for a new order
 * @returns {Object} { address, index }
 */
async function generatePaymentAddress() {
  const index = await getNextAddressIndex();
  const address = generateAddress(index);
  
  return {
    address,
    index,
  };
}

module.exports = {
  generateAddress,
  generateMnemonic,
  generatePaymentAddress,
};
