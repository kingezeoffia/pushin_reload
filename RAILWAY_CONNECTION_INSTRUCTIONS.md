# Railway PostgreSQL Connection Instructions

## Local Development Setup

### 1. Set DATABASE_URL Environment Variable

For local development, use the **public proxy endpoint** with SSL:

```bash
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"
```

**URL Breakdown:**
- `postgresql://` - Protocol
- `postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM` - Username:Password
- `@hopper.proxy.rlwy.net:25708` - Public proxy host:port
- `/railway` - Database name

### 2. Test Connection with Node.js

Create and run a test script to verify connection:

```bash
node test-connection.js
```

Expected output:
```
🔄 Testing connection to Railway PostgreSQL...
✅ Connection successful!
📊 PostgreSQL version: 15.4
📋 Public tables count: 0
🔌 Connection closed
```

### 3. Create Database Tables

Once connection works, run your table creation script:

```bash
node create_all_tables.js
```

### Typical Errors & Fixes

**SSL Connection Error:**
- **Cause:** Railway requires SSL but certificates aren't configured properly
- **Fix:** Use the SSL configuration shown in Node.js pg SSL Configuration section below

**Connection Timeout:**
- **Cause:** Railway service may be paused or network issues
- **Fix:** Check Railway dashboard to ensure PostgreSQL service is running

**Database URL Format Error:**
- **Cause:** Incorrect URL format or missing components
- **Fix:** Double-check the DATABASE_URL format matches the example above

## Node.js pg SSL Configuration

### Required SSL Configuration for Railway Public Proxy

Railway's public proxy requires SSL with self-signed certificates. Use this configuration:

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    require: true,              // Force SSL connection
    rejectUnauthorized: false   // Allow Railway's self-signed certificates
  }
});
```

### Why This SSL Configuration is Required

- **`require: true`**: Forces SSL encryption for security (Railway mandates this for external connections)
- **`rejectUnauthorized: false`**: Allows self-signed certificates (Railway uses these instead of CA-signed certificates)

### Alternative SSL Configurations (if needed)

If the basic configuration fails, try these alternatives:

```javascript
// Option 1: More explicit SSL settings
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false,
    ca: null,
    cert: undefined,
    key: undefined
  }
});

// Option 2: Disable server identity check
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false,
    checkServerIdentity: () => undefined
  }
});
```

## Fallback Options

### Railway CLI Tunnel Method

If the public proxy fails, use Railway CLI tunnel for reliable local access:

#### Step 1: Install Railway CLI

```bash
curl -fsSL https://railway.app/install.sh | sh
```

#### Step 2: Login and Link to Project

```bash
railway login
railway link
```

#### Step 3: Create Tunnel

```bash
railway connect postgres
```

This creates a local tunnel on `localhost:5432`.

#### Step 4: Use Local Tunnel Connection

When tunnel is active, use this DATABASE_URL (no SSL needed):

```bash
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@localhost:5432/railway"
node create_all_tables.js
```

#### Step 5: Test Tunnel Connection

```bash
# In another terminal (tunnel must be running)
node test-connection.js
```

### Pgweb Alternative

Pgweb provides a web-based database browser:

```bash
# Install Pgweb
brew install pgweb  # macOS

# Connect to Railway database
pgweb --url "postgres://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway?sslmode=require"

