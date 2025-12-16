# Stripe Web Checkout Integration Guide

**Status**: Ready for implementation  
**Payment Flow**: External Stripe Checkout (Web)  
**Returns**: Deep link back to app

---

## 🎯 Overview

This integration allows users to subscribe to PUSHIN' paid plans via Stripe Web Checkout without using Apple/Google in-app purchases.

**Flow**:
1. User taps "Upgrade" in PaywallScreen
2. Flutter calls your backend API
3. Backend creates Stripe Checkout session
4. App launches browser with Stripe Checkout URL
5. User completes payment on Stripe
6. Stripe redirects back to app via deep link
7. App verifies payment and unlocks premium features

---

## 📦 Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  http: ^1.1.0
  url_launcher: ^6.2.2
  uni_links: ^0.5.1
  shared_preferences: ^2.2.2
```

Run:
```bash
flutter pub get
```

---

## 🔗 Deep Link Setup

### iOS Setup

**1. Update `ios/Runner/Info.plist`:**

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

**2. Update `ios/Runner/Runner.entitlements`** (create if doesn't exist):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.associated-domains</key>
  <array>
    <string>applinks:pushinapp.com</string>
  </array>
</dict>
</plist>
```

**3. Test deep link:**
```bash
xcrun simctl openurl booted "pushinapp://payment-success?session_id=test123"
```

### Android Setup

**1. Update `android/app/src/main/AndroidManifest.xml`:**

```xml
<activity
    android:name=".MainActivity"
    ...>
    
    <!-- Existing intent filters -->
    ...
    
    <!-- Add deep link intent filter -->
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
    
    <!-- Universal link (App Links) -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <data
            android:scheme="https"
            android:host="pushinapp.com"
            android:pathPrefix="/payment-success" />
        <data
            android:scheme="https"
            android:host="pushinapp.com"
            android:pathPrefix="/payment-cancel" />
    </intent-filter>
</activity>
```

**2. Test deep link:**
```bash
adb shell am start -W -a android.intent.action.VIEW -d "pushinapp://payment-success?session_id=test123" com.pushin.app
```

---

## 🚀 Flutter Integration

**Update your `main.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/StripeCheckoutService.dart';
import 'services/DeepLinkHandler.dart';
import 'controller/PushinAppController.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final stripeService = StripeCheckoutService(
    baseUrl: 'YOUR_BACKEND_URL', // e.g., https://api.pushinapp.com/api
  );
  
  runApp(MyApp(stripeService: stripeService));
}

class MyApp extends StatefulWidget {
  final StripeCheckoutService stripeService;
  
  const MyApp({super.key, required this.stripeService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late DeepLinkHandler _deepLinkHandler;

  @override
  void initState() {
    super.initState();
    
    // Initialize deep link handler
    _deepLinkHandler = DeepLinkHandler(
      stripeService: widget.stripeService,
      onPaymentSuccess: (status) {
        // Update app controller with new subscription
        print('✅ Payment successful! Plan: ${status.planId}');
        
        // TODO: Update PushinAppController
        // context.read<PushinAppController>().updatePlanTier(status.planId, gracePeriodSeconds);
        
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Welcome to Premium!'),
            content: Text('You\'re now on the ${status.displayName}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Start Using'),
              ),
            ],
          ),
        );
      },
      onPaymentCanceled: () {
        print('⚠️ Payment was canceled');
        
        // Optionally show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment canceled')),
        );
      },
    );
    
    _deepLinkHandler.initialize();
  }

  @override
  void dispose() {
    _deepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Your app setup
      home: HomeScreen(),
    );
  }
}
```

---

## 🔧 Backend API Contract

### Required Endpoints

#### 1. Create Checkout Session

**POST** `/api/stripe/create-checkout-session`

**Request Body**:
```json
{
  "userId": "user123",
  "planId": "standard",
  "userEmail": "user@example.com",
  "successUrl": "pushinapp://payment-success?session_id={CHECKOUT_SESSION_ID}",
  "cancelUrl": "pushinapp://payment-cancel"
}
```

**Response**:
```json
{
  "checkoutUrl": "https://checkout.stripe.com/c/pay/cs_test_xxx",
  "sessionId": "cs_test_xxx"
}
```

#### 2. Verify Payment

**POST** `/api/stripe/verify-payment`

**Request Body**:
```json
{
  "sessionId": "cs_test_xxx",
  "userId": "user123"
}
```

**Response**:
```json
{
  "isActive": true,
  "planId": "standard",
  "customerId": "cus_xxx",
  "subscriptionId": "sub_xxx",
  "currentPeriodEnd": "2024-02-15T00:00:00Z"
}
```

#### 3. Check Subscription Status

**GET** `/api/stripe/subscription-status?userId=user123`

**Response**:
```json
{
  "isActive": true,
  "planId": "standard",
  "customerId": "cus_xxx",
  "subscriptionId": "sub_xxx",
  "currentPeriodEnd": "2024-02-15T00:00:00Z"
}
```

#### 4. Cancel Subscription

**POST** `/api/stripe/cancel-subscription`

