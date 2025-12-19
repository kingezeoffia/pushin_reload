# Database Setup Guide

Complete guide for creating tables locally and on Railway.

## 🚀 Quick Start

### Prerequisites
```bash
# Install dependencies
npm install
```

### Railway Setup (One-Time)

1. **Create PostgreSQL Database** (if not done):
   ```bash
   railway add --service postgresql
   ```

2. **Get Connection URLs** from Railway Dashboard:
   - Go to your Railway project
   - Click on PostgreSQL service
   - Copy `DATABASE_PRIVATE_URL` (for deployed apps)
   - Copy `DATABASE_URL` (for local development/testing)

3. **Set Environment Variables** in Railway:
   - Already auto-set by Railway for deployments
   - No manual configuration needed on Railway side

---

## 📋 Usage

### Option 1: Local Development (Recommended)

**Step 1:** Create `.env` file:
```bash
cp .env.example .env
```

**Step 2:** Edit `.env` with your Railway public proxy URL:
```env
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@YOUR_HOST.proxy.rlwy.net:YOUR_PORT/railway
```

**Step 3:** Run the script:
```bash
npm run db:create
# or
node create_all_tables.js
```

### Option 2: Export Environment Variable

```bash
export DATABASE_URL="postgresql://postgres:PASSWORD@HOST:PORT/railway"
node create_all_tables.js
```

### Option 3: One-Line Command

```bash
DATABASE_URL="postgresql://postgres:PASSWORD@HOST:PORT/railway" node create_all_tables.js
```

### Option 4: Railway CLI Tunnel (Alternative)

```bash
# Terminal 1: Create tunnel
railway connect postgres

# Terminal 2: Use local connection
export DATABASE_URL="postgresql://postgres:password@localhost:5432/railway"
node create_all_tables.js
```

---

## 🏗️ Railway Deployment

### Automatic Setup (No Action Needed)

When you deploy to Railway, the script automatically:
1. Detects Railway environment
2. Uses `DATABASE_PRIVATE_URL` (internal, no SSL) if available
3. Falls back to `DATABASE_URL` (external, SSL) if needed
4. Handles SSL configuration automatically

### Manual Deployment

```bash
# Deploy to Railway
railway up

# Run script on Railway
railway run node create_all_tables.js
```

---

## 📊 Tables Created

The script creates these tables in order:

1. **users** - User accounts (email, OAuth IDs)
2. **refresh_tokens** - JWT refresh tokens
3. **subscriptions** - Stripe subscription data
4. **workouts** - User workout records
5. **daily_usage** - App usage tracking

All tables have proper foreign key relationships and CASCADE deletes.

---

## 🔍 Troubleshooting

### Error: "DATABASE_URL not set!"

**Solution:**
```bash
# Create .env file with your connection string
echo 'DATABASE_URL=postgresql://...' > .env
```

### Error: "SSL connection failed" or "handshake error"

**Solutions:**

1. **Use Railway Private URL** (on Railway):
   ```bash
   # Railway sets this automatically
   echo $DATABASE_PRIVATE_URL
   ```

2. **Check SSL settings** (local):
   - The script uses `rejectUnauthorized: false` for Railway self-signed certs
   - This is correct and expected

3. **Verify connection string**:
   ```bash
   # Test connection with psql
   psql "$DATABASE_URL"
   ```

### Error: "Connection refused" or "ENOTFOUND"

**Check:**
- ✅ Host is correct (should be `*.proxy.rlwy.net` for external)
- ✅ Port is correct (typically 5-digit number)
- ✅ No typos in connection string

### Error: "Password authentication failed"

**Check:**
- ✅ Password in DATABASE_URL matches Railway dashboard
- ✅ User is `postgres`
- ✅ Database name is `railway`

### Script runs but tables not visible

**Verify with:**
```bash
# Option 1: Railway CLI
railway connect postgres
# Then in psql:
\dt

# Option 2: Direct connection
psql "$DATABASE_URL" -c "\dt"
```

---

## 🧪 Verification

### Check if tables exist:

```bash
# Via Railway CLI
railway connect postgres
# Then:
\dt

# Or one-liner
railway run psql \$DATABASE_URL -c "\\dt"
```

### Query tables directly:

```bash
# Check users table
railway run psql \$DATABASE_URL -c "SELECT COUNT(*) FROM users;"

# List all tables with row counts
railway run psql \$DATABASE_URL -c "
  SELECT schemaname, tablename 
  FROM pg_tables 
  WHERE schemaname = 'public';"
```

---

## 🔐 Security Notes

1. **Never commit `.env` file** to git (already in .gitignore)
2. **Never hardcode credentials** in scripts or commits
3. **Use Railway's automatic environment variables** in production
4. **Rotate credentials** if accidentally exposed

---

## 📞 Connection Modes

| Mode | When | SSL | Variable |
|------|------|-----|----------|
| **Railway Internal** | Deployed on Railway | ❌ No | `DATABASE_PRIVATE_URL` |
| **Railway External** | Local dev / external access | ✅ Yes | `DATABASE_URL` |
| **Railway Tunnel** | Local dev via CLI | ❌ No | Local `localhost:5432` |

---

## ✅ Success Output

When successful, you'll see:

```
🔧 Environment: Local
🔗 Connection: External (SSL)
🌐 Database: postgresql://postgres:****@hopper.proxy.rlwy.net:25708/railway

🔄 Connecting to PostgreSQL database...
✅ Connected successfully!
⏰ Server time: 2025-12-19 10:30:00
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

## 🎯 Next Steps

After tables are created:

1. ✅ Verify tables exist (see Verification section above)
2. ✅ Run your backend server locally
3. ✅ Deploy backend to Railway
4. ✅ Test API endpoints with database

---

## 📚 Additional Resources

- [Railway Docs - PostgreSQL](https://docs.railway.app/databases/postgresql)
- [Node.js pg Library](https://node-postgres.com/)
- [PostgreSQL Connection Strings](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING)
