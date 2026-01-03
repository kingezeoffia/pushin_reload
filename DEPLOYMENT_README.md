# 🚀 PUSHIN' Backend Deployment Guide

This guide covers deploying the PUSHIN' backend to Railway with Stripe integration.

## Prerequisites

- Railway account: https://railway.app
- Railway CLI: `brew install railway` or `npm install -g @railway/cli`
- Stripe account with test products created

## Quick Deploy (5 minutes)

### 1. Deploy Backend

```bash
# 1. Deploy backend
./deploy-backend.sh

# 2. Configure environment variables
./setup-env-vars.sh

# 3. Test deployment
./test-deployment.sh

# 4. Update Flutter app
./update-flutter-config.sh
```

That's it! Your backend will be live and your Flutter app configured.

## Detailed Steps

### 1. Deploy Backend

```bash
./deploy-backend.sh
```

Creates Railway project and deploys Node.js backend.

### 2. Configure Environment Variables

```bash
./setup-env-vars.sh
```

Interactive setup for:
- NODE_ENV=production
- Stripe secret key
- Price IDs for Standard/Advanced plans
- Optional webhook secret

### 3. Test Deployment

```bash
./test-deployment.sh
```

Comprehensive testing:
- Health check endpoint
- Environment variables verification
- Stripe integration test (creates test checkout session)

### 4. Update Flutter App

```bash
./update-flutter-config.sh
```

Automatically:
- Gets your Railway domain
- Updates `StripeCheckoutService.dart`
- Tests backend connection

Manual alternative:

```dart
// lib/services/StripeCheckoutService.dart
StripeCheckoutService({
  this.baseUrl = 'https://your-railway-domain.up.railway.app/api',
});
```

## Optional: Add PostgreSQL Database

For production persistence (MVP works without it):

```bash
./setup-postgres.sh
```

This adds a PostgreSQL database to your Railway project. You'll need to update `server.js` to use it instead of the in-memory Map.

## Manual Commands (Alternative)

If you prefer manual control:

```bash
# Deploy backend
cd backend
railway init --name pushin-stripe-api-production
railway up

# Set variables manually
railway variables set NODE_ENV=production
railway variables set STRIPE_SECRET_KEY=sk_test_...
railway variables set STRIPE_PRICE_STANDARD=price_test_...
railway variables set STRIPE_PRICE_ADVANCED=price_test_...
railway variables set STRIPE_WEBHOOK_SECRET=whsec_test_...

# Get domain
railway domain
```

## Flutter Web Hosting (Optional)

For web testing:

```bash
# Build web app
flutter build web --release

# Deploy to Railway (separate project)
cd web-build-directory
railway init --name pushin-web-test
railway up
```

## Architecture

- **Backend**: Node.js + Express + Stripe
- **Database**: In-memory Map (MVP) → PostgreSQL (production)
- **APIs**: REST endpoints for Stripe checkout
- **Security**: CORS restricted, environment variables
- **Monitoring**: Railway logs, health checks

## Environment Variables

| Variable | Required | Example |
|----------|----------|---------|
| NODE_ENV | Yes | production |
| STRIPE_SECRET_KEY | Yes | sk_test_... |
| STRIPE_PRICE_STANDARD | Yes | price_test_... |
| STRIPE_PRICE_ADVANCED | Yes | price_test_... |
| STRIPE_WEBHOOK_SECRET | No | whsec_test_... |
| DATABASE_URL | Optional | postgresql://... |

## Troubleshooting

### Backend won't start
```bash
railway logs
```

### Stripe errors
- Check environment variables: `railway variables`
- Verify Stripe dashboard keys
- Test with Stripe CLI: `stripe listen --forward-to your-api-url/api/stripe/webhook`

### CORS issues
- Update `server.js` allowedOrigins array with your domains
- For development, localhost origins are already included

### Database connection
- If using PostgreSQL: `railway variables get DATABASE_URL`
- Update server.js to use `pg` library instead of Map

## Production Checklist

- [ ] Backend deployed and healthy
- [ ] All Stripe environment variables set
- [ ] Webhook configured in Stripe dashboard
- [ ] Flutter app updated with production API URL
- [ ] Test checkout flow end-to-end
- [ ] CORS allows your app domains
- [ ] Database added if persistence needed

---

**Ready for testing! 🎉**


















