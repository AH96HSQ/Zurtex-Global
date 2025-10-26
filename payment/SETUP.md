# Zurtex Litecoin Payment Gateway - Server Setup Guide

## Quick Setup Instructions

### Prerequisites

- Node.js 16+ installed
- MongoDB installed and running
- Litecoin wallet address
- Server with public IP (for webhooks)

### Step-by-Step Setup

#### 1. Install Dependencies

```bash
cd payment
npm install
```

#### 2. Configure Environment

```bash
cp .env.example .env
nano .env
```

**Edit these required values:**

```env
# Your server configuration
PORT=5006
NODE_ENV=production

# MongoDB - install locally or use cloud service
MONGODB_URI=mongodb://localhost:27017/zurtex_payment

# Get your Litecoin address from any wallet
MERCHANT_LTC_ADDRESS=LYourLitecoinAddressHere123

# Get free API token from https://accounts.blockcypher.com/
BLOCKCYPHER_TOKEN=your_token_here

# Your main Zurtex backend URL
MAIN_BACKEND_URL=http://your-backend-url/api/payment-callback

# Pricing (in USD)
PRICE_30_DAYS=5.99
PRICE_90_DAYS=15.99
PRICE_180_DAYS=28.99

# Payment settings
PAYMENT_TIMEOUT_MINUTES=30
REQUIRED_CONFIRMATIONS=2
```

#### 3. Start MongoDB

**On Ubuntu/Debian:**
```bash
sudo systemctl start mongodb
sudo systemctl enable mongodb
```

**Using Docker:**
```bash
docker run -d -p 27017:27017 --name mongodb --restart unless-stopped mongo:latest
```

#### 4. Install PM2 (Process Manager)

```bash
npm install -g pm2
```

#### 5. Start Payment Gateway

```bash
pm2 start server.js --name zurtex-payment
pm2 save
pm2 startup
```

#### 6. Configure Firewall

```bash
# Allow port 5006
sudo ufw allow 5006/tcp

# Check status
sudo ufw status
```

#### 7. Set Up Webhook (Optional but Recommended)

For instant payment notifications, configure webhook URL in your server:

```bash
# Your webhook URL will be:
https://your-domain.com:5006/api/webhook/blockcypher
```

**Using nginx as reverse proxy:**

```nginx
server {
    listen 443 ssl;
    server_name payment.your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:5006;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

#### 8. Verify Installation

```bash
# Check if server is running
curl http://localhost:5006/health

# Check PM2 status
pm2 status

# View logs
pm2 logs zurtex-payment
```

### Getting API Credentials

#### Blockcypher Token (Free)

1. Go to https://accounts.blockcypher.com/
2. Sign up for free account
3. Copy your API token
4. Free tier includes:
   - 200 requests per hour
   - 3 requests per second
   - Sufficient for small to medium traffic

#### Litecoin Address

**Option 1: Desktop Wallet**
- Download Litecoin Core
- Generate new address
- Save backup

**Option 2: Hardware Wallet (Recommended)**
- Use Ledger or Trezor
- Generate Litecoin address
- More secure for merchant use

**Option 3: Exchange Wallet**
- Create account on exchange
- Get your LTC deposit address
- Note: Less secure, use only for testing

### Testing the Gateway

#### 1. Create Test Payment

```bash
curl -X POST http://localhost:5006/api/payment/create \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "planType": "30_days"
  }'
```

#### 2. Check Payment Status

```bash
curl http://localhost:5006/api/payment/status/ORDER_ID
```

#### 3. Manual Confirmation (Testing)

```bash
curl -X POST http://localhost:5006/api/webhook/manual-confirm \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "YOUR_ORDER_ID",
    "txHash": "test_tx_hash"
  }'
