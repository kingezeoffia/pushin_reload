#!/bin/bash

echo "🚀 PUSHIN' Test Backend Deployment Script"
echo "========================================"

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found. Installing..."
    brew install railway
fi

# Check if logged in
echo "🔐 Checking Railway login..."
railway status > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Please login to Railway:"
    railway login
fi

# Go to backend directory
cd /Users/kingezeoffia/pushin_reload/backend

echo "📦 Deploying backend to Railway..."

# Initialize if not already done
if [ ! -f ".railway" ]; then
    echo "🏗️  Initializing Railway project..."
    railway init --name "pushin-test-backend"
fi

# Deploy
echo "🚀 Deploying..."
railway up

# Set environment variables
echo "🔧 Configuring environment variables..."
railway variables --set "NODE_ENV=test"
railway variables --set "STRIPE_TEST_SECRET_KEY=sk_test_YOUR_SECRET_KEY"

# Get the domain
echo "🌐 Getting your backend URL..."
BACKEND_URL=$(railway domain)
echo "✅ Backend deployed at: $BACKEND_URL"

echo ""
echo "📋 NEXT STEPS:"
echo "=============="
echo "1. Create test products in Stripe Dashboard:"
echo "   https://dashboard.stripe.com/test/products"
echo ""
echo "2. Set price IDs (replace YOUR_PRICE_IDs below):"
echo "   railway variables --set \"STRIPE_TEST_PRICE_STANDARD=price_test_YOUR_STANDARD_ID\""
echo "   railway variables --set \"STRIPE_TEST_PRICE_ADVANCED=price_test_YOUR_ADVANCED_ID\""
echo ""
echo "3. Update your Flutter app:"
echo "   baseUrl: '$BACKEND_URL/api'"
echo ""
echo "4. Test payment flow with card: 4242 4242 4242 4242"
echo ""
echo "🎉 Ready to test payments!"
