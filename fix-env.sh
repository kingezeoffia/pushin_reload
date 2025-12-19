#!/bin/bash
# Quick .env fixer - Updates DATABASE_URL with correct public proxy URL

echo "🔧 Fix .env File with Correct Railway Public URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Step 1: Get your PUBLIC proxy URL"
echo "  → Open: https://railway.app/dashboard"
echo "  → Click: PUSHIN project"
echo "  → Click: PostgreSQL service"
echo "  → Click: 'Connect' tab"
echo "  → Copy: 'Postgres Connection URL'"
echo ""
echo "It should look like:"
echo "  postgresql://postgres:PASSWORD@XXXXX.proxy.rlwy.net:NNNNN/railway"
echo "  (Note: .proxy.rlwy.net is the key part!)"
echo ""
read -p "Paste your PUBLIC proxy URL here: " new_url

if [ -z "$new_url" ]; then
  echo "❌ No URL provided. Exiting."
  exit 1
fi

# Validate it's a public proxy URL
if [[ $new_url == *".railway.internal"* ]]; then
  echo ""
  echo "❌ ERROR: This is an INTERNAL URL - won't work locally!"
  echo "   You entered: $new_url"
  echo ""
  echo "   This only works when running INSIDE Railway's network."
  echo ""
  echo "   Please go back to Railway Dashboard and copy the"
  echo "   PUBLIC proxy URL (contains .proxy.rlwy.net)"
  exit 1
fi

if [[ $new_url != *"proxy.rlwy.net"* ]] && [[ $new_url != *"postgresql://"* ]]; then
  echo ""
  echo "⚠️  WARNING: This doesn't look like a Railway proxy URL"
  echo "   Expected format: postgresql://...@something.proxy.rlwy.net:PORT/railway"
  echo "   You entered: $new_url"
  echo ""
  read -p "Continue anyway? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 1
  fi
fi

# Backup old .env
if [ -f .env ]; then
  cp .env .env.backup
  echo "📦 Backed up old .env to .env.backup"
fi

# Create new .env
cat > .env << EOF
# Local Development Environment Variables
# Fixed with correct PUBLIC proxy URL

# Railway PostgreSQL Connection (PUBLIC PROXY for local dev)
DATABASE_URL=$new_url

# Note: On Railway deployment, these are auto-set:
# - DATABASE_PRIVATE_URL (preferred, internal network, no SSL)
# - DATABASE_URL (fallback, external proxy, SSL)
EOF

echo ""
echo "✅ .env file updated successfully!"
echo ""
echo "🧪 Test connection:"
echo "   npm run db:test"
echo ""
echo "🚀 Create tables:"
echo "   npm run db:create"
echo ""
