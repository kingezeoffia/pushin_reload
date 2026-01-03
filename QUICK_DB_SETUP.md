# 🚀 Quick Database Setup - 2 Minutes

## Step 1: Install Dependencies (10 seconds)
```bash
npm install
```

## Step 2: Test Connection (20 seconds)

### Option A: Export Variable (Quick Test)
```bash
export DATABASE_URL="postgresql://postgres:PASSWORD@HOST.proxy.rlwy.net:PORT/railway"
npm run db:test
```

### Option B: Create .env File (Recommended)
```bash
# Create .env file
cat > .env << 'EOF'
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@YOUR_HOST.proxy.rlwy.net:YOUR_PORT/railway
EOF

# Test connection
npm run db:test
```

**Get your DATABASE_URL from:**
- Railway Dashboard → Your Project → PostgreSQL → Connect → "Postgres Connection URL"

## Step 3: Create Tables (30 seconds)
```bash
npm run db:create
```

**Done! ✅**

---

## 📊 Expected Output

### Test Connection (`npm run db:test`):
```
🧪 Database Connection Test
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔧 Environment: Local 💻
🔗 Connection: External (SSL)
🌐 Host: postgresql://postgres:****@hopper.proxy.rlwy.net:25708/railway

🔄 Connecting...
✅ Connection successful!

⏰ Server time: 2025-12-19 10:30:00
🐘 PostgreSQL: PostgreSQL 15.3
💾 Database: railway

📊 Checking existing tables...
⚠️  No tables found. Run: npm run db:create

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 All checks passed! Database is ready.
```

### Create Tables (`npm run db:create`):
```
🔧 Environment: Local
🔗 Connection: External (SSL)
🌐 Database: postgresql://postgres:****@hopper.proxy.rlwy.net:25708/railway

🔄 Connecting to PostgreSQL database...
✅ Connected successfully!
⏰ Server time: 2025-12-19 10:30:15
🐘 PostgreSQL: PostgreSQL 15.3

📋 Creating table 'users'...
✅ Table 'users' ready
📋 Creating table 'refresh_tokens'...
✅ Table 'refresh_tokens' ready
📋 Creating table 'subscriptions'...
✅ Table 'subscriptions' ready
📋 Creating table 'workouts'...
✅ Table 'workouts' ready
📋 Creating table 'daily_usage'...
✅ Table 'daily_usage' ready

🎉 SUCCESS! All tables created/verified!

📊 Tables in database:
   - daily_usage
   - refresh_tokens
   - subscriptions
   - users
   - workouts

🔌 Connection closed
```

---

## 🔧 Common Issues & Fixes

### ❌ "DATABASE_URL not set!"
```bash
# Create .env file
echo 'DATABASE_URL=postgresql://postgres:PASSWORD@HOST:PORT/railway' > .env
```

### ❌ "Connection refused" or "ENOTFOUND"
- ✅ Check Railway dashboard for correct host/port
- ✅ Verify you have internet connection
- ✅ Copy fresh connection URL from Railway

### ❌ "SSL handshake error"
**On Railway deployment:** Railway will auto-use `DATABASE_PRIVATE_URL` (no SSL)  
**Locally:** Use `DATABASE_URL` from Railway's public proxy (script handles SSL automatically)

### ❌ "Password authentication failed"
- ✅ Copy fresh connection string from Railway dashboard
- ✅ Password may have been rotated
- ✅ Check for typos in connection string

---

## 🎯 NPM Scripts Available

```bash
npm run db:test    # Test database connection (doesn't create tables)
npm run db:create  # Create all tables (safe to run multiple times)
npm run db:setup   # Alias for db:create
```

---

## 🏗️ Tables Created

1. **users** - User accounts (email, OAuth providers)
2. **refresh_tokens** - JWT refresh token storage
3. **subscriptions** - Stripe subscription tracking
4. **workouts** - User workout history
5. **daily_usage** - Daily app usage tracking

All tables use `ON DELETE CASCADE` for automatic cleanup.

---

## 🚀 Railway Deployment (Automatic)

When deploying to Railway, **no setup needed!** The script:
- ✅ Auto-detects Railway environment
- ✅ Uses `DATABASE_PRIVATE_URL` (preferred, no SSL)
- ✅ Falls back to `DATABASE_URL` (SSL) if needed
- ✅ No .env file required

Just run in your Railway service:
```bash
node create_all_tables.js
```

Or add to your `package.json` build/deploy scripts.

---

## 📚 Full Documentation

- **DATABASE_SETUP_GUIDE.md** - Complete setup guide with troubleshooting
- **create_all_tables.js** - Main table creation script
- **test-db-connection.js** - Connection test utility

---

## ✅ Verification

After running `npm run db:create`, verify with:

```bash
# Option 1: Via Railway CLI
railway connect postgres
\dt

# Option 2: Direct query
psql "$DATABASE_URL" -c "\dt"

# Option 3: Count tables
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
```

Should show 5 tables: `users`, `refresh_tokens`, `subscriptions`, `workouts`, `daily_usage`

---

**Questions? See DATABASE_SETUP_GUIDE.md for detailed troubleshooting.**













