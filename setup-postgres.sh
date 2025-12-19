#!/bin/bash

echo "🐘 Setting up PostgreSQL Database for PUSHIN' Backend"
echo "==================================================="

# Check if Railway CLI is available
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found."
    exit 1
fi

echo "📦 Adding PostgreSQL database to Railway project..."

# Add PostgreSQL plugin
railway add postgres

echo "⏳ Waiting for database to be ready..."
sleep 10

# Get database URL
echo "🔗 Getting database connection details..."
DB_URL=$(railway variables get DATABASE_URL)

if [ -z "$DB_URL" ]; then
    echo "❌ Could not get DATABASE_URL. Database might still be provisioning."
    echo "   Try again in a few minutes with: railway variables get DATABASE_URL"
    exit 1
fi

echo "✅ PostgreSQL database added!"
echo "📋 Database URL: $DB_URL"
echo ""
echo "📝 NEXT STEPS:"
echo "=============="
echo "1. Update server.js to use PostgreSQL instead of in-memory Map"
echo "2. Install database library: npm install pg"
echo "3. Create tables for users and subscriptions"
echo "4. Update all Map operations to use database queries"
echo ""
echo "Example migration needed in server.js:"
echo "  const { Client } = require('pg');"
echo "  const client = new Client({ connectionString: process.env.DATABASE_URL });"
echo ""
echo "⚠️  NOTE: Current MVP works with in-memory storage for testing"
echo "   Database migration is for production persistence only"




