require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const authRoutes = require('./authRoutes');

// Use test key if in test mode, otherwise use live key
const stripeSecretKey = process.env.NODE_ENV === 'test'
  ? process.env.STRIPE_TEST_SECRET_KEY || 'sk_test_YOUR_TEST_KEY_HERE'
  : process.env.STRIPE_SECRET_KEY;

const stripe = require('stripe')(stripeSecretKey);
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();

// PostgreSQL connection - Always use Railway's DATABASE_URL
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

// Test database connection on startup
pool.connect()
  .then(client => {
    console.log("✅ Connected to PostgreSQL");
    client.release();
  })
  .catch(err => {
    console.error("❌ PostgreSQL connection error:", err);
  });

// Authentication configuration is now handled in auth.js module

// CORS - Allow Flutter app and web app to call API
const allowedOrigins = [
  'http://localhost:3000',    // Development
  'http://localhost:8080',    // Development
  'capacitor://localhost',    // Capacitor dev
  'ionic://localhost',        // Ionic dev
  'http://10.0.2.2:*',        // Android emulator
  'http://192.168.*.*:*',     // Local network
];

if (process.env.NODE_ENV === 'production') {
  // Add your production domains here
  allowedOrigins.push(
    'https://pushinapp.com',
    'https://www.pushinapp.com',
  );
}

