# 🔧 Fix Railway Connection - Quick Guide

## Problem
Your `.env` file has the **internal** Railway URL which only works inside Railway's network:
```
postgresql://...@postgres-zvno.railway.internal:5432/railway
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                  ❌ Won't work locally!
```

## Solution

### Step 1: Get the PUBLIC Proxy URL

1. **Open Railway Dashboard**: https://railway.app/dashboard
2. **Click** on project **"PUSHIN"**
3. **Click** on **"PostgreSQL"** service (database icon)
4. **Click** the **"Connect"** tab
5. **Look for**: "Postgres Connection URL" or "Public URL"
6. **Copy** the URL that looks like:
   ```
   postgresql://postgres:LONG_PASSWORD@something.proxy.rlwy.net:12345/railway
                                       ^^^^^^^^^^^^^^^^^^^^^^^^
                                       ✅ This is what you need!
   ```

### Step 2: Update Your .env File

**Option A: Use the fix script**
```bash
./fix-env.sh
# Paste your PUBLIC proxy URL when prompted
```

**Option B: Manual edit**
```bash
# Edit .env file
nano .env

# Replace the line with:
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@YOUR_HOST.proxy.rlwy.net:YOUR_PORT/railway
```

### Step 3: Test Connection
```bash
npm run db:test
```

Expected output:
```
✅ Connection successful!
⏰ Server time: ...
🐘 PostgreSQL: PostgreSQL 15.3
```

### Step 4: Create Tables
```bash
npm run db:create
```

---

## Quick Reference

### ❌ Internal URL (doesn't work locally):
```
postgresql://...@postgres-zvno.railway.internal:5432/railway
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

### ✅ Public Proxy URL (works everywhere):
```
postgresql://...@hopper.proxy.rlwy.net:25708/railway
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

---

## Why This Happens

Railway provides TWO connection URLs:

| URL Type | Hostname | Works Locally? | Use Case |
|----------|----------|----------------|----------|
| **PRIVATE** | `*.railway.internal` | ❌ No | Apps running ON Railway |
| **PUBLIC** | `*.proxy.rlwy.net` | ✅ Yes | Local dev, external tools |

Your `.env` file needs the **PUBLIC** proxy URL for local development!

---

## Still Having Issues?

### SSL/TLS Errors
The script handles this automatically with `rejectUnauthorized: false`.

### Connection Timeout
- Check your internet connection
- Verify the URL is copied completely (no spaces/breaks)
- Check Railway service is running

### Password Authentication Failed
- Get fresh URL from Railway dashboard
- Railway may have rotated the password

---

## Next Steps After Success

Once `npm run db:create` succeeds, verify tables:

```bash
# View all tables
npm run db:test

# Or connect directly
psql "$DATABASE_URL" -c "\dt"
```

You should see 5 tables:
- users
- refresh_tokens
- subscriptions
- workouts
- daily_usage

✅ **Ready to develop!**
