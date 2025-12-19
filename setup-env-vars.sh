#!/bin/bash

echo "🔧 Setting up Railway Environment Variables for PUSHIN' Backend"
echo "============================================================"

# Check if in backend directory or railway project
if [ ! -f "server.js" ]; then
    echo "❌ Please run this script from the backend directory"
    echo "   cd backend && ../setup-env-vars.sh"
    exit 1
fi

# Check if Railway CLI is available
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found."
    exit 1
fi

echo "Setting NODE_ENV..."
railway variables set NODE_ENV=production

echo ""
echo "📝 You'll need to get these values from your Stripe Dashboard:"
echo "   https://dashboard.stripe.com/test/apikeys"
echo "   https://dashboard.stripe.com/test/products"
echo ""
echo "Enter your Stripe Test Secret Key (sk_test_...):"
read -s STRIPE_SECRET_KEY
railway variables set STRIPE_SECRET_KEY="$STRIPE_SECRET_KEY"

echo ""
echo "Enter your Standard Plan Price ID (price_test_...):"
read STRIPE_PRICE_STANDARD
railway variables set STRIPE_PRICE_STANDARD="$STRIPE_PRICE_STANDARD"

echo ""
echo "Enter your Advanced Plan Price ID (price_test_...):"
read STRIPE_PRICE_ADVANCED
railway variables set STRIPE_PRICE_ADVANCED="$STRIPE_PRICE_ADVANCED"

echo ""
echo "🔐 Setting up webhook (optional but recommended):"
echo "   Go to: https://dashboard.stripe.com/test/webhooks"
echo "   Create webhook for: $(railway domain)/api/stripe/webhook"
echo "   Select events: checkout.session.completed, customer.subscription.*"
echo ""
echo "Enter your webhook signing secret (whsec_test_...) or press Enter to skip:"
read STRIPE_WEBHOOK_SECRET
if [ ! -z "$STRIPE_WEBHOOK_SECRET" ]; then
    railway variables set STRIPE_WEBHOOK_SECRET="$STRIPE_WEBHOOK_SECRET"
fi

echo ""
echo "✅ Environment variables configured!"
echo ""
echo "Next: Test your deployment:"
echo "  curl $(railway domain)/api/health"





