const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  // User identification
  email: {
    type: String,
    required: true,
    index: true,
  },
  
  // Payment details
  orderId: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  
  // Plan details
  planType: {
    type: String,
    enum: ['30_days', '730_days'],
    required: true,
  },
  
  priceUSD: {
    type: Number,
    required: true,
  },
  
  priceLTC: {
    type: Number,
    required: true,
  },
  
  // Litecoin payment address (unique for each payment)
  paymentAddress: {
    type: String,
    required: true,
    unique: true,
  },
  
  // HD Wallet derivation index
  addressIndex: {
    type: Number,
    required: true,
    unique: true,
    index: true,
  },
  
  // Payment status
  status: {
    type: String,
    enum: ['pending', 'confirming', 'completed', 'expired', 'failed', 'underpaid'],
    default: 'pending',
    index: true,
  },
  
  // Transaction details
  txHash: {
    type: String,
    default: null,
  },
  
  confirmations: {
    type: Number,
    default: 0,
  },
  
  amountReceived: {
    type: Number,
    default: 0,
  },
  
  // Timestamps
  createdAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
  
  expiresAt: {
    type: Date,
    required: true,
    index: true,
  },
  
  paidAt: {
    type: Date,
    default: null,
  },
  
  completedAt: {
    type: Date,
    default: null,
  },
  
  // Sweep tracking
  swept: {
    type: Boolean,
    default: false,
    index: true,
  },
  
  sweptAt: {
    type: Date,
    default: null,
  },
  
  sweptTxHash: {
    type: String,
    default: null,
  },
  
  // Metadata
  metadata: {
    userAgent: String,
    ipAddress: String,
  },
}, {
  timestamps: true,
});

// Index for cleanup queries
paymentSchema.index({ status: 1, expiresAt: 1 });

// Method to check if payment is expired
paymentSchema.methods.isExpired = function() {
  return this.status === 'pending' && new Date() > this.expiresAt;
};

// Method to mark as expired
paymentSchema.methods.markExpired = async function() {
  this.status = 'expired';
  return await this.save();
};

module.exports = mongoose.model('Payment', paymentSchema);
