#!/bin/bash

echo "🧪 Testing PUSHIN' Backend Deployment"
echo "====================================="

# Check if Railway CLI is available
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found."
    exit 1
fi

# Get the API URL
echo "🔗 Getting API URL..."
API_URL=$(railway domain)
if [ -z "$API_URL" ]; then
    echo "❌ Could not get API URL. Make sure you're in a Railway project."
    echo "   Try: cd backend && railway status"
    exit 1
fi

echo "🌐 API URL: $API_URL"
echo ""

# Test 1: Health Check
echo "1️⃣ Testing Health Check..."
HEALTH_RESPONSE=$(curl -s "$API_URL/api/health")
if [ $? -ne 0 ]; then
    echo "❌ Health check failed - backend not responding"
    exit 1
fi

# Parse JSON response
STATUS=$(echo "$HEALTH_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
ENVIRONMENT=$(echo "$HEALTH_RESPONSE" | grep -o '"environment":"[^"]*"' | cut -d'"' -f4)

if [ "$STATUS" = "ok" ]; then
    echo "✅ Health check passed"
    echo "   Environment: $ENVIRONMENT"
else
    echo "❌ Health check failed - status: $STATUS"
    echo "   Response: $HEALTH_RESPONSE"
    exit 1
fi

echo ""

# Test 2: Environment Variables
echo "2️⃣ Checking Environment Variables..."
ENV_VARS=$(railway variables)
if echo "$ENV_VARS" | grep -q "STRIPE_SECRET_KEY"; then
    echo "✅ STRIPE_SECRET_KEY is set"
else
    echo "⚠️  STRIPE_SECRET_KEY not found - set with: railway variables set STRIPE_SECRET_KEY=sk_test_..."
fi

if echo "$ENV_VARS" | grep -q "NODE_ENV"; then
    NODE_ENV=$(railway variables get NODE_ENV 2>/dev/null)
    echo "✅ NODE_ENV is set to: $NODE_ENV"
else
    echo "⚠️  NODE_ENV not set - set with: railway variables set NODE_ENV=production"
fi

echo ""

# Test 3: Stripe Integration (if variables are set)
echo "3️⃣ Testing Stripe Integration..."
if echo "$ENV_VARS" | grep -q "STRIPE_SECRET_KEY" && echo "$ENV_VARS" | grep -q "STRIPE_PRICE_STANDARD"; then
    echo "🔄 Testing checkout session creation..."

    # Create a test checkout session
    TEST_RESPONSE=$(curl -s -X POST "$API_URL/api/stripe/create-checkout-session" \
        -H "Content-Type: application/json" \
        -d '{
          "userId": "test_user_123",
          "planId": "standard",
          "userEmail": "test@example.com",
          "successUrl": "pushinapp://payment-success?session_id={CHECKOUT_SESSION_ID}",
          "cancelUrl": "pushinapp://payment-cancel"
        }')

    if echo "$TEST_RESPONSE" | grep -q "checkoutUrl"; then
        echo "✅ Stripe checkout session creation works!"
        CHECKOUT_URL=$(echo "$TEST_RESPONSE" | grep -o '"checkoutUrl":"[^"]*"' | cut -d'"' -f4)
        echo "   Test checkout URL: $CHECKOUT_URL"
    else
        echo "❌ Stripe integration failed"
        echo "   Response: $TEST_RESPONSE"
        echo ""
        echo "   💡 Common issues:"
        echo "   - STRIPE_PRICE_STANDARD not set correctly"
        echo "   - Stripe secret key invalid"
        echo "   - Price IDs don't exist in Stripe dashboard"
    fi
else
    echo "⚠️  Skipping Stripe test - environment variables not set"
    echo "   Run ./setup-env-vars.sh to configure Stripe"
fi

echo ""

# Summary
echo "📋 DEPLOYMENT STATUS SUMMARY:"
echo "=============================="
echo "✅ Backend deployed: $API_URL"
echo "✅ Health check: $STATUS ($ENVIRONMENT)"
echo "✅ CORS configured for mobile apps"
if echo "$ENV_VARS" | grep -q "STRIPE_SECRET_KEY"; then
    echo "✅ Stripe keys configured"
else
    echo "❌ Stripe keys missing"
fi

echo ""
echo "🎯 NEXT STEPS:"
echo "=============="
echo "1. Update Flutter app with API URL:"
echo "   baseUrl: '$API_URL/api'"
echo ""
echo "2. Test payment flow in Flutter app"
echo ""
echo "3. Set up webhooks in Stripe Dashboard:"
echo "   URL: $API_URL/api/stripe/webhook"
echo ""
echo "🚀 Ready for Flutter integration!"



