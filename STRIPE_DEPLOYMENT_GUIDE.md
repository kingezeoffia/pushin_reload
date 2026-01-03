# 🚀 PUSHIN' Stripe Deployment & Configuration Guide

**Complete step-by-step guide to deploy and test your Stripe integration.**

---

## 📋 Prerequisites

- [ ] Stripe account created (https://stripe.com)
- [ ] Node.js installed (v18+)
- [ ] Flutter project with Stripe integration (already done!)
- [ ] iOS/Android device or simulator for testing

---

## Part 1: Create Stripe Products (10 minutes)

### Step 1: Login to Stripe Dashboard

Go to: https://dashboard.stripe.com

**Toggle to TEST MODE** (top-right corner - important!)

### Step 2: Create Standard Plan

1. Go to **Products** → **Add Product**
2. Fill in:
   - **Name**: `PUSHIN' Standard`
   - **Description**: `Standard subscription with 3 workouts and 3 hours daily usage`
   - **Pricing**:
     - **Price**: `9.99` EUR (or your currency)
     - **Billing period**: `Monthly`
     - **Recurring**: ✅ Yes
3. Click **Save product**
4. **COPY THE PRICE ID** (looks like `price_1234abcd`)

### Step 3: Create Advanced Plan

1. **Products** → **Add Product**
2. Fill in:
   - **Name**: `PUSHIN' Advanced`
   - **Description**: `Advanced subscription with 5 workouts and unlimited daily usage`
   - **Pricing**:
     - **Price**: `14.99` EUR
     - **Billing period**: `Monthly`
     - **Recurring**: ✅ Yes
3. Click **Save product**
4. **COPY THE PRICE ID** (looks like `price_5678efgh`)

### Step 4: Get Your API Keys

1. Go to **Developers** → **API keys**
2. Copy **Secret key** (starts with `sk_test_...`)

**Save these 3 values - you'll need them soon:**
```
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PRICE_STANDARD=price_...
STRIPE_PRICE_ADVANCED=price_...
```

---

## Part 2: Deploy Backend to Railway (15 minutes)

### Step 1: Install Railway CLI

**macOS:**
```bash
brew install railway
```

**Windows/Linux (via npm):**
```bash
npm install -g @railway/cli
```

### Step 2: Login to Railway

```bash
railway login
```

This opens your browser. Click **"Authorize"**.

### Step 3: Initialize and Deploy

```bash
cd /Users/kingezeoffia/pushin_reload/backend
railway init
```

Follow prompts:
- **Project name**: `pushin-stripe-api`
- **Environment**: `production`

Deploy:
```bash
railway up
```

Wait ~2 minutes for deployment to complete.

### Step 4: Set Environment Variables

**ONE BY ONE, run these commands** (replace with YOUR values):

```bash
railway variables set STRIPE_SECRET_KEY=sk_test_YOUR_KEY_HERE

railway variables set STRIPE_PRICE_STANDARD=price_YOUR_STANDARD_ID

railway variables set STRIPE_PRICE_ADVANCED=price_YOUR_ADVANCED_ID

railway variables set NODE_ENV=production
```

### Step 5: Assign a Public Domain

```bash
railway domain
```

Railway will generate a URL like:
```
pushin-stripe-api-production.up.railway.app
```

**SAVE THIS URL** - you'll use it in your Flutter app!

### Step 6: Test Your Deployed API

```bash
curl https://YOUR_RAILWAY_URL.up.railway.app/api/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2024-12-15T...",
  "environment": "production"
}
```

✅ **Your backend is live!**

---

## Part 3: Configure Stripe Webhook (10 minutes)

### Step 1: Get Webhook URL

Your webhook endpoint is:
```
https://YOUR_RAILWAY_URL.up.railway.app/api/stripe/webhook
```

### Step 2: Add Endpoint in Stripe Dashboard

1. Go to: https://dashboard.stripe.com/test/webhooks
2. Click **"+ Add endpoint"**
3. **Endpoint URL**: Paste your webhook URL
4. **Description**: `PUSHIN' Production Webhook`
5. **Events to send**:
   - Search and select these 6 events:
     - ✅ `checkout.session.completed`
     - ✅ `customer.subscription.created`
     - ✅ `customer.subscription.updated`
     - ✅ `customer.subscription.deleted`
     - ✅ `invoice.payment_succeeded`
     - ✅ `invoice.payment_failed`
6. Click **"Add endpoint"**

### Step 3: Get Webhook Signing Secret

On the webhook details page, you'll see:

**Signing secret**: `whsec_...`

Click **"Reveal"** and copy the full secret.

### Step 4: Add Webhook Secret to Railway

```bash
railway variables set STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET_HERE
```

### Step 5: Test Webhook (Optional but Recommended)

Install Stripe CLI:
```bash
brew install stripe/stripe-cli/stripe
```

Login:
```bash
stripe login
```

Trigger a test event:
```bash
stripe trigger checkout.session.completed --forward-to https://YOUR_RAILWAY_URL/api/stripe/webhook
```

Check Railway logs:
```bash
railway logs
```

You should see: `✅ Webhook signature verified: checkout.session.completed`

---

## Part 4: Configure Deep Links (15 minutes)

### iOS Configuration

**File**: `ios/Runner/Info.plist`

Add this inside the `<dict>` tag (before the closing `</dict>`):

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>com.pushin.app</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>pushinapp</string>
    </array>
  </dict>
</array>
```

**Test iOS Deep Link:**

```bash
# Open your iOS Simulator first, then run:
xcrun simctl openurl booted "pushinapp://payment-success?session_id=cs_test_123"
```

Expected: App opens and deep link is detected.

### Android Configuration

**File**: `android/app/src/main/AndroidManifest.xml`

Find the `<activity android:name=".MainActivity">` section and add this intent filter inside it:

```xml
<!-- Add this INSIDE the MainActivity activity tag -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    
    <!-- Deep link scheme -->
    <data
        android:scheme="pushinapp"
        android:host="payment-success" />
    <data
        android:scheme="pushinapp"
        android:host="payment-cancel" />
</intent-filter>
```

**Test Android Deep Link:**

```bash
# With Android emulator or device connected:
adb shell am start -W -a android.intent.action.VIEW \
  -d "pushinapp://payment-success?session_id=cs_test_123" \
  com.pushin.app
```

Expected: App opens and deep link is detected.

---

## Part 5: Update Flutter App Configuration (5 minutes)

### Update StripeCheckoutService

**File**: `lib/services/StripeCheckoutService.dart`

Change the default `baseUrl` to your Railway URL:

```dart
StripeCheckoutService({
  this.baseUrl = 'https://YOUR_RAILWAY_URL.up.railway.app/api',
});
```

**OR** pass it when initializing in `main.dart`:

```dart
final stripeService = StripeCheckoutService(
  baseUrl: 'https://YOUR_RAILWAY_URL.up.railway.app/api',
);
```

### Rebuild Your App

```bash
cd /Users/kingezeoffia/pushin_reload

# iOS
flutter run -d iPhone

# Android
flutter run -d android

# Chrome (for quick testing)
flutter run -d chrome
```

---

## Part 6: End-to-End Testing (20 minutes)

### Test 1: Health Check

**Goal**: Verify backend is accessible from Flutter app.

**Flutter Code** (add temporarily to test):
```dart
import 'package:http/http.dart' as http;

// In your widget
ElevatedButton(
  onPressed: () async {
    final response = await http.get(
      Uri.parse('https://YOUR_RAILWAY_URL/api/health'),
    );
    print('Health check: ${response.body}');
  },
  child: Text('Test Backend'),
)
```

**Expected**: Console prints `{"status":"ok",...}`

---

### Test 2: Launch Stripe Checkout

**Steps:**
1. Open your app
2. Navigate to Paywall screen
3. Tap **"Upgrade to Standard"** button

**Expected:**
1. Dialog appears: *"Complete Payment - You'll be redirected to Stripe..."*
2. Browser opens with Stripe Checkout page
3. Checkout page shows "PUSHIN' Standard - €9.99/month"

---

### Test 3: Complete Test Payment

**On Stripe Checkout page:**

**Test Card Details:**
```
Card Number: 4242 4242 4242 4242
Expiry: 12/34 (any future date)
CVC: 123 (any 3 digits)
Name: Test User
Email: test@example.com
Postal Code: 12345
```

Click **"Pay"**.

**Expected:**
1. Checkout shows success
2. Browser redirects to: `pushinapp://payment-success?session_id=cs_test_...`
3. Your app opens automatically
4. App verifies payment with backend
5. Premium features unlock!

**Check Railway logs:**
```bash
railway logs
```

You should see:
```
✅ Checkout session created: cs_test_...
Verifying payment: cs_test_...
✅ Payment verified and stored
```

---

### Test 4: Cancel Payment Flow

**Steps:**
1. Open Paywall again
2. Tap **"Upgrade"**
3. On Stripe Checkout, click **"← Back"** (top-left)

**Expected:**
1. Browser redirects to: `pushinapp://payment-cancel`
2. App opens
3. Message shows: *"Payment canceled"*
4. User remains on free plan

---

### Test 5: Verify Subscription Persists

**Steps:**
1. After successful payment, close your app completely
2. Reopen the app

**Expected:**
- Premium features still unlocked
- `StripeCheckoutService.getCachedSubscriptionStatus()` returns `isActive: true`
- App doesn't ask for payment again

---

### Test 6: Manual Deep Link Testing

**iOS Simulator:**
```bash
# Test success
xcrun simctl openurl booted "pushinapp://payment-success?session_id=cs_test_a1b2c3d4e5f6"

# Test cancel
xcrun simctl openurl booted "pushinapp://payment-cancel"
```

**Android Emulator:**
```bash
# Test success
adb shell am start -W -a android.intent.action.VIEW \
  -d "pushinapp://payment-success?session_id=cs_test_a1b2c3d4e5f6" \
  com.pushin.app

# Test cancel
adb shell am start -W -a android.intent.action.VIEW \
  -d "pushinapp://payment-cancel" \
  com.pushin.app
```

**Expected**: App opens and `DeepLinkHandler` logs deep link in console.

---

## Part 7: App Store / Play Store Compliance (2025)

### Apple App Store - External Payment Rules

**Requirements as of 2024/2025:**

1. **External payments ARE allowed** (with restrictions)
2. You must include **both options**: Stripe external + Apple IAP
3. You must show a **disclaimer** before redirecting to external checkout
4. Apple takes **12-27% commission** on external sales (depending on program)
5. Available **only in certain regions** (e.g., US, South Korea)

### Copy for Paywall Screen

**Add this text ABOVE your "Upgrade" buttons:**

```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.blue.shade900.withOpacity(0.3),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.blue.shade700),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '💳 Payment Options',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      SizedBox(height: 8),
      Text(
        'You can subscribe through our payment provider (Stripe) '
        'or via the App Store. Prices are the same for both options. '
        'External subscriptions are managed at stripe.com.',
        style: TextStyle(
          fontSize: 14,
          color: Colors.white70,
          height: 1.4,
        ),
      ),
    ],
  ),
)
```

### Copy for Upgrade Button Dialog

When user taps "Upgrade", show this dialog:

```dart
AlertDialog(
  title: Text('Complete Payment'),
  content: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'You will be redirected to a secure external checkout '
        'to complete your subscription.',
        style: TextStyle(fontSize: 16),
      ),
      SizedBox(height: 16),
      Text(
        'Important:',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text(
        '• Payment is processed by Stripe (our payment provider)\n'
        '• Return to the app when payment is complete\n'
        '• Your subscription will be managed at stripe.com',
        style: TextStyle(fontSize: 14, color: Colors.black87),
      ),
    ],
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text('Cancel'),
    ),
    ElevatedButton(
      onPressed: () {
        Navigator.pop(context);
        // Launch Stripe Checkout
        _launchStripeCheckout();
      },
      child: Text('Continue to Checkout'),
    ),
  ],
)
```

### App Store Review Notes

**When submitting to App Review, include this text:**

```
EXTERNAL PAYMENT LINK DISCLOSURE

This app uses external payment processing through Stripe for digital subscriptions 
in accordance with Apple's External Purchase Link Entitlement.

- Users are clearly informed before being redirected to external checkout
- Prices are identical to App Store In-App Purchase options
- External subscriptions are managed at stripe.com
- All required disclaimers are shown before checkout

Test Account:
- Email: test@pushinapp.com
- Password: TestPass123!

To test external payment:
1. Navigate to Settings > Upgrade
2. Select a plan
3. Use Stripe test card: 4242 4242 4242 4242
```

### Google Play Store - External Payment Rules

**Requirements as of 2024/2025:**

1. External payments **ARE allowed** for subscriptions
2. You must offer **Google Play Billing as an option** too
3. Google takes **4% commission** on external sales
4. Must show disclaimer before redirecting

**Google Play Disclaimer Text:**

```
'You can subscribe through Google Play Billing or our payment provider (Stripe). 
Prices are the same for both options.'
```

### Recommendation: Dual Payment Support

**Best Practice for App Store Approval:**

Implement BOTH payment methods:

```dart
// Paywall Screen
Column(
  children: [
    // Disclaimer (shown above)
    DisclaimerWidget(),
    
    SizedBox(height: 24),
    
    // Option 1: External Stripe Checkout
    PaymentOptionCard(
      title: 'Pay with Credit Card',
      subtitle: 'Managed at stripe.com',
      icon: Icons.credit_card,
      onTap: () => _launchStripeCheckout(),
    ),
    
    SizedBox(height: 16),
    
    // Option 2: Apple IAP
    PaymentOptionCard(
      title: 'Pay with App Store',
      subtitle: 'Managed in iOS Settings',
      icon: Icons.apple,
      onTap: () => _launchAppleIAP(),
    ),
  ],
)
```

**For MVP/Testing**: You can ship with Stripe-only and add IAP later.

---

## Part 8: Production Checklist

Before going live:

### Backend

- [ ] Backend deployed with HTTPS (Railway/Vercel)
- [ ] All environment variables configured
- [ ] Health endpoint returns 200 OK
- [ ] Webhook configured in Stripe Dashboard
- [ ] Webhook secret matches environment variable
- [ ] Test checkout creates session successfully
- [ ] Logs show successful webhook events

### Stripe Dashboard

- [ ] Products created (Standard €9.99, Advanced €14.99)
- [ ] Price IDs copied and set in environment
- [ ] Webhook endpoint added
- [ ] All 6 webhook events selected
- [ ] Tested in TEST MODE with test cards

### Flutter App

- [ ] Deep links configured (iOS + Android)
- [ ] `StripeCheckoutService` points to production URL
- [ ] Deep link handler initialized in `main.dart`
- [ ] Payment flow tested end-to-end
- [ ] Success flow unlocks premium features
- [ ] Cancel flow returns to app gracefully
- [ ] Subscription status cached locally
- [ ] Disclaimer text shown on Paywall

### Testing

- [ ] Test card payment completes successfully
- [ ] Deep links work on real iOS device
- [ ] Deep links work on real Android device
- [ ] Webhook events logged in Railway
- [ ] Premium features unlock after payment
- [ ] Subscription persists after app restart
- [ ] Cancel flow works correctly

### App Store / Play Store

- [ ] Disclaimer text added to Paywall
- [ ] Payment flow dialog shows external notice
- [ ] App Store Review notes prepared
- [ ] Screenshots show clear payment flow
- [ ] Privacy Policy mentions Stripe
- [ ] Terms of Service mention subscriptions

---

## Part 9: Troubleshooting

### Problem: "Could not launch Stripe Checkout URL"

**Cause**: `url_launcher` can't open browser.

**Solution**:
```bash
# Add to pubspec.yaml (already done)
flutter pub get

# For iOS, check Info.plist has LSApplicationQueriesSchemes
```

---

### Problem: "Webhook signature verification failed"

**Cause**: Webhook secret mismatch.

**Solution**:
1. Go to Stripe Dashboard → Webhooks
2. Click your webhook endpoint
3. Click "Reveal" on Signing secret
4. Copy the FULL secret (starts with `whsec_`)
5. Update Railway:
   ```bash
   railway variables set STRIPE_WEBHOOK_SECRET=whsec_YOUR_FULL_SECRET
   ```

---

### Problem: Deep link doesn't open app

**iOS Solution**:
```bash
# Check Info.plist syntax
cat ios/Runner/Info.plist | grep -A 10 CFBundleURLSchemes

# Should show:
# <string>pushinapp</string>

# Test manually:
xcrun simctl openurl booted "pushinapp://test"
```

**Android Solution**:
```bash
# Check AndroidManifest.xml
cat android/app/src/main/AndroidManifest.xml | grep -A 5 "pushinapp"

# Should show intent-filter with pushinapp scheme

# Test manually:
adb shell am start -W -a android.intent.action.VIEW \
  -d "pushinapp://test" com.pushin.app
```

---

### Problem: "Payment verified but features not unlocked"

**Cause**: App state not updating after verification.

**Solution**:
Check `DeepLinkHandler` callback:

```dart
DeepLinkHandler(
  stripeService: stripeService,
  onPaymentSuccess: (status) {
    // Make sure this updates your app state!
    controller.updatePlanTier(status.planId, 300);
    
    // Or trigger a rebuild:
    setState(() {});
  },
);
```

---

### Problem: Backend returns 500 errors

**Check Railway logs**:
```bash
railway logs --tail
```

**Common issues**:
- Missing environment variable (check all 4 are set)
- Invalid Stripe key (must start with `sk_test_` or `sk_live_`)
- Invalid Price ID (must start with `price_`)

---

### Problem: Stripe Checkout shows "Invalid Price"

**Cause**: Price ID doesn't exist or is from wrong Stripe account.

**Solution**:
1. Go to Stripe Dashboard → Products
2. Click your product
3. Copy the Price ID from the **Pricing** section
4. Verify it matches `STRIPE_PRICE_STANDARD` or `STRIPE_PRICE_ADVANCED`

---

## Part 10: Going Live (Production Mode)

### Switch from Test Mode to Live Mode

**1. Get Live API Keys:**
- Stripe Dashboard → Toggle to **LIVE MODE** (top-right)
- Go to **Developers** → **API keys**
- Copy **Secret key** (`sk_live_...`)

**2. Create Live Products:**
- Products → Add Product (repeat process for Standard & Advanced)
- Get live Price IDs (`price_...`)

**3. Update Environment Variables:**
```bash
railway variables set STRIPE_SECRET_KEY=sk_live_YOUR_LIVE_KEY
railway variables set STRIPE_PRICE_STANDARD=price_LIVE_STANDARD_ID
railway variables set STRIPE_PRICE_ADVANCED=price_LIVE_ADVANCED_ID
```

**4. Configure Live Webhook:**
- Stripe Dashboard (LIVE MODE) → Webhooks → Add endpoint
- Use same webhook URL: `https://YOUR_RAILWAY_URL/api/stripe/webhook`
- Select same 6 events
- Copy new **Live Signing secret** (`whsec_...`)
- Update Railway:
  ```bash
  railway variables set STRIPE_WEBHOOK_SECRET=whsec_LIVE_SECRET
  ```

**5. Test with Real Card:**
- Use your own credit card (small amount will be charged!)
- Complete payment flow
- Verify webhook events in Stripe Dashboard

---

## 🎉 You're Done!

Your Stripe integration is now:

✅ **Deployed** - Backend running on Railway with HTTPS  
✅ **Configured** - Stripe products, webhooks, and environment variables set  
✅ **Integrated** - Flutter app connects to backend and handles deep links  
✅ **Tested** - Payment flow works end-to-end  
✅ **Compliant** - Disclaimer text meets App Store requirements  

### Next Steps

1. **Test thoroughly** with test cards (at least 10 test purchases)
2. **Monitor logs** for any errors in Railway dashboard
3. **Prepare app store submission** with required disclaimers
4. **Go live** when ready by switching to live Stripe keys

---

**Questions or issues? Check the troubleshooting section or review Railway/Stripe logs!**

**Ship it! 🚀**



