**Request Body**:
```json
{
  "userId": "user123",
  "subscriptionId": "sub_xxx"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Subscription will be canceled at period end"
}
```

---

## 💻 Backend Implementation (Node.js/Express)

Create `server.js`:

```javascript
const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.json());

// In-memory user storage (replace with your database)
const users = new Map();

// 1. Create Checkout Session
app.post('/api/stripe/create-checkout-session', async (req, res) => {
  try {
    const { userId, planId, userEmail, successUrl, cancelUrl } = req.body;

    // Determine price ID based on plan
    const priceIds = {
      standard: process.env.STRIPE_PRICE_STANDARD, // e.g., price_xxx
      advanced: process.env.STRIPE_PRICE_ADVANCED, // e.g., price_yyy
    };

    const priceId = priceIds[planId];
    if (!priceId) {
      return res.status(400).json({ error: 'Invalid plan ID' });
    }

    // Create Stripe Checkout session
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer_email: userEmail,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: {
        userId,
        planId,
      },
    });

    res.json({
      checkoutUrl: session.url,
      sessionId: session.id,
    });
  } catch (error) {
    console.error('Error creating checkout session:', error);
    res.status(500).json({ error: error.message });
  }
});

// 2. Verify Payment
app.post('/api/stripe/verify-payment', async (req, res) => {
  try {
    const { sessionId, userId } = req.body;

    // Retrieve the checkout session
    const session = await stripe.checkout.sessions.retrieve(sessionId, {
      expand: ['subscription'],
    });

    if (session.payment_status === 'paid') {
      const subscription = session.subscription;
      
      // Store subscription in your database
      users.set(userId, {
        customerId: session.customer,
        subscriptionId: subscription.id,
        planId: session.metadata.planId,
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        isActive: true,
      });

      res.json({
        isActive: true,
        planId: session.metadata.planId,
        customerId: session.customer,
        subscriptionId: subscription.id,
        currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
      });
    } else {
      res.json({
        isActive: false,
        planId: 'free',
        customerId: null,
        subscriptionId: null,
        currentPeriodEnd: null,
      });
    }
  } catch (error) {
    console.error('Error verifying payment:', error);
    res.status(500).json({ error: error.message });
  }
});

// 3. Check Subscription Status
app.get('/api/stripe/subscription-status', async (req, res) => {
  try {
    const { userId } = req.query;
    
    const userData = users.get(userId);
    if (!userData || !userData.subscriptionId) {
      return res.json({
        isActive: false,
        planId: 'free',
        customerId: null,
        subscriptionId: null,
        currentPeriodEnd: null,
      });
    }

    // Fetch latest subscription status from Stripe
    const subscription = await stripe.subscriptions.retrieve(userData.subscriptionId);
    
    const isActive = subscription.status === 'active';
    
    res.json({
      isActive,
      planId: userData.planId,
      customerId: userData.customerId,
      subscriptionId: userData.subscriptionId,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
    });
  } catch (error) {
    console.error('Error checking subscription:', error);
    res.status(500).json({ error: error.message });
  }
});

// 4. Cancel Subscription
app.post('/api/stripe/cancel-subscription', async (req, res) => {
  try {
    const { userId, subscriptionId } = req.body;

    // Cancel at period end (user keeps access until billing period ends)
    await stripe.subscriptions.update(subscriptionId, {
      cancel_at_period_end: true,
    });

    res.json({
      success: true,
      message: 'Subscription will be canceled at period end',
    });
  } catch (error) {
    console.error('Error canceling subscription:', error);
    res.status(500).json({ error: error.message });
  }
});

// 5. Webhook Handler (CRITICAL for production)
app.post('/api/stripe/webhook', bodyParser.raw({ type: 'application/json' }), async (req, res) => {
  const sig = req.headers['stripe-signature'];
  
  try {
    const event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );

    // Handle different event types
    switch (event.type) {
      case 'checkout.session.completed':
        const session = event.data.object;
        console.log('✅ Checkout completed:', session.id);
        // Update user subscription in database
        break;
        
      case 'customer.subscription.updated':
        const updatedSub = event.data.object;
        console.log('🔄 Subscription updated:', updatedSub.id);
        // Update subscription status
        break;
        
      case 'customer.subscription.deleted':
        const deletedSub = event.data.object;
        console.log('❌ Subscription canceled:', deletedSub.id);
        // Mark subscription as inactive
        break;
    }

    res.json({ received: true });
  } catch (error) {
    console.error('Webhook error:', error.message);
    res.status(400).send(`Webhook Error: ${error.message}`);
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
```

**Environment Variables** (`.env`):
```
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_PRICE_STANDARD=price_xxx
STRIPE_PRICE_ADVANCED=price_yyy
STRIPE_WEBHOOK_SECRET=whsec_xxx
```

---

## 🔒 Security Best Practices

### 1. **Use Webhooks**
- Never rely solely on client-side verification
- Stripe webhooks ensure you're notified of subscription changes
- Validate webhook signatures

### 2. **Verify Session Server-Side**
- Always verify `sessionId` on your backend
- Never trust client-provided subscription status

