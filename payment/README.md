# Zurtex Litecoin Payment Gateway

Lightweight, self-hosted Litecoin payment gateway for Zurtex VPN subscriptions.

## Features

- 💰 Litecoin (LTC) payment processing
- 🔄 Real-time payment monitoring (no full node required)
- 📊 MongoDB for payment tracking
- 🔔 Webhook support for instant notifications
- 📱 QR code generation for easy payments
- ⏰ Automatic payment expiration
- 🔗 Callback integration with main backend
- 📈 Multiple subscription plans (30/90/180 days)

## Architecture

This payment gateway uses the **Blockcypher API** to monitor Litecoin transactions without running a full node, making it extremely lightweight and easy to deploy.

### How it works:

1. User selects a subscription plan
2. System generates payment order with unique ID
3. User sends LTC to merchant address
4. System monitors address for incoming transactions
5. Once confirmed, system notifies main backend
6. Main backend activates user's subscription

## Installation

### 1. Clone and install dependencies

```bash
cd payment
npm install
```

### 2. Configure environment variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
nano .env
```

**Required configurations:**

- `MERCHANT_LTC_ADDRESS`: Your Litecoin receiving address
- `MONGODB_URI`: MongoDB connection string
- `BLOCKCYPHER_TOKEN`: Get free token at https://accounts.blockcypher.com/
- `MAIN_BACKEND_URL`: Your Zurtex backend callback URL

### 3. Start MongoDB

Make sure MongoDB is running:

```bash
# Linux/Mac
sudo systemctl start mongodb

# Or using Docker
docker run -d -p 27017:27017 --name mongodb mongo:latest
```

### 4. Run the server

```bash
# Production
npm start

# Development (with auto-reload)
npm run dev
```

Server will start on port **5006** by default.

## API Endpoints

### Payment Endpoints

#### Create Payment Order
```http
POST /api/payment/create
Content-Type: application/json

{
  "email": "user@example.com",
  "planType": "30_days"
}

Response:
{
  "success": true,
  "orderId": "uuid",
  "paymentAddress": "ltc1...",
  "amount": "0.06789",
  "amountUSD": 5.99,
  "planType": "30_days",
  "expiresAt": "2025-10-20T12:00:00.000Z",
  "qrCode": "data:image/png;base64,...",
  "ltcPriceUSD": "88.25"
}
```

#### Check Payment Status
```http
GET /api/payment/status/:orderId

Response:
{
  "orderId": "uuid",
  "status": "pending|confirming|completed|expired",
  "amount": "0.06789",
  "amountUSD": 5.99,
  "paymentAddress": "ltc1...",
  "txHash": "abc123...",
  "confirmations": 2,
  "amountReceived": 0.06789,
  "expiresAt": "2025-10-20T12:00:00.000Z",
  "paidAt": "2025-10-20T11:30:00.000Z",
  "completedAt": "2025-10-20T11:45:00.000Z"
}
```

#### Get User Payment History
```http
GET /api/payment/user/:email

Response:
{
  "success": true,
  "payments": [...]
}
```

#### Get Available Plans
```http
GET /api/payment/plans

Response:
{
  "success": true,
  "ltcPriceUSD": "88.25",
  "plans": [
    {
      "type": "30_days",
      "priceUSD": 5.99,
      "priceLTC": "0.06789",
      "days": 30
    },
    ...
  ]
}
```

### Webhook Endpoints

#### Blockcypher Webhook
```http
POST /api/webhook/blockcypher
```

#### Manual Confirmation (Testing/Admin)
```http
POST /api/webhook/manual-confirm
Content-Type: application/json

{
  "orderId": "uuid",
  "txHash": "abc123..."
}
```

### Health Check
```http
GET /health
```

## Payment Flow

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Flutter   │         │   Payment    │         │   Main      │
│     App     │────────▶│   Gateway    │────────▶│   Backend   │
└─────────────┘         └──────────────┘         └─────────────┘
      │                        │                         │
      │ 1. Create Payment      │                         │
      │───────────────────────▶│                         │
      │                        │                         │
      │ 2. Return Address +    │                         │
      │    QR Code             │                         │
      │◀───────────────────────│                         │
      │                        │                         │
      │ 3. User Sends LTC      │                         │
      │        to Address      │                         │
      │                        │                         │
      │                        │ 4. Monitor TX           │
      │                        │    (Blockcypher)        │
      │                        │                         │
      │ 5. Poll Status         │                         │
      │───────────────────────▶│                         │
      │                        │                         │
      │ 6. Status: confirming  │                         │
      │◀───────────────────────│                         │
      │                        │                         │
      │                        │ 7. TX Confirmed         │
      │                        │    (2+ confirmations)   │
      │                        │                         │
      │                        │ 8. Notify Completion    │
      │                        │────────────────────────▶│
      │                        │                         │
      │                        │ 9. Activate Sub         │
      │                        │◀────────────────────────│
      │                        │                         │
      │ 10. Status: completed  │                         │
      │◀───────────────────────│                         │
```

