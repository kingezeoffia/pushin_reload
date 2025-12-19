#!/bin/bash

echo "📱 Updating Flutter App Configuration for Railway Backend"
echo "========================================================="

# Check if Railway CLI is available
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found."
    exit 1
fi

# Get the API URL
echo "🔗 Getting Railway API URL..."
API_URL=$(railway domain)

if [ -z "$API_URL" ]; then
    echo "❌ Could not get API URL from Railway."
    echo "   Make sure you're in the correct Railway project."
    echo ""
    echo "   Alternative: Enter your Railway domain manually:"
    read -p "   Railway domain (e.g., pushin-api-production.up.railway.app): " MANUAL_DOMAIN
    if [ ! -z "$MANUAL_DOMAIN" ]; then
        API_URL="https://$MANUAL_DOMAIN"
    else
        exit 1
    fi
fi

echo "🌐 Using API URL: $API_URL"
echo ""

# Update the Flutter service
FLUTTER_SERVICE="lib/services/StripeCheckoutService.dart"

if [ ! -f "$FLUTTER_SERVICE" ]; then
    echo "❌ Flutter service file not found: $FLUTTER_SERVICE"
    exit 1
fi

# Create backup
cp "$FLUTTER_SERVICE" "${FLUTTER_SERVICE}.backup"

# Update the baseUrl
sed -i.bak "s|https://pushin-production.up.railway.app/api|$API_URL/api|g" "$FLUTTER_SERVICE"

echo "✅ Updated Flutter app configuration:"
echo "   File: $FLUTTER_SERVICE"
echo "   API URL: $API_URL/api"
echo ""

# Test the health endpoint
echo "🧪 Testing updated configuration..."
HEALTH_RESPONSE=$(curl -s "$API_URL/api/health" 2>/dev/null)

if echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"'; then
    echo "✅ Backend connection successful!"
    echo "   Health check: OK"
else
    echo "⚠️  Backend health check failed - configuration updated but backend may not be ready"
    echo "   Test manually: curl $API_URL/api/health"
fi

echo ""
echo "🎯 NEXT STEPS:"
echo "=============="
echo "1. Run Flutter app and test payment flow"
echo ""
echo "2. Test with real Stripe checkout (use 4242 4242 4242 4242 for test card)"
echo ""
echo "3. Monitor Railway logs: railway logs"
echo ""
echo "4. If issues, check Flutter console for API errors"
echo ""
echo "📱 Flutter app is now configured for Railway backend!"