### 3. **Use HTTPS**
- Always use HTTPS for your backend API
- Never send Stripe secret keys to the client

### 4. **Authentication**
- Add authentication headers to all API requests
- Use JWT tokens or session cookies
- Validate `userId` matches authenticated user

### 5. **Rate Limiting**
- Implement rate limiting on checkout creation
- Prevent abuse (e.g., 5 checkouts per user per hour)

---

## 🧪 Testing

### Sandbox Testing

**1. Stripe Test Mode**
- Use test API keys (`sk_test_xxx`)
- Test credit card: `4242 4242 4242 4242`
- Any future expiry date, any CVC

**2. Test Deep Links**

iOS Simulator:
```bash
xcrun simctl openurl booted "pushinapp://payment-success?session_id=cs_test_xxx"
```

Android Emulator:
```bash
adb shell am start -W -a android.intent.action.VIEW -d "pushinapp://payment-success?session_id=cs_test_xxx" com.pushin.app
```

**3. Test Webhook Locally**
```bash
# Install Stripe CLI
stripe listen --forward-to localhost:3000/api/stripe/webhook

# Trigger test events
stripe trigger checkout.session.completed
```

### Production Testing

1. Switch to live API keys (`sk_live_xxx`)
2. Use real credit card (your own for testing)
3. Verify webhooks are receiving events in Stripe Dashboard
4. Test on real devices (not simulators)

---

## 📱 Apple/Google Policy Compliance (2025)

### ⚠️ IMPORTANT: External Payment Rules

**Apple (as of 2024)**:
- External links for digital goods are now **partially allowed** (with restrictions)
- Must include App Store listing with in-app purchase option
- External link must include disclaimers
- Apple takes 12-27% commission on external sales (depending on developer program)

**Google (as of 2024)**:
- External payments **allowed** for subscriptions
- Must offer Google Play Billing as an option
- Google takes 4% commission on external sales

**Recommendations**:
1. **Dual Payment Option**: Offer both in-app purchase AND external Stripe checkout
2. **Comply with Guidelines**: Include required disclaimers when linking externally
3. **Regional Restrictions**: Some countries require in-app purchases only
4. **Monitor Policy Changes**: App Store policies change frequently

**Example Disclaimer Text**:
```
"You can subscribe via Stripe (external payment) or through 
the App Store. Prices are the same. Stripe subscriptions are 
managed outside the app at stripe.com."
```

---

## 🚀 Stripe Dashboard Setup

### 1. Create Products

Go to Stripe Dashboard → Products → Add Product:

**Standard Plan**:
- Name: PUSHIN' Standard
- Price: €9.99/month
- Billing Period: Monthly, recurring
- Copy the Price ID (`price_xxx`)

**Advanced Plan**:
- Name: PUSHIN' Advanced
- Price: €14.99/month
- Billing Period: Monthly, recurring
- Copy the Price ID (`price_yyy`)

### 2. Configure Webhooks

Dashboard → Developers → Webhooks → Add endpoint:

**URL**: `https://api.pushinapp.com/api/stripe/webhook`

**Events to listen for**:
- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

Copy the **Webhook Secret** (`whsec_xxx`)

### 3. Test Mode vs Live Mode

- Start in **Test Mode** (toggle in Dashboard)
- Use test API keys for development
- Switch to **Live Mode** for production
- Update environment variables with live keys

---

## ✅ Checklist Before Going Live

- [ ] Backend API deployed and accessible via HTTPS
- [ ] Environment variables configured (live Stripe keys)
- [ ] Webhooks configured in Stripe Dashboard
- [ ] Deep links tested on real devices
- [ ] Subscription flow tested end-to-end
- [ ] Cancel subscription flow tested
- [ ] Error handling tested (declined cards, network failures)
- [ ] Apple/Google policy compliance reviewed
- [ ] Terms of Service and Privacy Policy updated
- [ ] Customer support flow prepared for billing questions

---

## 🆘 Troubleshooting

### Deep Link Not Working

**iOS**: Check `Info.plist` and test with:
```bash
xcrun simctl openurl booted "pushinapp://test"
```

**Android**: Check `AndroidManifest.xml` and test with:
```bash
adb shell am start -W -a android.intent.action.VIEW -d "pushinapp://test" com.pushin.app
```

### Payment Verification Fails

- Check backend logs for errors
- Verify `sessionId` is correct
- Ensure webhook is receiving events
- Check Stripe Dashboard → Events for payment status

### Subscription Not Syncing

- Verify webhook endpoint is accessible (test with `stripe trigger`)
- Check webhook signing secret is correct
- Ensure user ID mapping is correct in database

---

## 📚 Resources

- [Stripe Checkout Docs](https://stripe.com/docs/payments/checkout)
- [Stripe Subscriptions Guide](https://stripe.com/docs/billing/subscriptions/overview)
- [Flutter Deep Linking](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [Apple External Purchase Links](https://developer.apple.com/support/storekit-external-entitlement/)
- [Google Play Alternative Billing](https://support.google.com/googleplay/android-developer/answer/12175430)

---

**Ship it! 🚀 You're ready to monetize PUSHIN' with Stripe!**


