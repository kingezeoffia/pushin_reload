# ⚡ PUSHIN' Stripe - Quick Reference

**Copy-paste commands for deploying and testing Stripe integration.**

---

## 🚀 Deploy to Railway (5 minutes)

```bash
# 1. Install Railway CLI
brew install railway

# 2. Login
railway login

# 3. Deploy backend
cd /Users/kingezeoffia/pushin_reload/backend
railway init
railway up

# 4. Set environment variables (replace with YOUR values)
railway variables set STRIPE_SECRET_KEY=sk_test_YOUR_KEY
railway variables set STRIPE_PRICE_STANDARD=price_YOUR_STANDARD_ID
railway variables set STRIPE_PRICE_ADVANCED=price_YOUR_ADVANCED_ID
railway variables set NODE_ENV=production

# 5. Get your API URL
railway domain
# Save this URL!

# 6. Test health endpoint
curl https://YOUR_RAILWAY_URL.up.railway.app/api/health
```

---

## 🔗 Configure Stripe Webhook

```bash
# Your webhook URL:
https://YOUR_RAILWAY_URL.up.railway.app/api/stripe/webhook

# Add this in Stripe Dashboard:
# 1. Go to: https://dashboard.stripe.com/test/webhooks
# 2. Click "Add endpoint"
# 3. Enter webhook URL above
# 4. Select these events:
#    - checkout.session.completed
#    - customer.subscription.created
#    - customer.subscription.updated
#    - customer.subscription.deleted
#    - invoice.payment_succeeded
#    - invoice.payment_failed
# 5. Copy the "Signing secret" (whsec_...)

# Set webhook secret in Railway:
railway variables set STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET
```

---

## 📱 Deep Link Configuration

### iOS: `ios/Runner/Info.plist`

Add inside `<dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>pushinapp</string>
    </array>
  </dict>
</array>
```

### Android: `android/app/src/main/AndroidManifest.xml`

Add inside `<activity android:name=".MainActivity">`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="pushinapp" android:host="payment-success" />
    <data android:scheme="pushinapp" android:host="payment-cancel" />
</intent-filter>
```

---

## 🧪 Testing Commands

### Test Deep Links

**iOS:**
```bash
xcrun simctl openurl booted "pushinapp://payment-success?session_id=cs_test_123"
```

**Android:**
```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "pushinapp://payment-success?session_id=cs_test_123" \
  com.pushin.app
```

### Test Stripe Checkout

**Test Card:**
```
Card: 4242 4242 4242 4242
Expiry: 12/34
CVC: 123
```

### Monitor Backend Logs

```bash
railway logs --tail
```

---

## 📝 App Store Compliance Copy

### Paywall Disclaimer

```dart
Text(
  'You can subscribe through our payment provider (Stripe) '
  'or via the App Store. Prices are the same for both options. '
  'External subscriptions are managed at stripe.com.',
)
```

### Checkout Dialog

```dart
AlertDialog(
  title: Text('Complete Payment'),
  content: Text(
    'You will be redirected to a secure external checkout '
    'to complete your subscription. Return to the app when done.'
  ),
)
```

---

## ✅ Quick Checklist

- [ ] Railway deployed
- [ ] Environment variables set (4 total)
- [ ] Webhook configured in Stripe
- [ ] Deep links added to iOS/Android
- [ ] Flutter app updated with Railway URL
- [ ] Test payment completed successfully
- [ ] Disclaimer text added to Paywall

---

## 🆘 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Health check fails | Check Railway URL is correct |
| Webhook verification fails | Verify `STRIPE_WEBHOOK_SECRET` matches Stripe Dashboard |
| Deep link doesn't open app | Check `Info.plist` / `AndroidManifest.xml` syntax |
| Payment not verified | Check Railway logs: `railway logs` |

---

## 📍 Key URLs

- **Stripe Dashboard**: https://dashboard.stripe.com
- **Railway Dashboard**: https://railway.app
- **Your API**: https://YOUR_RAILWAY_URL.up.railway.app
- **Health Check**: https://YOUR_RAILWAY_URL.up.railway.app/api/health

---

**For detailed steps, see `STRIPE_DEPLOYMENT_GUIDE.md`**











