# Password Reset Setup Guide

## What Was Fixed

I've implemented a complete, industry-standard password reset system for your Flutter app:

### Backend Fixes (Node.js)

1. **Database Schema** - Added missing tables and columns:
   - `password_reset_tokens` table with token hashing, expiration, and one-time use
   - `audit_logs` table for security event tracking
   - Added `firstname` and `updated_at` columns to `users` table

2. **Email Service** - Implemented `sendPasswordResetEmail()` function:
   - Full nodemailer integration with SMTP support
   - Beautiful HTML email template with branding
   - Support for multiple email providers (Gmail, SendGrid, Mailgun, AWS SES, Mailtrap)
   - Automatic fallback to plain text for email clients that don't support HTML

3. **Bug Fixes**:
   - Fixed database column reference (`password` → `password_hash`) in backend/auth.js:700
   - Added proper error handling and logging throughout

4. **Security Features**:
   - Cryptographically secure token generation (32 bytes, SHA-256 hashed)
   - 15-minute token expiration
   - One-time use tokens (prevents replay attacks)
   - Rate limiting (5 requests per 15 minutes per IP+email)
   - Audit logging for all password reset events
   - Automatic session invalidation after password reset

### Frontend (Flutter)
- Already properly implemented in `AuthenticationService.dart`
- Beautiful UI screens in `ForgotPasswordScreen.dart` and `ResetPasswordScreen.dart`
- Proper validation and error handling

---

## Setup Instructions

### Step 1: Update Your Database

Run the updated database initialization script:

```bash
cd backend
node init_db.js
```

This will create the new tables: `password_reset_tokens` and `audit_logs`, and add missing columns to the `users` table.

### Step 2: Configure Email Service

Copy the environment variables from `backend/env.example` to your `.env` file.

#### Option A: Gmail (Easiest for Testing)

1. Enable 2-Factor Authentication on your Google account
2. Generate an App Password:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and your device
   - Copy the 16-character password

3. Add to your `.env` file:

```env
# Email Configuration
FRONTEND_URL=pushinapp://reset-password
EMAIL_FROM="PUSHIN" <noreply@pushinapp.com>

# Gmail SMTP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-email@gmail.com
SMTP_PASS=xxxx xxxx xxxx xxxx  # Your 16-char app password
```

#### Option B: Mailtrap (Best for Development)

Mailtrap catches all emails so you can test without sending real emails.

1. Sign up at https://mailtrap.io (free tier available)
2. Get credentials from Dashboard → Email Testing → SMTP Settings
3. Add to your `.env` file:

```env
# Email Configuration
FRONTEND_URL=pushinapp://reset-password
EMAIL_FROM="PUSHIN" <noreply@pushinapp.com>

# Mailtrap SMTP
SMTP_HOST=sandbox.smtp.mailtrap.io
SMTP_PORT=2525
SMTP_SECURE=false
SMTP_USER=your-mailtrap-username
SMTP_PASS=your-mailtrap-password
```

#### Option C: SendGrid (Production Ready)

1. Sign up at https://sendgrid.com
2. Create API key: Settings → API Keys
3. Add to your `.env` file:

```env
# Email Configuration
FRONTEND_URL=https://yourapp.com/reset-password
EMAIL_FROM="PUSHIN" <noreply@pushinapp.com>

# SendGrid SMTP
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=apikey
SMTP_PASS=your-sendgrid-api-key
```

### Step 3: Set Frontend URL

The `FRONTEND_URL` determines where the password reset link points:

- **Mobile App (Deep Link)**: `pushinapp://reset-password`
- **Web App**: `https://yourapp.com/reset-password`

Make sure your app handles the deep link or route properly!

### Step 4: Set JWT Secrets (Important for Production!)

Generate strong random secrets for production:

```bash
# Generate secrets using OpenSSL
openssl rand -base64 64
```

Add to your `.env`:

```env
JWT_SECRET=your-long-random-secret-here
JWT_REFRESH_SECRET=another-long-random-secret-here
```

### Step 5: Restart Your Backend

```bash
cd backend
npm start
```

---

## Testing the Flow

### 1. Request Password Reset

```bash
curl -X POST http://localhost:3000/api/auth/forgot-password \\
  -H "Content-Type: application/json" \\
  -d '{"email": "test@example.com"}'
```

Expected response:
```json
{
  "success": true,
  "message": "Password reset email sent"
}
```

### 2. Check Your Email

- **Gmail**: Check your inbox
- **Mailtrap**: Check your Mailtrap inbox at https://mailtrap.io/inboxes
- **SendGrid**: Check the recipient's email

The email will contain a reset link like:
```
pushinapp://reset-password?token=64-character-hex-token
```

