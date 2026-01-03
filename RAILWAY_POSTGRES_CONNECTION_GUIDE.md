# Railway PostgreSQL Local Connection Guide

## 🚀 Quick Start (TL;DR)

```bash
# Set environment variable
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"

# Test connection
node test-connection.js

# Run your table creation script
node create_all_tables.js
```

---

## 📋 Connection Details Summary

| Parameter | Value |
|-----------|--------|
| **Public Proxy Host** | `hopper.proxy.rlwy.net:25708` |
| **Internal Host** | `postgres.railway.internal:5432` (Railway only) |
| **Database** | `railway` |
| **Username** | `postgres` |
| **Password** | `OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM` |

---

## 🔧 Local Development Setup

### Step 1: Set DATABASE_URL Environment Variable

**For your Railway setup, use the public proxy:**

```bash
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"
```

**Breakdown of the URL:**
- `postgresql://` - Protocol
- `postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM` - Username:Password
- `@hopper.proxy.rlwy.net:25708` - Public proxy host:port
- `/railway` - Database name

### Step 2: Test Connection with psql (Optional)

```bash
# Install psql if you don't have it
brew install postgresql  # macOS
# OR
sudo apt-get install postgresql-client  # Ubuntu

# Test connection
psql "$DATABASE_URL"
```

Expected output:
```sql
psql (15.4, server 15.4)
SSL connection (protocol: TLSv1.3, cipher: TLS_AES_256_GCM_SHA384, bits: 256, compression: off)
Type "help" for help.

railway=>
```

### Step 3: Run Your Table Creation Script

```bash
node create_all_tables.js
```

---

## 🟢 Node.js Configuration

Your `create_all_tables.js` already has the correct SSL configuration! Here's why it works:

```javascript
const pool = new Pool({
  connectionString,
  ssl: {
    require: true,              // Forces SSL connection
    rejectUnauthorized: false   // Allows Railway's self-signed certificates
  }
});
```

### Key SSL Settings Explained:

- **`require: true`** - Forces SSL encryption (Railway requires this)
- **`rejectUnauthorized: false`** - Allows self-signed certificates (Railway uses these)

### Alternative SSL Configuration (if needed):

```javascript
// Option 2: More explicit SSL config
const pool = new Pool({
  connectionString,
  ssl: {
    rejectUnauthorized: false,
    ca: null,  // Don't verify CA
    checkServerIdentity: () => undefined  // Skip hostname verification
  }
});
```

---

## 🔄 Public Proxy vs Internal Endpoint

| Endpoint Type | Usage | When to Use |
|---------------|--------|-------------|
| **Public Proxy** (`hopper.proxy.rlwy.net:25708`) | Local development, external connections | ✅ **Local machine development** |
| **Internal Host** (`postgres.railway.internal:5432`) | Railway services only | ✅ **Production/Railway deployment** |

### Important Notes:

- **Internal host only works within Railway infrastructure** - it won't resolve locally
- **Public proxy requires SSL** - always use `ssl: { require: true, rejectUnauthorized: false }`
- **Both use same credentials** - username, password, and database name are identical

---

## 🚨 Troubleshooting Public Proxy Issues

### Error: "SSL connection error" or "handshake failure"

**Try these solutions in order:**

1. **Verify DATABASE_URL format:**
   ```bash
   echo $DATABASE_URL
   # Should output: postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway
   ```

2. **Test basic connectivity:**
   ```bash
   ping hopper.proxy.rlwy.net
   # Should respond if network allows
   ```

3. **Check Railway service status:**
   - Go to Railway dashboard
   - Verify PostgreSQL service is running
   - Check if public proxy is enabled

4. **Try different SSL configuration:**
   ```javascript
   // In your script, try this SSL config:
   ssl: {
     require: true,
     rejectUnauthorized: false,
     // Add these if basic config fails:
     ca: undefined,
     cert: undefined,
     key: undefined
   }
   ```

5. **Check firewall/proxy settings:**
   - Corporate firewalls may block Railway's port
   - Try different networks (home vs work)

---

## 🔧 Fallback Options

### Option 1: Railway CLI Tunnel Method

If public proxy fails, use Railway CLI tunnel for reliable local access.

#### Step 1: Install Railway CLI

```bash
# Install Railway CLI
curl -fsSL https://railway.app/install.sh | sh

# Login to Railway
railway login
```

