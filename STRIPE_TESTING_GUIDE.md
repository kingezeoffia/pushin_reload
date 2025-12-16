# 🧪 STRIPE TESTING GUIDE - Your Keys Ready!

**Your Stripe test account is set up!** Here's how to test your complete payment flow.

## 📋 Your Test Keys (Already Configured)

- ✅ **Publishable Key**: `pk_test_YOUR_PUBLISHABLE_KEY` (get from Stripe Dashboard → Developers → API keys)
- ✅ **Secret Key**: `sk_test_YOUR_SECRET_KEY` (get from Stripe Dashboard → Developers → API keys)

## 🚀 Step 1: Create Test Products in Stripe Dashboard

**Go to: https://dashboard.stripe.com/test/products**

### Create "Standard Plan" (€9.99/month)

1. Click **"Create product"**
2. **Name**: `Standard Plan`
3. **Description**: `Ad-free, 3 blocked apps, 3 workouts`
4. **Price**: `€9.99` per month
5. **Currency**: EUR (Euro)
6. **Billing period**: Monthly
7. **API ID**: Keep default or set to `standard_monthly`
8. Click **"Create product"**

**Copy the Price ID** (starts with `price_test_`): `price_1SeeJz4DoaIPNX76QvqX2weX`

### Create "Advanced Plan" (€14.99/month)

1. Click **"Create product"** again
2. **Name**: `Advanced Plan`
3. **Description**: `Ad-free, 5 blocked apps, 5 workouts, unlimited unlock time`
4. **Price**: `€14.99` per month
5. **Currency**: EUR (Euro)
6. **Billing period**: Monthly
7. **API ID**: Keep default or set to `advanced_monthly`
8. Click **"Create product"**

**Copy the Price ID** (starts with `price_test_`): `price_1SeeLG4DoaIPNX76EYQHzfpp`

---

## 🚀 Step 2: Deploy Backend to Railway

```bash
# 1. Install Railway CLI (if not installed)
brew install railway

# 2. Login to Railway
railway login

# 3. Go to backend directory
cd /Users/kingezeoffia/pushin_reload/backend

# 4. Link to your existing PUSHIN project
railway link
# Select: "PUSHIN" from your projects

# 5. Deploy backend
railway up

# 6. Set environment variables with YOUR price IDs:
railway variables --set "NODE_ENV=test"
railway variables --set "STRIPE_TEST_SECRET_KEY=sk_test_YOUR_SECRET_KEY"
railway variables --set "STRIPE_TEST_PRICE_STANDARD=price_test_YOUR_STANDARD_PRICE_ID"
railway variables --set "STRIPE_TEST_PRICE_ADVANCED=price_test_YOUR_ADVANCED_PRICE_ID"

# 7. Get your backend URL
railway domain
# Copy this URL: https://your-project-name.up.railway.app
```

---

## 🚀 Step 3: Set Up Webhooks (Optional but Recommended)

**Go to: https://dashboard.stripe.com/test/webhooks**

1. Click **"Add endpoint"**
2. **Endpoint URL**: `https://your-railway-url.up.railway.app/api/stripe/webhook`
3. **Events to send**:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
4. Click **"Add endpoint"**
5. **Copy the webhook secret** (starts with `whsec_test_`)

```bash
# Set webhook secret in Railway
railway variables set STRIPE_TEST_WEBHOOK_SECRET=whsec_test_YOUR_WEBHOOK_SECRET
```

---

## 🚀 Step 4: Update Flutter App Configuration

**Update your `StripeCheckoutService` initialization:**

```dart
// In your PaywallScreen or wherever you initialize payments:
final stripeService = StripeCheckoutService(
  baseUrl: 'https://your-railway-url.up.railway.app/api',
  isTestMode: true, // This will use your test keys
);
```

---

## 🚀 Step 5: Test the Payment Flow

### **Test Card Numbers** (No real money charged!)

- ✅ **Success**: `4242 4242 4242 4242`
- ❌ **Decline**: `4000 0000 0000 0002`
- ✅ **3D Secure**: `4000 0025 0000 3155`

**Any expiry date in future, any CVC**

### **Testing Steps:**

```dart
// 1. Launch checkout
await stripeService.launchCheckout(
  userId: 'test_user_123',
  planId: 'standard', // or 'advanced'
  userEmail: 'test@example.com',
);

// 2. Browser opens with Stripe Checkout
// 3. Use test card: 4242 4242 4242 4242
// 4. Complete payment

// 5. App receives deep link and verifies
final status = await stripeService.verifyPayment(
  sessionId: 'cs_test_...', // From deep link
  userId: 'test_user_123',
);

// 6. Check status
print('Plan: ${status?.planId}'); // Should be 'standard' or 'advanced'
```

---

## 🐛 Troubleshooting

### **Backend Not Working?**
```bash
# Check Railway logs
railway logs

# Test health endpoint
curl https://your-railway-url.up.railway.app/api/health
```

### **Flutter App Issues?**
```bash
# Check console for errors
flutter run --verbose

# Test with mock mode first
flutter run --dart-define=PAYMENT_MODE=mock
```

### **Stripe Dashboard Not Showing Payments?**
- Make sure you're in **Test Mode** (not Live Mode)
- Check: https://dashboard.stripe.com/test/payments

---

## ✅ Expected Results

After successful test payment:

1. ✅ **Stripe Dashboard**: Shows completed payment
2. ✅ **Backend**: Receives webhook events
3. ✅ **Flutter App**: Subscription status updated
4. ✅ **Local Storage**: Subscription cached locally
5. ✅ **Deep Link**: App returns from browser

---

## 🎯 Your Test Checklist

- [ ] Created Standard Plan (€9.99/month) in Stripe
- [ ] Created Advanced Plan (€14.99/month) in Stripe
- [ ] Deployed backend to Railway
- [ ] Set environment variables with your keys
- [ ] Updated Flutter app with backend URL
- [ ] Set up webhooks (optional)
- [ ] Tested payment flow with test card
- [ ] Verified subscription status in app

---

## 🚨 Important Notes

- **Test Mode Only**: No real money is charged
- **Separate Keys**: Never use test keys in production
- **Webhook Testing**: Use Stripe CLI for local webhook testing
- **Rate Limits**: Stripe has test mode rate limits

**Ready to test?** Start with Step 1 - create your test products! 🚀