### 3. Reset Password

Use the token from the email:

```bash
curl -X POST http://localhost:3000/api/auth/reset-password \\
  -H "Content-Type: application/json" \\
  -d '{
    "token": "your-64-char-token-here",
    "newPassword": "NewSecure123!"
  }'
```

Expected response:
```json
{
  "success": true,
  "message": "Password reset successfully"
}
```

### 4. Verify in Flutter App

1. Open your Flutter app
2. Tap "Forgot Password?" on sign-in screen
3. Enter email address
4. Check email for reset link
5. Click the link (should open your app)
6. Enter new password
7. See success screen
8. Sign in with new password

---

## Security Features

✅ **Token Security**
- Tokens are 256-bit random values (32 bytes hex = 64 characters)
- Stored as SHA-256 hashes in database (never store plain tokens)
- Expire after 15 minutes
- Single use only (marked as used after reset)

✅ **Rate Limiting**
- 5 forgot password requests per 15 minutes per IP+email combo
- 10 reset password attempts per 15 minutes per IP
- Prevents brute force and DoS attacks

✅ **Audit Logging**
- All password reset events logged with timestamp, IP, user agent
- Events: `password_reset_initiated`, `password_reset_email_sent`, `password_reset_successful`, etc.
- Query logs: `SELECT * FROM audit_logs WHERE event_type LIKE 'password_reset%'`

✅ **Session Invalidation**
- All refresh tokens deleted when password is reset
- Forces user to sign in again on all devices
- Prevents hijacked sessions from remaining active

✅ **Information Disclosure Protection**
- Always returns success even if email doesn't exist
- Prevents email enumeration attacks

✅ **Strong Password Policy** (backend/auth.js:23-71)
- Minimum 8 characters
- At least 1 uppercase, 1 lowercase, 1 number, 1 special character
- Blocks common passwords
- No more than 3 repeated characters

---

## Troubleshooting

### "Failed to send password reset email"

**Check SMTP credentials:**
```bash
# View backend logs
cd backend
npm start
# Look for: "❌ SMTP verification failed"
```

**Common Issues:**
- Wrong SMTP host/port/credentials
- Gmail: Need app password (not regular password)
- Gmail: 2FA must be enabled
- Firewall blocking SMTP ports (587, 465, 2525)

### Token expired or invalid

Tokens expire after 15 minutes. Request a new one.

### Email not received

1. **Check spam folder**
2. **Verify email service:**
   ```bash
   # Check backend logs for email sending
   # Should see: "✅ Password reset email sent successfully"
   ```
3. **Test SMTP connection:**
   - Use Mailtrap to capture all emails during development
   - Check SendGrid Activity Feed for production

### Frontend URL not working

Make sure your app has deep linking configured:

**iOS (ios/Runner/Info.plist):**
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

**Android (android/app/src/main/AndroidManifest.xml):**
```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="pushinapp" />
</intent-filter>
```

---

## Database Schema Reference

### password_reset_tokens
```sql
CREATE TABLE password_reset_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) UNIQUE NOT NULL,  -- SHA-256 hash of token
  expires_at TIMESTAMP NOT NULL,            -- 15 minutes from creation
  used BOOLEAN DEFAULT false,               -- One-time use flag
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### audit_logs
```sql
CREATE TABLE audit_logs (
  id SERIAL PRIMARY KEY,
  event_type VARCHAR(100) NOT NULL,         -- e.g., 'password_reset_initiated'
  user_id INTEGER REFERENCES users(id),
  ip_address VARCHAR(50),
  user_agent TEXT,
  metadata JSONB,                           -- Additional event data
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## Production Checklist

Before deploying to production:

- [ ] Generate and set strong JWT secrets
- [ ] Configure production email service (SendGrid, Mailgun, or AWS SES)
- [ ] Set correct `FRONTEND_URL` for your production domain
- [ ] Test email delivery in production
- [ ] Verify deep links work on iOS and Android
- [ ] Monitor audit logs for suspicious activity
- [ ] Set up email delivery monitoring (SendGrid/Mailgun dashboards)
- [ ] Configure DNS records for custom email domain (SPF, DKIM, DMARC)
- [ ] Test rate limiting is working
- [ ] Verify password policy enforcement

---

## Support

If you encounter issues:

1. Check backend logs: `cd backend && npm start`
2. Check Flutter logs: Look for "🔑 FORGOT PASSWORD" and "🔄 RESET PASSWORD" messages
3. Verify database tables exist: `psql $DATABASE_URL` then `\dt`
4. Test SMTP connection separately before integrating

The implementation follows industry best practices from OWASP and NIST guidelines.