#### Step 2: Connect to Your Project

```bash
# Link to your Railway project
railway link

# List services to find your PostgreSQL
railway services

# Connect via tunnel (creates local proxy on localhost:5432)
railway connect postgres
```

#### Step 3: Use Local Tunnel Connection

When tunnel is active, use this DATABASE_URL:

```bash
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@localhost:5432/railway"
```

**Note:** No SSL needed with tunnel - Railway CLI handles encryption.

#### Step 4: Test Tunnel Connection

```bash
# In another terminal (tunnel must be running)
node test-connection.js
```

### Option 2: Pgweb - Web-based PostgreSQL Client

Pgweb provides a web interface to browse and query your database.

#### Install Pgweb

```bash
# macOS
brew install pgweb

# Linux
# Download from: https://github.com/sosedoff/pgweb/releases
# OR use Docker: docker run -p 8081:8081 sosedoff/pgweb
```

#### Connect with Pgweb

```bash
# Method 1: Direct connection string
pgweb --url "postgres://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway?sslmode=require"

# Method 2: Individual parameters
pgweb \
  --host hopper.proxy.rlwy.net \
  --port 25708 \
  --user postgres \
  --pass OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM \
  --db railway \
  --ssl-mode require

# Method 3: With Railway CLI Tunnel (if tunnel is active)
pgweb --url "postgres://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@localhost:5432/railway"
```

#### Access Pgweb

Open http://localhost:8081 in your browser. Pgweb will show:
- Database tables
- Query interface
- Table data viewer
- Schema information

#### Pgweb SSL Configuration

```bash
# If SSL handshake fails, try:
pgweb --url "postgres://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway?sslmode=require&sslcertmode=disable"
```

---

## 🔍 Troubleshooting Checklist

### ❌ SSL Handshake Errors

**Error:** "There was an error establishing an SSL connection"

**Diagnosis:**
```bash
# Test basic connectivity
ping hopper.proxy.rlwy.net

# Test SSL with openssl
openssl s_client -connect hopper.proxy.rlwy.net:25708 -servername hopper.proxy.rlwy.net
```

**Fixes:**
1. **Verify SSL config in Node.js:**
   ```javascript
   ssl: {
     require: true,              // Force SSL
     rejectUnauthorized: false   // Allow self-signed certs
   }
   ```

2. **Try different SSL modes:**
   ```javascript
   ssl: {
     rejectUnauthorized: false,
     ca: null,
     checkServerIdentity: () => undefined
   }
   ```

3. **Check Node.js version:** Requires Node.js ≥14 for TLS 1.3

### 🚫 "No supported database found in service"

**Railway CLI Error Diagnosis:**

```bash
# Check CLI version
railway --version

# List all projects
railway projects

# Link to correct project
railway link

# List services (should show postgres)
railway services
```

**Common fixes:**
- Run `railway logout && railway login`
- Ensure you're in the correct Railway project
- Update CLI: `curl -fsSL https://railway.app/install.sh | sh`

### ⏰ Public Proxy Timeouts

**Error:** Connection timeout or "connection refused"

**Diagnosis:**
```bash
# Test network connectivity
telnet hopper.proxy.rlwy.net 25708

# Check if Railway service is running
# Go to Railway dashboard → Your project → PostgreSQL service
```

**Possible causes & fixes:**
- **Railway service paused:** Check dashboard, resume if needed
- **Network firewall:** Try different network (home/office)
- **Corporate proxy:** Configure HTTP_PROXY if needed
- **Port blocked:** Verify port 25708 is accessible

### 🧪 Verification Steps

**Test with psql:**
```bash
# Install psql if needed
brew install postgresql  # macOS

# Test connection
psql "postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway?sslmode=require"

# List tables
\d
```

**Test with Node.js:**
```bash
node test-connection.js
```

**Test with Pgweb:**
```bash
pgweb --url "postgres://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway?sslmode=require"
# Open http://localhost:8081
```

### 🔄 Environment-Specific Configuration

**Local Development (Public Proxy):**
```bash
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"
```

**Railway Deployment (Internal):**
```javascript
// Railway automatically provides DATABASE_URL
// Or configure manually:
const pool = new Pool({
  host: 'postgres.railway.internal',
  port: 5432,
  database: 'railway',
  user: 'postgres',
  password: 'OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM',
  ssl: { require: true, rejectUnauthorized: false }
});
```

