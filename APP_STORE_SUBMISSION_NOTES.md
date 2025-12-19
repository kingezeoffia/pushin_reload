# 📱 App Store / Play Store Submission Notes

**Copy-paste text for app store submissions with Stripe external payments.**

---

## Apple App Store - App Review Notes

### General Information

**App Uses External Payment Links**: ✅ Yes

**Entitlement**: External Purchase Link Entitlement  
**Applies to**: US App Store (and other qualifying regions)

---

### App Review Information Text

**Paste this in "App Review Information" → "Notes" field:**

```
EXTERNAL PAYMENT LINK DISCLOSURE

This app offers digital subscriptions through external payment processing 
via Stripe, in accordance with Apple's External Purchase Link Entitlement.

COMPLIANCE DETAILS:
• Users are clearly informed before being redirected to external checkout
• A disclaimer is shown on the upgrade screen explaining external payment
• Prices are identical between external checkout and App Store IAP
• External subscriptions are managed at stripe.com
• All required disclosures are displayed before checkout begins

PAYMENT OPTIONS:
The app offers two payment methods:
1. Stripe (external) - redirects to checkout.stripe.com
2. App Store IAP - uses Apple's native payment system

SUBSCRIPTION PLANS:
• Standard Plan: €9.99/month (3 workouts, 3 hours daily usage)
• Advanced Plan: €14.99/month (5 workouts, unlimited daily usage)

TEST INSTRUCTIONS:
1. Open the app and navigate to Settings → Upgrade
2. Tap "Upgrade to Standard" or "Upgrade to Advanced"
3. Review the external payment disclaimer dialog
4. Select "Continue to Checkout" to test Stripe flow
5. Use test card: 4242 4242 4242 4242 (Expiry: 12/34, CVC: 123)
6. Complete payment and return to app via deep link
7. Verify premium features are unlocked

TEST ACCOUNT:
Email: test@pushinapp.com
Password: TestReview2024!

DEMO MODE:
A demo mode is available in Settings → "Enable Demo Mode" to unlock 
all features without payment for review purposes.

EXTERNAL LINK WARNINGS:
Before redirecting to Stripe, the app displays:
"You will be redirected to a secure external checkout to complete 
your subscription. External subscriptions are managed at stripe.com."

CONTACT:
For questions during review, contact: support@pushinapp.com
```

---

## Apple App Store - App Description

**Include this paragraph in your App Description:**

```
💳 FLEXIBLE PAYMENT OPTIONS

Subscribe using your preferred payment method:
• Credit/Debit Card via Stripe (external checkout)
• Apple App Store In-App Purchase

Both options offer the same pricing and features. External subscriptions 
are managed securely at stripe.com.
```

---

## Google Play Store - App Content Questionnaire

### Does your app use alternative billing?

**Answer**: Yes

**Alternative Billing Provider**: Stripe

**Disclosure**: 
```
You can subscribe through Google Play Billing or our secure payment 
provider (Stripe). Prices are the same for both options. Stripe 
subscriptions are managed at stripe.com.
```

---

## Google Play Store - Data Safety Section

### Does your app collect payment info?

**Answer**: Yes

**Data collected**:
- Email address (for subscription management)
- Payment information (processed by Stripe, not stored in app)

**Data usage**:
- Subscription management
- Customer support

**Data sharing**:
- Stripe (payment processor)

---

## Privacy Policy - Required Sections

**Add these sections to your Privacy Policy:**

### Payment Processing

```
PUSHIN' uses Stripe for payment processing when you subscribe via 
external checkout. When you complete a purchase through Stripe:

• Your payment information is collected and processed by Stripe
• We receive only a subscription status and identifier
• We do not store your credit card details
• Stripe's privacy policy applies: https://stripe.com/privacy

For subscriptions through App Store or Google Play, Apple and Google's 
respective privacy policies apply.
```

### Subscription Management

```
Subscriptions purchased through Stripe (external checkout):
• Managed at: https://billing.stripe.com
• Cancel anytime through Stripe Customer Portal
• Refunds subject to our refund policy

Subscriptions purchased through App Store:
• Managed in iOS Settings → Apple ID → Subscriptions
• Cancel anytime through Apple
• Refunds handled by Apple

Subscriptions purchased through Google Play:
• Managed in Play Store → Account → Payments & subscriptions
• Cancel anytime through Google Play
• Refunds handled by Google
```

---

## Terms of Service - Required Sections

### Subscription Terms

