require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const paymentRoutes = require('./routes/payment');
const webhookRoutes = require('./routes/webhook');
const { startPaymentMonitor } = require('./services/paymentMonitor');

const app = express();
const PORT = process.env.PORT || 5006;

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => {
  console.log('✅ Connected to MongoDB');
  // Start payment monitoring after DB connection
  startPaymentMonitor();
})
.catch((err) => {
  console.error('❌ MongoDB connection error:', err);
  process.exit(1);
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'Zurtex Litecoin Payment Gateway',
    timestamp: new Date().toISOString()
  });
});

// Monitoring status endpoint
app.get('/api/monitor/status', async (req, res) => {
  try {
    const Payment = require('./models/Payment');
    
    const [pending, confirming, completed, expired] = await Promise.all([
      Payment.countDocuments({ status: 'pending' }),
      Payment.countDocuments({ status: 'confirming' }),
      Payment.countDocuments({ status: 'completed' }),
      Payment.countDocuments({ status: 'expired' })
    ]);

    const activeMonitoring = await Payment.find({
      status: { $in: ['pending', 'confirming'] },
      expiresAt: { $gt: new Date() }
    }).select('orderId paymentAddress status createdAt expiresAt');

    res.json({
      status: 'active',
      monitorInterval: '10 seconds',
      statistics: {
        pending,
        confirming,
        completed,
        expired
      },
      activelyMonitoring: activeMonitoring.length,
      payments: activeMonitoring
    });
  } catch (error) {
    console.error('❌ Error getting monitor status:', error.message);
    res.status(500).json({ error: 'Failed to get monitor status' });
  }
});

// Routes
app.use('/api/payment', paymentRoutes);
app.use('/api/webhook', webhookRoutes);

// Error handling middleware
app.use((err, req, res, _next) => {
  console.error('❌ Error:', err);
  res.status(500).json({ 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Litecoin Payment Gateway running on port ${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`💰 Merchant Address: ${process.env.MERCHANT_LTC_ADDRESS}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('👋 SIGTERM received, closing server...');
  mongoose.connection.close(() => {
    process.exit(0);
  });
});
