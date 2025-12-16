# 🚀 Stripe Test Mode Setup (No Company Account Required!)

**You can continue developing immediately using Stripe's test mode!**

## 🎯 Why Test Mode?

- ✅ **No company account needed** - Works with any email
- ✅ **Real Stripe infrastructure** - Same code as production
- ✅ **Test payments** - Use fake card numbers
- ✅ **Full checkout flow** - Browser redirect, webhooks, etc.
- ✅ **Free forever** - No costs for development

## 📋 3 Setup Options (Choose One)

### Option 1: Real Stripe Test Account (Recommended)

**1. Create FREE test account:**
```bash
# Go to: https://dashboard.stripe.com/register
# Use any email (doesn't need to be business)
# Select "Test Mode" during signup
```

**2. Get your test keys:**
- Go to: https://dashboard.stripe.com/test/apikeys
- Copy your "Secret key" (starts with `sk_test_`)

**3. Create test products:**
```bash
# In Stripe Dashboard: https://dashboard.stripe.com/test/products
# Create "Standard Plan" - €9.99/month
# Create "Advanced Plan" - €14.99/month
# Copy the price IDs (start with `price_test_`)
```

**4. Set environment variables:**
```bash
cd backend
cp env.example .env

# Edit .env file:
NODE_ENV=test
STRIPE_TEST_SECRET_KEY=sk_test_YOUR_ACTUAL_TEST_KEY
STRIPE_TEST_PRICE_STANDARD=price_test_YOUR_STANDARD_PRICE_ID
STRIPE_TEST_PRICE_ADVANCED=price_test_YOUR_ADVANCED_PRICE_ID
```

### Option 2: Mock Simulation (Immediate Development)

**Use this if you want to code NOW without Stripe setup:**

```dart
// In your Flutter code, initialize service in test mode:
final stripeService = StripeCheckoutService(
  baseUrl: 'mock', // Special flag for simulation
  isTestMode: true,
);

// This will simulate payments without any backend
bool success = await stripeService.launchCheckout(
  userId: 'test_user',
  planId: 'standard',
  userEmail: 'test@example.com',
);
```

### Option 3: My Test Keys (Temporary)

**I can provide temporary test keys for immediate development:**

```
STRIPE_TEST_SECRET_KEY=sk_test_...temporary_key...
STRIPE_TEST_PRICE_STANDARD=price_test_...standard_id...
STRIPE_TEST_PRICE_ADVANCED=price_test_...advanced_id...
```

*Note: Replace with your own keys before production!*

## 🔧 Update Your Flutter Code

**Modify your service initialization:**

```dart
// In development/test mode:
final stripeService = StripeCheckoutService(
  baseUrl: 'https://your-test-backend.up.railway.app/api',
  isTestMode: true,
);

// In production:
final stripeService = StripeCheckoutService(
  baseUrl: 'https://api.pushinapp.com/api',
  isTestMode: false,
);
```

## 🧪 Test Payments

**Use these test card numbers in Stripe Checkout:**

- ✅ **Success**: `4242 4242 4242 4242`
- ❌ **Decline**: `4000 0000 0000 0002`
- ✅ **3D Secure**: `4000 0025 0000 3155`

Any expiry date in the future, any CVC.

## 📱 Test the Full Flow

```dart
// 1. Launch checkout
await stripeService.launchCheckout(
  userId: 'user123',
  planId: 'standard',
  userEmail: 'user@example.com',
);

// 2. In browser: Use test card 4242 4242 4242 4242

// 3. App receives deep link and verifies payment
final status = await stripeService.verifyPayment(
  sessionId: 'cs_test_...', // From deep link
  userId: 'user123',
);

// 4. Check status anytime
final currentStatus = await stripeService.getCachedSubscriptionStatus();
print('Plan: ${currentStatus?.planId}'); // 'standard'
```

## 🚀 Deploy Test Backend

```bash
cd backend

# Deploy to Railway
railway login
railway init
railway up

# Set test environment variables
railway variables set NODE_ENV=test
railway variables set STRIPE_TEST_SECRET_KEY=sk_test_YOUR_KEY
railway variables set STRIPE_TEST_PRICE_STANDARD=price_test_STANDARD_ID
railway variables set STRIPE_TEST_PRICE_ADVANCED=price_test_ADVANCED_ID

# Get your test API URL
railway domain
# Example: https://pushin-test.up.railway.app
```

## 🔄 Switch to Live Mode Later

**When you get your Estonian company:**

```bash
# 1. Create live Stripe account
# 2. Get live keys and price IDs
# 3. Update environment variables:
NODE_ENV=production
STRIPE_SECRET_KEY=sk_live_YOUR_LIVE_KEY
STRIPE_PRICE_STANDARD=price_YOUR_LIVE_STANDARD_ID
STRIPE_PRICE_ADVANCED=price_YOUR_LIVE_ADVANCED_ID

# 4. Update Flutter service:
final stripeService = StripeCheckoutService(
  baseUrl: 'https://api.pushinapp.com/api',
  isTestMode: false,
);
```

## 🎉 You're Ready!

**You can continue developing your payment flow immediately!**

- Build UI components
- Test user flows
- Implement premium features
- Deploy to app stores
- Collect feedback

**When your Estonian setup is ready, just switch the environment variables.**

---

*Questions? The integration is already complete - you just need test keys or simulation mode to continue!* 🚀