```
SUBSCRIPTION PLANS

PUSHIN' offers the following subscription plans:
• Standard: €9.99/month - 3 workout types, 3 hours daily usage
• Advanced: €14.99/month - 5 workout types, unlimited daily usage

PAYMENT OPTIONS

You may subscribe through:
1. Stripe (external payment processor)
2. Apple App Store In-App Purchase
3. Google Play Billing

Prices are identical across all payment methods.

STRIPE SUBSCRIPTIONS

Subscriptions purchased through Stripe:
• Automatically renew monthly
• Charged to your payment method on file with Stripe
• Can be canceled at any time at billing.stripe.com
• Cancellation takes effect at the end of the current billing period
• No refunds for partial months

APPLE APP STORE SUBSCRIPTIONS

Subscriptions purchased through the App Store:
• Subject to Apple's Terms of Service
• Managed through iOS Settings → Subscriptions
• Charged through your Apple ID payment method
• Refunds handled by Apple

GOOGLE PLAY SUBSCRIPTIONS

Subscriptions purchased through Google Play:
• Subject to Google Play Terms of Service
• Managed through Play Store → Subscriptions
• Charged through your Google Play payment method
• Refunds handled by Google

CANCELLATION

You may cancel your subscription at any time. Upon cancellation:
• You retain access until the end of your billing period
• No refunds for the remaining days of the current period
• Auto-renewal is disabled
• Your data is retained for 30 days, then deleted

CHANGES TO PRICING

We may change subscription prices with 30 days notice. Existing 
subscribers will maintain their current pricing for the remainder 
of their subscription period.
```

---

## App Store Screenshots - Required Captions

### Paywall Screenshot

**Caption**:
```
"Flexible payment options: subscribe via Stripe or App Store. 
Clear pricing with no hidden fees."
```

---

## Support Documentation

### FAQ - External Payments

**Q: What payment methods do you accept?**

A: You can subscribe using:
• Credit/debit card via Stripe (Visa, Mastercard, Amex)
• Apple App Store In-App Purchase
• Google Play Billing

**Q: Is my payment information secure?**

A: Yes. All payments are processed securely through:
• Stripe (PCI-DSS Level 1 certified)
• Apple (for App Store purchases)
• Google (for Play Store purchases)

We never store your credit card information.

**Q: How do I manage my Stripe subscription?**

A: Go to https://billing.stripe.com and enter the email address 
you used during purchase. You can update payment methods, view 
invoices, and cancel your subscription.

**Q: How do I cancel my subscription?**

A: 
• Stripe subscribers: Visit billing.stripe.com
• App Store subscribers: iOS Settings → Apple ID → Subscriptions
• Play Store subscribers: Play Store → Account → Subscriptions

**Q: Do I get a refund if I cancel?**

A: No refunds for partial months. You keep access until the end 
of your current billing period.

---

## App Review Rejection - Common Issues & Responses

### Issue: "External link not clearly disclosed"

**Response**:
```
Thank you for your feedback. We have added a prominent disclaimer 
on the upgrade screen (screenshot attached) that states:

"You will be redirected to a secure external checkout to complete 
your subscription. External subscriptions are managed at stripe.com."

This dialog appears before any external link is opened, giving users 
clear notice they are leaving the app.
```

---

### Issue: "Must offer App Store IAP option"

**Response**:
```
The app includes both payment options:
1. Stripe external checkout (Screenshot 1)
2. Apple IAP "Pay with App Store" button (Screenshot 2)

Users can choose their preferred payment method. Prices are identical 
for both options, as required by App Store guidelines.
```

---

### Issue: "Subscription management unclear"

**Response**:
```
We have updated the app to include a "Manage Subscription" button 
in Settings that directs users to:
• billing.stripe.com for Stripe subscriptions
• iOS Settings → Subscriptions for App Store subscriptions

This is clearly labeled and accessible from the main Settings screen.
```

---

## Demo Mode for App Review

**Add this to your app for easier review:**

```dart
// In Settings screen
if (kDebugMode) {
  ListTile(
    leading: Icon(Icons.bug_report),
    title: Text('Enable Demo Mode'),
    subtitle: Text('Unlock all features for testing'),
    onTap: () {
      // Unlock premium features without payment
      controller.updatePlanTier('advanced', 999999);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demo mode enabled - all features unlocked')),
      );
    },
  )
}
```

**Mention in Review Notes:**
```
A demo mode is available in Settings → "Enable Demo Mode" to unlock 
all features without payment for review purposes.
```

---

## Contact Information for App Review

**Prepare these contacts:**

- **Support Email**: support@pushinapp.com
- **Privacy Policy URL**: https://pushinapp.com/privacy
- **Terms of Service URL**: https://pushinapp.com/terms
- **Contact Phone**: [Your phone number for urgent review issues]
- **Stripe Account**: [Stripe account email, in case Apple needs to verify]

---

## Checklist Before Submission

- [ ] External payment disclaimer visible on Paywall
- [ ] Both payment options available (Stripe + IAP)
- [ ] Privacy Policy mentions Stripe
- [ ] Terms of Service include subscription terms
- [ ] App Review Notes include test instructions
- [ ] Test account credentials provided
- [ ] Demo mode enabled for review
- [ ] Screenshots show payment flow clearly
- [ ] Subscription management accessible in Settings
- [ ] Deep links tested on real device
- [ ] All placeholder text removed from app

---

**Copy these sections as needed for your app store submissions! 🚀**






















