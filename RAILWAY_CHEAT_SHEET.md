# 🚂 Railway Cheat Sheet for Pushin App

## 🎯 Quick Start (First Time Setup)

### 1. Install Railway CLI
```bash
curl -fsSL https://railway.app/install.sh | sh
railway login
```

### 2. Link Your Project
```bash
cd /Users/kingezeoffia/pushin_reload
railway link
# Select your PUSHIN project
```

### 3. Set Environment Variables
```bash
# In Railway Dashboard → Project → Variables tab
NODE_ENV=production
JWT_SECRET=your-super-secret-jwt-key-change-in-production-2025
JWT_REFRESH_SECRET=your-super-secret-refresh-key-change-in-production-2025

# Optional: Stripe variables for payments
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PRICE_STANDARD=price_...
STRIPE_PRICE_ADVANCED=price_...
```

---

## 🚀 Daily Development Workflow

### Deploy Code Changes
```bash
cd /Users/kingezeoffia/pushin_reload
railway up
```
**What it does:** Builds and deploys your backend to Railway servers

### Check Deployment Status
```bash
railway status
railway logs
```

### Test Your API
```bash
# Health check
curl https://pushin-production.up.railway.app/api/health

# Test auth (replace with real email)
curl -X POST https://pushin-production.up.railway.app/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

---

## 🔧 Troubleshooting

### Backend Not Responding?
```bash
# 1. Check if deployed
railway status

# 2. Check logs for errors
railway logs

# 3. Redeploy
railway up
```

### Auth Not Working?
```bash
# Check environment variables
curl https://pushin-production.up.railway.app/api/health
# Should show: "environment":"production"

# If it shows "test", fix in Railway Dashboard → Variables → NODE_ENV=production
```

### Database Issues?
```bash
# Test local database connection
cd backend && node test-db-connection.js

# Check Railway database status in Dashboard → PostgreSQL service
```

---

## 📊 Key Railway URLs & Services

- **App URL:** `https://pushin-production.up.railway.app`
- **API Base:** `https://pushin-production.up.railway.app/api`
- **Dashboard:** https://railway.app/dashboard
- **Project:** Your PUSHIN project in dashboard

---

## 🛠️ Useful Commands

```bash
# View all variables
railway variables

# Add a variable
railway variables set NEW_VAR=value

# View logs
railway logs

# Open in browser
railway open

# Get domain URL
railway domain
```

---

## 🚨 Emergency Fixes

### If Everything Breaks:
1. **Check Railway Dashboard** - Make sure services are running
2. **Redeploy:** `railway up`
3. **Check logs:** `railway logs`
4. **Verify variables** in Dashboard → Variables tab

### If Auth Still Fails:
1. Confirm `NODE_ENV=production`
2. Confirm JWT secrets are set
3. Check database connectivity
4. Redeploy

---

## 💡 Pro Tips

- **Always check health endpoint** after deployment
- **NODE_ENV must be "production"** for auth to work
- **Redeploy after changing variables** in Railway Dashboard
- **Use Railway Dashboard** for visual monitoring
- **Check logs immediately** if something breaks

---

## 🎯 Flutter Testing

After Railway deployment:
```bash
cd /Users/kingezeoffia/pushin_reload
flutter run
```
Test account creation - should work instantly!

---

**Remember:** Railway handles scaling, SSL, and infrastructure. Focus on your code! 🚀
