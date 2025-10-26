/**
 * HD Wallet Verification Script
 * Generates and displays the first address to verify setup
 */

require('dotenv').config();
const { generateAddress } = require('./services/hdwallet');

console.log('🔍 Verifying HD Wallet Setup...\n');

if (!process.env.HD_WALLET_MNEMONIC) {
    console.error('❌ Error: HD_WALLET_MNEMONIC not found in .env file');
    console.log('\n📝 Please add your mnemonic to .env file:');
    console.log('   HD_WALLET_MNEMONIC="your twelve word mnemonic phrase here"');
    process.exit(1);
}

try {
    console.log('✅ Mnemonic found in .env');
    console.log(`   Words: ${process.env.HD_WALLET_MNEMONIC.split(' ').length}`);
    
    console.log('\n🔐 Generating first 5 addresses:\n');
    console.log('━'.repeat(80));
    console.log('Index | Address');
    console.log('━'.repeat(80));
    
    for (let i = 0; i < 5; i++) {
        const address = generateAddress(i);
        console.log(`  ${i}   | ${address}`);
    }
    
    console.log('━'.repeat(80));
    
    console.log('\n✅ HD Wallet is working correctly!');
    console.log('\n💡 Each payment order will get a unique address starting from index 0');
    console.log('   All addresses are derived from your master mnemonic phrase\n');
    
} catch (error) {
    console.error('❌ Error generating addresses:', error.message);
    console.log('\n🔧 Troubleshooting:');
    console.log('   - Check that your mnemonic has exactly 12 words');
    console.log('   - Ensure words are separated by single spaces');
    console.log('   - Verify words are from the BIP39 word list');
    process.exit(1);
}