```

### Integrating with Main Backend

Add this endpoint to your main Zurtex backend (ZurtexGlobalBackend.js):

```javascript
// Payment callback endpoint
app.post('/api/payment-callback', async (req, res) => {
  try {
    const { email, orderId, planType, amountLTC, txHash, completedAt } = req.body;

    console.log('💰 Payment received:', { email, planType, orderId });

    // Find or create device/user
    const device = await Device.findOne({ email });
    
    if (!device) {
      return res.status(404).json({ error: 'Device not found' });
    }

    // Calculate expiration based on plan
    const daysToAdd = parseInt(planType.split('_')[0]);
    const currentExpiration = device.expirationDate || new Date();
    const newExpiration = new Date(currentExpiration);
    newExpiration.setDate(newExpiration.getDate() + daysToAdd);

    // Update device subscription
    device.expirationDate = newExpiration;
    device.dataLimit = 1099511627776; // 1TB in bytes
    device.dataUsed = 0;
    
    await device.save();

    // Log the payment
    await Log.create({
      email,
      action: 'payment_received',
      details: { orderId, planType, amountLTC, txHash },
      timestamp: new Date(),
    });

    console.log('✅ Subscription activated:', {
      email,
      expiresAt: newExpiration,
      plan: planType,
    });

    res.json({ 
      success: true, 
      message: 'Subscription activated',
      expiresAt: newExpiration,
    });

  } catch (error) {
    console.error('❌ Payment callback error:', error);
    res.status(500).json({ error: 'Failed to process payment' });
  }
});
```

### Monitoring & Maintenance

#### Check Logs

```bash
# Real-time logs
pm2 logs zurtex-payment --lines 100

# Error logs only
pm2 logs zurtex-payment --err

# Save logs to file
pm2 logs zurtex-payment >> payment.log
```

#### Monitor Performance

```bash
# Show PM2 dashboard
pm2 monit

# Show detailed info
pm2 show zurtex-payment
```

#### Restart Service

```bash
# Restart
pm2 restart zurtex-payment

# Reload (zero-downtime)
pm2 reload zurtex-payment
```

#### Update Code

```bash
cd payment
git pull
npm install
pm2 restart zurtex-payment
```

### Security Best Practices

1. **SSL/TLS**: Always use HTTPS in production
2. **Firewall**: Only open required ports
3. **API Keys**: Never commit `.env` to git
4. **Rate Limiting**: Implement rate limiting on API endpoints
5. **Webhook Verification**: Verify webhook signatures in production
6. **Regular Updates**: Keep Node.js and packages updated
7. **Monitoring**: Set up alerts for failed payments
8. **Backups**: Regularly backup MongoDB

### Troubleshooting

#### MongoDB Connection Failed

```bash
# Check if MongoDB is running
sudo systemctl status mongodb

# Check connection
mongo --eval "db.adminCommand('ping')"

# Restart MongoDB
sudo systemctl restart mongodb
```

#### Port Already in Use

```bash
# Find process using port 5006
sudo lsof -i :5006

# Kill process
sudo kill -9 PID
```

#### Payment Not Detected

1. Check Litecoin network status
2. Verify transaction on block explorer
3. Check API rate limits
4. Review payment monitor logs

#### High Memory Usage

```bash
# Check memory
pm2 show zurtex-payment

# Restart if needed
pm2 restart zurtex-payment

# Set memory limit
pm2 start server.js --name zurtex-payment --max-memory-restart 500M
```

### Production Deployment Checklist

- [ ] Node.js 16+ installed
- [ ] MongoDB installed and secured
- [ ] PM2 installed and configured
- [ ] Firewall configured
- [ ] SSL certificate installed
- [ ] Nginx reverse proxy configured
- [ ] Environment variables set
- [ ] Blockcypher API token obtained
- [ ] Litecoin merchant address configured
- [ ] Webhook URL configured
- [ ] Main backend callback endpoint implemented
- [ ] Monitoring and alerts set up
- [ ] Regular backups scheduled
- [ ] Log rotation configured

### Support

If you encounter issues:

1. Check logs: `pm2 logs zurtex-payment`
2. Verify configuration: `cat .env`
3. Test API: `curl http://localhost:5006/health`
4. Review MongoDB: `mongo zurtex_payment --eval "db.payments.find().limit(5)"`

For additional help, contact the development team.