# Or with Railway CLI tunnel active:
pgweb --url "postgres://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@localhost:5432/railway"
```

Access Pgweb at: http://localhost:8081

## Troubleshooting Checklist

### SSL Handshake Errors

**Error:** "There was an error establishing an SSL connection"

**Solutions:**
1. Verify SSL configuration in your Node.js code matches the example above
2. Check Node.js version (≥14 recommended for TLS 1.3 support)
3. Try alternative SSL configurations shown above
4. Test basic network connectivity: `ping hopper.proxy.rlwy.net`

### Connection Timeout / Connection Refused

**Error:** "Connection timeout" or "ECONNREFUSED"

**Solutions:**
1. Check Railway dashboard - ensure PostgreSQL service is running
2. Verify DATABASE_URL format is correct
3. Try different network (corporate firewalls may block Railway)
4. Use Railway CLI tunnel as fallback
5. Check if Railway service is paused (resume if needed)

### "No supported database found in service"

**Railway CLI Error**

**Solutions:**
```bash
railway logout
railway login
railway link  # Select correct project
railway services  # Should show your postgres service
```

### Internal Hostname Resolution Issues

**Error:** "postgres.railway.internal" not found

**Explanation:**
- `postgres.railway.internal:5432` only works within Railway infrastructure
- For local development, always use the public proxy: `hopper.proxy.rlwy.net:25708`
- Internal host provides better performance and no egress costs in production

### Environment Variable Issues

**Error:** "DATABASE_URL not set"

**Solution:**
```bash
echo $DATABASE_URL  # Verify it's set
# If not set, run the export command again
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"
```

## Verification Checklist

Use these steps to confirm successful connection:

### [ ] psql Connection Test

```bash
# Install psql if needed
brew install postgresql  # macOS

# Test connection
psql "$DATABASE_URL"

# In psql, run:
# \dt  # List tables
# SELECT version();  # Check PostgreSQL version
# \q  # Quit
```

**Expected:** Successful connection to database

### [ ] Node.js Test Script

```bash
node test-connection.js
```

**Expected output:**
```
🔄 Testing connection to Railway PostgreSQL...
✅ Connection successful!
📊 PostgreSQL version: 15.4
📋 Public tables count: X
🔌 Connection closed
```

### [ ] Table Creation Success

```bash
node create_all_tables.js
```

**Expected output:**
```
🔄 Connecting to PostgreSQL database...
✅ Connected to PostgreSQL
📋 Creating table 'users'…
✅ Created 'users'
📋 Creating table 'refresh_tokens'…
✅ Created 'refresh_tokens'
📋 Creating table 'subscriptions'…
✅ Created 'subscriptions'
📋 Creating table 'workouts'…
✅ Created 'workouts'
📋 Creating table 'daily_usage'…
✅ Created 'daily_usage'
🎉 All tables created!
🔌 Connection closed
```

### [ ] Railway Dashboard Verification

1. Go to Railway dashboard
2. Navigate to your PostgreSQL service
3. Open the "Query" tab
4. Run: `SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';`

**Expected:** See your 5 tables listed (users, refresh_tokens, subscriptions, workouts, daily_usage)

### [ ] Optional: Pgweb Browser Test

```bash
pgweb --url "$DATABASE_URL"
# Open http://localhost:8081
```

**Expected:** Web interface shows database tables and allows browsing data

---

## Production Deployment Notes

### Railway Internal Connection (Automatic)

When deployed on Railway, the platform automatically provides `DATABASE_URL` pointing to the internal host. Your code will work without changes:

```javascript
// This same code works in both local and production
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    require: true,
    rejectUnauthorized: false
  }
});
```

### Environment Variables in Railway

Railway automatically sets:
- `DATABASE_URL` - Full connection string
- `PGHOST` - Internal host
- `PGPORT` - Port (5432)
- `PGDATABASE` - Database name
- `PGUSER` - Username
- `PGPASSWORD` - Password

### Performance Benefits of Internal Connection

- No egress costs (data stays within Railway network)
- Lower latency
- Higher reliability
- Automatic SSL termination by Railway

---

## Quick Reference

### Essential Commands

```bash
# Local development setup
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"
node test-connection.js
node create_all_tables.js

# Fallback: Railway CLI tunnel
railway login && railway link && railway connect postgres
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@localhost:5432/railway"

# Test with psql
psql "$DATABASE_URL" -c "\dt"

# Debug SSL issues
node debug-connection.js
```

### Connection Summary

| Environment | Endpoint | SSL Required | When to Use |
|-------------|----------|--------------|-------------|
| Local Development | `hopper.proxy.rlwy.net:25708` | Yes | Development on local machine |
| Railway Production | `postgres.railway.internal:5432` | Yes | Deployed Railway applications |
| CLI Tunnel | `localhost:5432` | No | When public proxy fails |












