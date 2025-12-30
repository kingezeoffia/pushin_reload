# PUSHIN' Stripe Backend API

Backend API for Stripe Web Checkout integration with the PUSHIN' Flutter app.

## Quick Deploy to Railway (5 minutes)

### 1. Install Railway CLI

```bash
# macOS
brew install railway

# Or use npm
npm install -g @railway/cli
```

### 2. Login to Railway

```bash
railway login
```

This opens your browser for authentication.

### 3. Deploy from this directory

```bash
cd backend
railway init
railway up
```

Railway will:
- Create a new project
- Deploy your code
- Assign a public URL (e.g., `pushin-stripe-api-production.up.railway.app`)

### 4. Set Environment Variables

Go to Railway Dashboard or use CLI:

```bash
railway variables set STRIPE_SECRET_KEY=sk_test_YOUR_KEY
railway variables set STRIPE_PRICE_STANDARD=price_YOUR_STANDARD_ID
railway variables set STRIPE_PRICE_ADVANCED=price_YOUR_ADVANCED_ID
railway variables set STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET
railway variables set NODE_ENV=production
```

### 5. Get Your API URL

```bash
railway domain
```

Copy this URL - you'll use it in your Flutter app!

Example: `https://pushin-stripe-api-production.up.railway.app`

---

## Alternative: Deploy to Vercel (4 minutes)

### 1. Install Vercel CLI

```bash
npm install -g vercel
```

### 2. Deploy

```bash
cd backend
vercel
```

Follow prompts:
- Link to existing project or create new: **Create new**
- Project name: **pushin-stripe-api**
- Directory: **.**
- Override settings: **No**

### 3. Set Environment Variables

```bash
vercel env add STRIPE_SECRET_KEY
# Paste your key when prompted

vercel env add STRIPE_PRICE_STANDARD
# Paste your price ID

vercel env add STRIPE_PRICE_ADVANCED
# Paste your price ID

vercel env add STRIPE_WEBHOOK_SECRET
# Paste your webhook secret
```

### 4. Deploy to Production

```bash
vercel --prod
```

---

## Testing Your Deployed API

### 1. Health Check

```bash
curl https://YOUR_API_URL.up.railway.app/api/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2024-12-15T...",
  "environment": "production"
}
```

### 2. Test Create Checkout Session

```bash
curl -X POST https://YOUR_API_URL/api/stripe/create-checkout-session \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test_user",
    "planId": "standard",
    "userEmail": "test@example.com",
    "successUrl": "pushinapp://payment-success?session_id={CHECKOUT_SESSION_ID}",
    "cancelUrl": "pushinapp://payment-cancel"
  }'
```

Expected response:
```json
{
  "checkoutUrl": "https://checkout.stripe.com/c/pay/cs_test_...",
  "sessionId": "cs_test_..."
}
```

---

## Configure Stripe Webhook

### 1. Get Your Webhook URL

Your webhook endpoint is:
```
https://YOUR_API_URL/api/stripe/webhook
```

### 2. Add Webhook in Stripe Dashboard

1. Go to: https://dashboard.stripe.com/test/webhooks
2. Click **"Add endpoint"**
3. Enter endpoint URL: `https://YOUR_API_URL/api/stripe/webhook`
4. Select events to listen to:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
5. Click **"Add endpoint"**
6. Copy the **Signing secret** (`whsec_...`)

### 3. Update Environment Variable

Railway:
```bash
railway variables set STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET
```

Vercel:
```bash
vercel env add STRIPE_WEBHOOK_SECRET
# Paste your webhook secret
vercel --prod
```

### 4. Test Webhook (using Stripe CLI)

```bash
# Install Stripe CLI
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks to your deployed API
stripe listen --forward-to https://YOUR_API_URL/api/stripe/webhook

# In another terminal, trigger a test event
stripe trigger checkout.session.completed
```

---

## API Endpoints

### Health Check
```
GET /api/health
```

### Create Checkout Session
```
POST /api/stripe/create-checkout-session
Content-Type: application/json

{
  "userId": "string",
  "planId": "standard|advanced",
  "userEmail": "string",
  "successUrl": "string",
  "cancelUrl": "string"
}
```

### Verify Payment
```
POST /api/stripe/verify-payment
Content-Type: application/json

{
  "sessionId": "string",
  "userId": "string"
}
```

### Check Subscription Status
```
GET /api/stripe/subscription-status?userId=string
```

### Cancel Subscription
```
POST /api/stripe/cancel-subscription
Content-Type: application/json

{
  "userId": "string",
  "subscriptionId": "string"
}
```

### Webhook
```
POST /api/stripe/webhook
(Stripe signature in headers)
```

---

## Update Flutter App

In your Flutter app, update the API URL:

```dart
// lib/services/StripeCheckoutService.dart
StripeCheckoutService({
  this.baseUrl = 'https://YOUR_API_URL.up.railway.app/api',
});
```

Or pass it when initializing:

```dart
final stripeService = StripeCheckoutService(
  baseUrl: 'https://YOUR_API_URL.up.railway.app/api',
);
```

---

## Environment Variables Summary

| Variable | Where to Get It | Example |
|----------|----------------|---------|
| `STRIPE_SECRET_KEY` | Stripe Dashboard → Developers → API keys | `sk_test_...` |
| `STRIPE_PRICE_STANDARD` | Stripe Dashboard → Products → Standard Plan | `price_...` |
| `STRIPE_PRICE_ADVANCED` | Stripe Dashboard → Products → Advanced Plan | `price_...` |
| `STRIPE_WEBHOOK_SECRET` | Stripe Dashboard → Webhooks → Signing secret | `whsec_...` |

---

## Monitoring & Logs

### Railway Logs

```bash
railway logs
```

### Vercel Logs

Go to: https://vercel.com/dashboard → Your Project → Logs

---

## Production Checklist

- [ ] Backend deployed with HTTPS
- [ ] All environment variables set
- [ ] Health check endpoint responds
- [ ] Webhook configured in Stripe Dashboard
- [ ] Webhook secret set in environment variables
- [ ] Test checkout flow works end-to-end
- [ ] Logs show successful webhook events
- [ ] Flutter app points to production API URL

---

## Troubleshooting

### Issue: "Webhook signature verification failed"

**Solution**: Double-check `STRIPE_WEBHOOK_SECRET` matches the signing secret from Stripe Dashboard.

### Issue: "Invalid plan ID"

**Solution**: Verify `STRIPE_PRICE_STANDARD` and `STRIPE_PRICE_ADVANCED` are set correctly.

### Issue: API returns 500 errors

**Solution**: Check Railway/Vercel logs:
```bash
railway logs  # or check Vercel dashboard
```

### Issue: CORS errors from Flutter app

**Solution**: Update CORS origin in `server.js` if you restricted it:
```javascript
app.use(cors({
  origin: ['https://pushinapp.com', 'http://localhost'],
  methods: ['GET', 'POST'],
}));
```

---

**Your backend is ready! 🚀**



































