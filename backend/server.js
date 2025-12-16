const express = require('express');

// Use test key if in test mode, otherwise use live key
const stripeSecretKey = process.env.NODE_ENV === 'test'
  ? process.env.STRIPE_TEST_SECRET_KEY || 'sk_test_YOUR_TEST_KEY_HERE'
  : process.env.STRIPE_SECRET_KEY;

const stripe = require('stripe')(stripeSecretKey);
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();

// CORS - Allow Flutter app to call API
app.use(cors({
  origin: '*', // In production, restrict to your domain
  methods: ['GET', 'POST'],
}));

// JSON parser for most routes
app.use(bodyParser.json());

// In-memory user storage (REPLACE WITH DATABASE IN PRODUCTION)
const users = new Map();

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// 1. Create Checkout Session
app.post('/api/stripe/create-checkout-session', async (req, res) => {
  try {
    const { userId, planId, userEmail, successUrl, cancelUrl } = req.body;

    console.log('Creating checkout session:', { userId, planId, userEmail });

    // Validate inputs
    if (!userId || !planId || !userEmail) {
      return res.status(400).json({ 
        error: 'Missing required fields: userId, planId, userEmail' 
      });
    }

    // Determine price ID based on plan (test or live mode)
    const priceIds = process.env.NODE_ENV === 'test' ? {
      standard: process.env.STRIPE_TEST_PRICE_STANDARD || 'price_test_standard_placeholder',
      advanced: process.env.STRIPE_TEST_PRICE_ADVANCED || 'price_test_advanced_placeholder',
    } : {
      standard: process.env.STRIPE_PRICE_STANDARD,
      advanced: process.env.STRIPE_PRICE_ADVANCED,
    };

    const priceId = priceIds[planId];
    if (!priceId) {
      return res.status(400).json({ 
        error: `Invalid plan ID: ${planId}. Must be 'standard' or 'advanced'` 
      });
    }

    // Create Stripe Checkout session
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer_email: userEmail,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      success_url: successUrl,
      cancel_url: cancelUrl,
      metadata: {
        userId,
        planId,
      },
    });

    console.log('✅ Checkout session created:', session.id);

    res.json({
      checkoutUrl: session.url,
      sessionId: session.id,
    });
  } catch (error) {
    console.error('❌ Error creating checkout session:', error);
    res.status(500).json({ error: error.message });
  }
});

// 2. Verify Payment
app.post('/api/stripe/verify-payment', async (req, res) => {
  try {
    const { sessionId, userId } = req.body;

    console.log('Verifying payment:', { sessionId, userId });

    if (!sessionId || !userId) {
      return res.status(400).json({ 
        error: 'Missing required fields: sessionId, userId' 
      });
    }

    // Retrieve the checkout session from Stripe
    const session = await stripe.checkout.sessions.retrieve(sessionId, {
      expand: ['subscription'],
    });

    console.log('Session payment status:', session.payment_status);

    if (session.payment_status === 'paid') {
      const subscription = session.subscription;
      
      // Store subscription in your database (using Map for demo)
      users.set(userId, {
        customerId: session.customer,
        subscriptionId: subscription.id,
        planId: session.metadata.planId,
        currentPeriodEnd: new Date(subscription.current_period_end * 1000),
        isActive: true,
        updatedAt: new Date(),
      });

      console.log('✅ Payment verified and stored');

      res.json({
        isActive: true,
        planId: session.metadata.planId,
        customerId: session.customer,
        subscriptionId: subscription.id,
        currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
      });
    } else {
      console.log('⚠️ Payment not completed');
      res.json({
        isActive: false,
        planId: 'free',
        customerId: null,
        subscriptionId: null,
        currentPeriodEnd: null,
      });
    }
  } catch (error) {
    console.error('❌ Error verifying payment:', error);
    res.status(500).json({ error: error.message });
  }
});

// 3. Check Subscription Status
app.get('/api/stripe/subscription-status', async (req, res) => {
  try {
    const { userId } = req.query;
    
    console.log('Checking subscription status for:', userId);

    if (!userId) {
      return res.status(400).json({ error: 'Missing userId parameter' });
    }
    
    const userData = users.get(userId);
    if (!userData || !userData.subscriptionId) {
      console.log('No subscription found');
      return res.json({
        isActive: false,
        planId: 'free',
        customerId: null,
        subscriptionId: null,
        currentPeriodEnd: null,
      });
    }

    // Fetch latest subscription status from Stripe
    const subscription = await stripe.subscriptions.retrieve(userData.subscriptionId);
    
    const isActive = subscription.status === 'active';
    
    console.log('Subscription status:', subscription.status);

    res.json({
      isActive,
      planId: userData.planId,
      customerId: userData.customerId,
      subscriptionId: userData.subscriptionId,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
    });
  } catch (error) {
    console.error('❌ Error checking subscription:', error);
    res.status(500).json({ error: error.message });
  }
});

// 4. Cancel Subscription
app.post('/api/stripe/cancel-subscription', async (req, res) => {
  try {
    const { userId, subscriptionId } = req.body;

    console.log('Canceling subscription:', { userId, subscriptionId });

    if (!userId || !subscriptionId) {
      return res.status(400).json({ 
        error: 'Missing required fields: userId, subscriptionId' 
      });
    }

    // Cancel at period end (user keeps access until billing period ends)
    const subscription = await stripe.subscriptions.update(subscriptionId, {
      cancel_at_period_end: true,
    });

    console.log('✅ Subscription will cancel at period end');

    res.json({
      success: true,
      cancelAt: new Date(subscription.cancel_at * 1000).toISOString(),
    });
  } catch (error) {
    console.error('❌ Error canceling subscription:', error);
    res.status(500).json({ error: error.message });
  }
});

// 5. Webhook Handler (CRITICAL for production)
app.post('/api/stripe/webhook', 
  bodyParser.raw({ type: 'application/json' }), 
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    
    let event;
    
    try {
      event = stripe.webhooks.constructEvent(
        req.body,
        sig,
        process.env.STRIPE_WEBHOOK_SECRET
      );
      
      console.log('✅ Webhook signature verified:', event.type);
    } catch (err) {
      console.error('❌ Webhook signature verification failed:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // Handle different event types
    try {
      switch (event.type) {
        case 'checkout.session.completed':
          const session = event.data.object;
          console.log('💰 Checkout completed:', session.id);
          // Update user subscription in database
          break;
          
        case 'customer.subscription.created':
          const newSub = event.data.object;
          console.log('🆕 Subscription created:', newSub.id);
          break;
          
        case 'customer.subscription.updated':
          const updatedSub = event.data.object;
          console.log('🔄 Subscription updated:', updatedSub.id);
          // Update subscription status in database
          break;
          
        case 'customer.subscription.deleted':
          const deletedSub = event.data.object;
          console.log('❌ Subscription canceled:', deletedSub.id);
          // Mark subscription as inactive in database
          break;
          
        case 'invoice.payment_succeeded':
          const invoice = event.data.object;
          console.log('✅ Payment succeeded:', invoice.id);
          break;
          
        case 'invoice.payment_failed':
          const failedInvoice = event.data.object;
          console.log('⚠️ Payment failed:', failedInvoice.id);
          // Notify user
          break;
          
        default:
          console.log('Unhandled event type:', event.type);
      }

      res.json({ received: true });
    } catch (error) {
      console.error('Error processing webhook:', error);
      res.status(500).json({ error: 'Webhook processing failed' });
    }
  }
);

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 PUSHIN' Stripe API running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/api/health`);
});

