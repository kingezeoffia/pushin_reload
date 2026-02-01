# Deep Link Password Reset - Test Guide

## Setup Complete! ✅

I've successfully implemented the complete password reset deep link flow:

### What Was Done:

1. **Backend Email Service** ✅
   - Configured Mailtrap integration
   - Professional HTML email template
   - Token generation and validation

2. **Deep Link Handling** ✅
   - `pushinapp://reset-password?token=...` deep link configured
   - DeepLinkHandler updated with password reset callback
   - Backend token validation before navigation

3. **App Routing** ✅
   - AppRouter updated to detect password reset tokens
   - Automatic navigation to ResetPasswordScreen
   - Token cleanup after navigation

4. **iOS Configuration** ✅
   - `pushinapp` URL scheme already configured in Info.plist

---

## How to Test

### Option 1: Test on Real Device (Recommended)

1. **Build and install your app** on your iPhone:
   ```bash
   cd /Users/kingezeoffia/pushin_reload
   flutter run --release
   ```

2. **Trigger a password reset email** using the test script:
   ```bash
   cd backend
   node test_password_reset.js
   ```

3. **Check Mailtrap inbox**:
   - Go to https://mailtrap.io/inboxes
   - Open the password reset email
   - You'll see a beautiful email with a reset link

4. **Copy the reset link**:
   - The link will look like: `pushinapp://reset-password?token=64-character-hex`
   - Copy the ENTIRE URL

5. **Test the deep link on your iPhone**:
   - **Method A - Safari**:
     - Open Safari on your iPhone
     - Paste the deep link into the address bar
     - Tap Go
     - Safari will ask "Open in Pushin Reload?" → Tap "Open"

   - **Method B - Notes App**:
     - Open Notes app
     - Create a new note
     - Paste the deep link
     - Tap on the link
     - It will open your app

   - **Method C - Messages**:
     - Send the link to yourself via Messages
     - Tap on the link
     - It will open your app

6. **Verify the flow**:
   - App should open
   - You should see the ResetPasswordScreen
   - Enter a new password (at least 6 characters)
   - Confirm the password
   - Tap "Reset Password"
   - Should see success screen

### Option 2: Test on iOS Simulator

1. **Run the app** on iOS simulator:
   ```bash
   cd /Users/kingezeoffia/pushin_reload
   flutter run
   ```

2. **Trigger password reset** (in another terminal):
   ```bash
   cd backend
   node test_password_reset.js
   ```

3. **Get the reset URL** from Mailtrap:
   - Go to https://mailtrap.io/inboxes
   - Copy the full reset URL from the email

4. **Open the deep link** in simulator:
   ```bash
   xcrun simctl openurl booted "pushinapp://reset-password?token=YOUR_TOKEN_HERE"
   ```

   Replace `YOUR_TOKEN_HERE` with the actual token from the email.

---

## Testing Commands

### Send Test Password Reset Email
```bash
cd /Users/kingezeoffia/pushin_reload/backend
node test_password_reset.js
```

### Open Deep Link in Simulator
```bash
# Get the token from Mailtrap, then run:
xcrun simctl openurl booted "pushinapp://reset-password?token=PASTE_TOKEN_HERE"
```

### Check Backend Logs
```bash
cd /Users/kingezeoffia/pushin_reload/backend
npm start
```

---

## Troubleshooting

### Deep link doesn't open the app
- **Check if app is installed**: Make sure the app is installed on the device/simulator
- **Check URL scheme**: Verify `pushinapp` is in ios/Runner/Info.plist (it is!)
- **Try rebuilding**: `flutter clean && flutter run`

### App opens but doesn't show ResetPasswordScreen
- **Check console logs**: Look for:
  ```
  🔗 DEEP LINK STREAM RECEIVED
  🔑 Password reset deep link received
  🔑 PASSWORD RESET TOKEN detected → ResetPasswordScreen
  ```
- **Verify token format**: Should be exactly 64 hexadecimal characters

### "Invalid or expired token" error
- Tokens expire after 15 minutes
- Request a new reset email: `node test_password_reset.js`

### Email not received in Mailtrap
- Check backend logs for errors
- Verify `.env` has correct Mailtrap credentials
- Check that backend is running

---

## Expected Flow

1. User taps "Forgot Password?" in app
2. Enters email → `test@example.com`
3. Backend sends email via Mailtrap
4. User opens email in Mailtrap inbox
5. User taps the reset link
6. Deep link opens the app → ResetPasswordScreen
7. User enters new password
8. Password is reset successfully
9. User can sign in with new password

---

## Current Test Data

- **Test Email**: `test@example.com`
- **User ID**: 39 (in database)
- **Backend URL**: `http://192.168.1.107:3000/api` (for iOS physical device)

---

## Next Steps

Once you verify the deep link works:

1. **Test the full flow in your app**:
   - Sign in with `test@example.com`
   - Sign out
   - Tap "Forgot Password?"
   - Complete the flow

2. **Test on Android** (if needed):
   - Android deep links are configured differently
   - May need to add intent-filter to AndroidManifest.xml

3. **Deploy to production**:
   - Update email service to SendGrid or AWS SES
   - Update FRONTEND_URL in backend .env
   - Test with real email addresses

---

## Quick Test Command

Run this single command to test the whole flow:

```bash
cd /Users/kingezeoffia/pushin_reload/backend && \\
node test_password_reset.js && \\
echo "" && \\
echo "📧 Check your Mailtrap inbox: https://mailtrap.io/inboxes" && \\
echo "🔗 Copy the reset link and paste it in Safari on your device" && \\
echo "📱 Or use this command in simulator:" && \\
echo "   xcrun simctl openurl booted 'pushinapp://reset-password?token=TOKEN_HERE'"
```

Happy testing! 🎉