---

## ✅ Self-Test Checklist

Run these commands to verify everything works:

```bash
# 1. Set DATABASE_URL for local development
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"

# 2. Test basic connection with Node.js
node test-connection.js

# 3. Create tables
node create_all_tables.js

# 4. Verify tables exist with psql
psql "$DATABASE_URL" -c "\dt"

# 5. Test with Pgweb (optional)
pgweb --url "$DATABASE_URL"

# 6. Check Railway dashboard
# - Confirm PostgreSQL service is running
# - Check connection logs show successful connections
# - Verify public proxy endpoint is enabled
```

### Expected Results:

- ✅ `test-connection.js` outputs "Connection successful!"
- ✅ `create_all_tables.js` creates all tables without SSL errors
- ✅ `psql \dt` shows: users, refresh_tokens, subscriptions, workouts, daily_usage
- ✅ Pgweb loads at http://localhost:8081 and shows database contents
- ✅ Railway dashboard shows active connections in metrics

---

## 🏗️ Why This Setup Works (Railway Architecture)

### Why Internal Host Doesn't Work Locally

**Railway's internal network** (`postgres.railway.internal:5432`) only resolves within Railway's infrastructure. This hostname:
- ✅ Works in Railway deployments and other Railway services
- ❌ Doesn't resolve on local machines or external networks
- ✅ Provides better performance (no egress costs)
- ✅ More secure (internal network only)

### Why Public Proxy Requires SSL

**Railway enforces SSL** for external connections to ensure security:
- ✅ Public proxy (`hopper.proxy.rlwy.net:25708`) requires SSL
- ✅ Uses self-signed certificates (hence `rejectUnauthorized: false`)
- ✅ Protects data in transit over public internet

### Why SSL Handshake Can Fail

**Common SSL issues:**
- **Certificate validation:** Railway uses self-signed certs
- **TLS version mismatch:** Older Node.js versions may not support TLS 1.3
- **Network interference:** Corporate firewalls/proxy may interfere with SSL
- **Connection instability:** Railway proxy connections can drop under load

### Why Railway CLI Tunnel is Reliable

**CLI tunnel advantages:**
- ✅ Bypasses SSL configuration issues entirely
- ✅ Creates secure local proxy (`localhost:5432`)
- ✅ Handles authentication through Railway CLI
- ✅ Works reliably even with network restrictions

---

## 📖 Quick Reference

### Essential Commands

```bash
# Set DATABASE_URL for local development
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"

# Test connection
node test-connection.js

# Debug SSL issues
node debug-connection.js

# Create tables
node create_all_tables.js

# Test with psql
psql "$DATABASE_URL"

# Railway CLI tunnel (fallback)
railway login && railway link && railway connect postgres

# Test with Pgweb
pgweb --url "$DATABASE_URL"
```

### Node.js SSL Configuration (Required)

```javascript
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    require: true,              // Force SSL for Railway
    rejectUnauthorized: false   // Allow self-signed certificates
  }
});
```

### Environment Variables

```bash
# Local Development (Public Proxy)
export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"

# Railway Deployment (Internal) - Auto-provided
# DATABASE_URL is automatically set by Railway
```

### Common Error Solutions

| Error | Solution |
|-------|----------|
| SSL handshake error | `ssl: { require: true, rejectUnauthorized: false }` |
| No supported database | `railway logout && railway login && railway link` |
| Connection timeout | Check Railway dashboard + try CLI tunnel |
| Internal host not found | Use public proxy for local development |

---

## 🚀 Production Deployment Notes

When deploying to Railway, your app will automatically use the internal endpoint:

```javascript
// In production (Railway), use internal host
const pool = new Pool({
  host: 'postgres.railway.internal',
  port: 5432,
  database: 'railway',
  user: 'postgres',
  password: process.env.DATABASE_URL ? new URL(process.env.DATABASE_URL).password : 'OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM',
  ssl: {
    require: true,
    rejectUnauthorized: false
  }
});
```

The internal host provides better performance and doesn't count against egress limits.

---

## 📞 Need Help?

1. **Check Railway status:** https://railway.app/status
2. **Review Railway docs:** https://docs.railway.app/databases/postgresql
3. **Test with Railway CLI:** `railway connect postgres`
4. **Verify environment variables:** `echo $DATABASE_URL`

The test script `test-connection.js` will give you specific error messages to diagnose issues.












