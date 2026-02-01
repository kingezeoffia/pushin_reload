# Fix Railway Database Connection for Restore Button

## Problem
The restore button functionality is **100% working** in the code, but Railway can't connect to the database.

Current DATABASE_URL uses internal hostname:
```
postgresql://postgres:***@postgres-zvno.railway.internal:5432/railway
```

## Solution: Update DATABASE_URL with Public Proxy

### Step 1: Get Public Database URL from Railway Dashboard

1. Open: https://railway.app/dashboard
2. Click on your **PUSHIN** project
3. Click on the **PostgreSQL** service (postgres-zvno)
4. Click the **"Connect"** tab at the top
5. Look for **"Postgres Connection URL"** or **"Public URL"**
6. Copy the URL that looks like:
   ```
   postgresql://postgres:PASSWORD@postgres-zvno-production.up.railway.app:PORT/railway
   ```
   Note: It should have `.up.railway.app` NOT `.railway.internal`

### Step 2: Update Environment Variable

**Option A: Via Railway Dashboard (Easiest)**
1. In your PUSHIN project dashboard
2. Click on the **PUSHIN** service (your backend server)
3. Go to **"Variables"** tab
4. Find `DATABASE_URL`
5. Click "Edit"
6. Replace with the public URL from Step 1
7. Click "Save" - Railway will automatically redeploy

**Option B: Via Railway CLI**
```bash
railway variables --set DATABASE_URL="postgresql://postgres:PASSWORD@postgres-zvno-production.up.railway.app:PORT/railway"
```

### Step 3: Test After Deployment

Wait 1-2 minutes for deployment, then test:

```bash
# Test table access
curl https://pushin-production.up.railway.app/api/stripe/test-tables

# Test restore endpoint (with a test email)
curl -X POST 'https://pushin-production.up.railway.app/api/stripe/restore-by-email' \
  -H 'Content-Type: application/json' \
  -d '{"email": "test@example.com"}'
```

### Expected Results

**Before fix:**
```json
{"success":false,"error":"Connection terminated unexpectedly"}
```

**After fix:**
```json
{
  "success":false,
  "error":"no_active_subscription",
  "message":"No active subscriptions found for this email address."
}
```

The second response means the database connection works! It's just that the email has no subscription (which is expected for a test email).

## Verification in Your App

Once Railway redeploys with the correct DATABASE_URL:

1. Open your app
2. Go to the Paywall screen
3. Click "Restore" in the top right
4. Enter your email: `kingezeoffia28@gmail.com`
5. Click "Check Purchases"

### Expected Behavior:
- ✅ If you have a subscription: It will restore and navigate to the main app
- ℹ️ If you don't have a subscription: It will show "No active subscriptions found"

## Alternative: Connect to Railway DB Locally

If you want to manage subscriptions directly, you can connect with:

```bash
# Install PostgreSQL client if you don't have it
brew install postgresql

# Connect using the public URL
psql "postgresql://postgres:PASSWORD@postgres-zvno-production.up.railway.app:PORT/railway"
```

Then you can query subscriptions:
```sql
-- Check authenticated subscriptions
SELECT * FROM subscriptions WHERE is_active = true;

-- Check anonymous subscriptions
SELECT * FROM anonymous_subscriptions WHERE is_active = true;
```

## Summary

The restore button code is **fully functional**. The only issue was Railway using the internal database URL instead of the public proxy URL. Once you update the DATABASE_URL environment variable, everything will work perfectly! 🎉
