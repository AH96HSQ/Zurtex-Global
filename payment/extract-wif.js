#!/usr/bin/env node

require('dotenv').config();
const { BIP32Factory } = require('bip32');
const bip39 = require('bip39');
const ecc = require('tiny-secp256k1');
const bitcoin = require('bitcoinjs-lib');

const bip32 = BIP32Factory(ecc);

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

function usage() {
  console.log('Usage: node extract-wif.js <index>');
  console.log('Example: node extract-wif.js 0');
  process.exit(1);
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    usage();
  }

  const index = parseInt(args[0], 10);
  if (isNaN(index) || index < 0) {
    usage();
  }

  const mnemonic = process.env.HD_WALLET_MNEMONIC;
  if (!mnemonic) {
    console.error('HD_WALLET_MNEMONIC not set in .env');
    process.exit(1);
  }

  if (!bip39.validateMnemonic(mnemonic)) {
    console.error('Invalid mnemonic in HD_WALLET_MNEMONIC');
    process.exit(1);
  }

  const seed = bip39.mnemonicToSeedSync(mnemonic);
  const root = bip32.fromSeed(seed, litecoin);
  const path = `m/44'/2'/0'/0/${index}`;
  const child = root.derivePath(path);

  const wif = child.toWIF();
  const { address } = bitcoin.payments.p2wpkh({ pubkey: child.publicKey, network: litecoin });

  console.log('Index:', index);
  console.log('Address:', address);
  console.log('WIF (private key):', wif);
  console.log('\nImportant: keep the WIF secret. Import into a trusted wallet to sweep funds.');
}

main().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