app.use(cors({
  origin: function (origin, callback) {
    // Allow requests with no origin (mobile apps, Postman, etc.)
    if (!origin) return callback(null, true);

    if (allowedOrigins.some(allowed => {
      if (allowed.includes('*')) {
        return origin.match(allowed.replace('*', '.*'));
      }
      return origin === allowed;
    })) {
      return callback(null, true);
    }

    return callback(new Error('Not allowed by CORS'));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  credentials: true,
}));

// JSON parser for most routes
app.use(express.json());

// Initialize database tables
async function initDatabase() {
  try {
    console.log('🔄 Attempting database connection and table initialization...');

    // Test connection first
    const client = await pool.connect();
    console.log('✅ Database connection successful');
    client.release();

    // Create users table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255),
        apple_id VARCHAR(255) UNIQUE,
        google_id VARCHAR(255) UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create refresh tokens table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        token VARCHAR(500) UNIQUE NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create subscriptions table for Stripe
    await pool.query(`
      CREATE TABLE IF NOT EXISTS subscriptions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        customer_id VARCHAR(255),
        subscription_id VARCHAR(255) UNIQUE,
        plan_id VARCHAR(50),
        current_period_end TIMESTAMP,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    console.log('✅ Database connected and tables initialized');
  } catch (error) {
    console.error('❌ Database initialization error:', error);
    console.error('❌ Error details:', {
      message: error.message,
      code: error.code,
      errno: error.errno,
      syscall: error.syscall,
      hostname: error.hostname,
      host: error.host,
      port: error.port
    });

    // If it's a connection error, suggest Railway configuration
    if (error.code === 'ECONNREFUSED') {
      console.error('💡 This looks like a Railway PostgreSQL connection issue.');
      console.error('💡 Make sure DATABASE_URL is set in Railway service variables.');
      console.error('💡 Railway should provide DATABASE_URL automatically from your PostgreSQL service.');
    }
  }
}

// Authentication middleware and functions are now in authRoutes.js

// Initialize database on startup
initDatabase();

// ===========================
// AUTHENTICATION ROUTES
// ===========================

// Make pool available to auth routes
app.locals.pool = pool;

// Mount authentication routes
app.use('/api/auth', authRoutes);

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
    const { userId, planId, billingPeriod, userEmail, successUrl, cancelUrl } = req.body;

    console.log('Creating checkout session:', { userId, planId, billingPeriod, userEmail });

    // Validate inputs
    if (!userId || !planId || !userEmail) {
      return res.status(400).json({
        error: 'Missing required fields: userId, planId, userEmail'
      });
    }

    // Default billingPeriod to 'monthly' if not provided
    const period = billingPeriod || 'monthly';

    // Validate planId and billingPeriod
    if (!['pro', 'advanced'].includes(planId)) {
      return res.status(400).json({
        error: `Invalid plan ID: ${planId}. Must be 'pro' or 'advanced'`
      });
    }

    if (!['monthly', 'yearly'].includes(period)) {
      return res.status(400).json({
        error: `Invalid billing period: ${period}. Must be 'monthly' or 'yearly'`
      });
    }

    // Determine price ID based on plan and billing period (test or live mode)
    // Supports 4 combinations: pro_monthly, pro_yearly, advanced_monthly, advanced_yearly
    const priceIds = process.env.NODE_ENV === 'test' ? {
      'pro_monthly': process.env.STRIPE_TEST_PRICE_PRO_MONTHLY || 'price_test_pro_monthly_placeholder',
      'pro_yearly': process.env.STRIPE_TEST_PRICE_PRO_YEARLY || 'price_test_pro_yearly_placeholder',
      'advanced_monthly': process.env.STRIPE_TEST_PRICE_ADVANCED_MONTHLY || 'price_test_advanced_monthly_placeholder',
      'advanced_yearly': process.env.STRIPE_TEST_PRICE_ADVANCED_YEARLY || 'price_test_advanced_yearly_placeholder',
    } : {
      'pro_monthly': process.env.STRIPE_PRICE_PRO_MONTHLY,
      'pro_yearly': process.env.STRIPE_PRICE_PRO_YEARLY,
      'advanced_monthly': process.env.STRIPE_PRICE_ADVANCED_MONTHLY,
      'advanced_yearly': process.env.STRIPE_PRICE_ADVANCED_YEARLY,
    };

    // Create planKey from planId and billingPeriod (e.g., "pro_monthly")
    const planKey = `${planId}_${period}`;
    const priceId = priceIds[planKey];

    if (!priceId) {
      return res.status(400).json({
        error: `Invalid plan/billing combination: ${planKey}. Check that STRIPE_PRICE_${planId.toUpperCase()}_${period.toUpperCase()} is set.`
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
        planId: planId,
        billingPeriod: period,
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

      // Store subscription in database
      await pool.query(
        `INSERT INTO subscriptions (user_id, customer_id, subscription_id, plan_id, current_period_end, is_active, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         ON CONFLICT (subscription_id)
         DO UPDATE SET
           plan_id = EXCLUDED.plan_id,
           current_period_end = EXCLUDED.current_period_end,
           is_active = EXCLUDED.is_active,
           updated_at = EXCLUDED.updated_at`,
        [userId, session.customer, subscription.id, session.metadata.planId,
         new Date(subscription.current_period_end * 1000), true, new Date()]
      );

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
    
    const subscriptionResult = await pool.query(
      'SELECT * FROM subscriptions WHERE user_id = $1 AND is_active = true ORDER BY updated_at DESC LIMIT 1',
      [userId]
    );

    if (subscriptionResult.rows.length === 0) {
      console.log('No subscription found');
      return res.json({
        isActive: false,
        planId: 'free',
        customerId: null,
        subscriptionId: null,
        currentPeriodEnd: null,
      });
    }

    const userData = subscriptionResult.rows[0];

    // Fetch latest subscription status from Stripe
    const subscription = await stripe.subscriptions.retrieve(userData.subscription_id);

    const isActive = subscription.status === 'active';

    // Update database with latest status
    await pool.query(
      'UPDATE subscriptions SET is_active = $1, current_period_end = $2, updated_at = $3 WHERE subscription_id = $4',
      [isActive, new Date(subscription.current_period_end * 1000), new Date(), userData.subscription_id]
    );

    console.log('Subscription status:', subscription.status);

    res.json({
      isActive,
      planId: userData.plan_id,
      customerId: userData.customer_id,
      subscriptionId: userData.subscription_id,
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

    // Update database to reflect cancellation
    await pool.query(
      'UPDATE subscriptions SET is_active = false, updated_at = $1 WHERE subscription_id = $2',
      [new Date(), subscriptionId]
    );

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
app.listen(PORT, async () => {
  console.log(`🚀 PUSHIN' API running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/api/health`);

  // Initialize database tables
  await initDatabase();
});