## Monitoring

The system runs a background monitor that:

- Checks pending payments every **60 seconds**
- Verifies transaction confirmations
- Marks expired payments automatically
- Notifies main backend when payments complete

Required confirmations: **2** (configurable via `REQUIRED_CONFIRMATIONS`)

## Security Considerations

1. **API Keys**: Keep your Blockcypher token secure
2. **HTTPS**: Use HTTPS in production for webhook callbacks
3. **Rate Limits**: Blockcypher free tier has rate limits (200 req/hour)
4. **Unique Addresses**: Current implementation uses single merchant address - consider HD wallet for unique addresses per payment
5. **Webhook Verification**: Add webhook signature verification in production

## Blockcypher Setup

1. Sign up at https://accounts.blockcypher.com/
2. Get your API token (free tier: 200 requests/hour, 3 requests/second)
3. Add token to `.env` file
4. Optional: Set up webhook URL for instant notifications

## Upgrading to HD Wallet (Future)

For production use, consider implementing HD wallet derivation to generate unique addresses per payment:

1. Use libraries like `bitcoinjs-lib` or `bip32`
2. Generate new address for each payment
3. Derive addresses from master public key
4. Track used addresses in database

This improves privacy and makes payment reconciliation easier.

## Troubleshooting

### Payment not detected
- Check Litecoin network status
- Verify transaction was sent to correct address
- Check minimum confirmations requirement
- Review Blockcypher API rate limits

### Webhook not working
- Ensure webhook URL is publicly accessible
- Check firewall/port forwarding
- Verify HTTPS certificate if using HTTPS
- Test with ngrok for local development

### MongoDB connection issues
- Verify MongoDB is running
- Check connection string format
- Ensure network access to MongoDB server

## Testing

### Local Testing with Testnet

1. Switch to Litecoin testnet in `litecoin.js`:
```javascript
const url = `https://api.blockcypher.com/v1/ltc/test3/txs/${txHash}`;
```

2. Get testnet LTC from faucets:
   - https://testnet.help/en/ltcfaucet/testnet
   - https://tltc.bitaps.com/

3. Use testnet addresses for testing

### Manual Payment Confirmation

For testing purposes, you can manually confirm payments:

```bash
curl -X POST http://localhost:5006/api/webhook/manual-confirm \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "your-order-id",
    "txHash": "fake-tx-hash-for-testing"
  }'
```

## Maintenance

### Database Cleanup

Regularly clean up old expired payments:

```javascript
// Run this periodically (e.g., daily cron job)
db.payments.deleteMany({
  status: 'expired',
  createdAt: { $lt: new Date(Date.now() - 30*24*60*60*1000) } // 30 days old
})
```

### Monitoring Logs

Monitor logs for issues:

```bash
# Follow logs in real-time
npm start | tee -a payment-gateway.log

# Search for errors
grep "❌" payment-gateway.log

# Check payment confirmations
grep "✅ Payment completed" payment-gateway.log
```

## Sweep Management

The payment system uses HD wallet derivation, generating a unique address for each payment. Once a payment is completed, funds need to be swept to the merchant wallet.

### Check Sweep Status

View which payments have been swept and which haven't:

```bash
node check-sweep-status.js
```

### One-Time Migration

If you have existing completed payments, mark already-swept addresses:

```bash
node migrate-swept-payments.js
```

This script:
- Checks blockchain balance for each completed payment
- Marks addresses with 0 balance as `swept: true`
- Uses 2-second delays to respect API rate limits
- Only needs to be run once

### Regular Sweeps

Sweep all funds from completed payments to merchant wallet:

```bash
# Preview sweep (recommended first)
node sweep-all.js --dry-run

# Execute sweep
node sweep-all.js --execute
```

The sweep script:
- ✅ Only processes payments not yet marked as swept
- ✅ Respects BlockCypher rate limits (2 seconds between requests)
- ✅ Uses retry logic with exponential backoff
- ✅ Automatically marks swept addresses in database
- ✅ Never tries to sweep the same address twice
- ✅ Tracks sweep transaction hash for audit trail

**Recommended workflow:**
1. Run `check-sweep-status.js` to see pending sweeps
2. Run `sweep-all.js --dry-run` to preview
3. Run `sweep-all.js --execute` to sweep
4. Payments are marked as `swept: true` with timestamp and TX hash

**Rate Limit Safety:**
- BlockCypher free tier: 200 requests/hour
- Script uses 2-second delays between requests
- With 4 addresses, sweep takes ~30-40 seconds
- Well within rate limits

## License

Proprietary - Zurtex Global

## Support

For issues or questions, contact the Zurtex development team.
