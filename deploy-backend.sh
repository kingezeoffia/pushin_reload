#!/bin/bash

echo "🚀 PUSHIN' Backend Deployment to Railway"
echo "========================================"

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found."
    echo "Install with: brew install railway"
    echo "Or: npm install -g @railway/cli"
    exit 1
fi

# Check if logged in
echo "🔐 Checking Railway login..."
if ! railway status &> /dev/null; then
    echo "Please login to Railway:"
    railway login
fi

# Go to backend directory
cd backend

echo "📦 Deploying backend to Railway..."

# Initialize if not already done
if [ ! -f ".railway" ]; then
    echo "🏗️  Initializing Railway project..."
    railway init --name pushin-stripe-api-production
fi

# Deploy
echo "🚀 Deploying..."
railway up

# Get the domain
echo "🌐 Getting your backend URL..."
BACKEND_URL=$(railway domain)
echo "✅ Backend deployed at: $BACKEND_URL"

echo ""
echo "📋 NEXT STEPS:"
echo "=============="
echo "1. Set environment variables:"
echo "   railway variables set NODE_ENV=production"
echo "   railway variables set STRIPE_SECRET_KEY=sk_test_YOUR_KEY"
echo "   railway variables set STRIPE_PRICE_STANDARD=price_YOUR_STANDARD_ID"
echo "   railway variables set STRIPE_PRICE_ADVANCED=price_YOUR_ADVANCED_ID"
echo "   railway variables set STRIPE_WEBHOOK_SECRET=whsec_YOUR_SECRET"
echo ""
echo "2. Test health check:"
echo "   curl $BACKEND_URL/api/health"
echo ""
echo "3. Update Flutter app with:"
echo "   baseUrl: '$BACKEND_URL/api'"
echo ""
echo "🎉 Backend ready!"





