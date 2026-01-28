// Must be set before any TLS connections
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

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
const rateLimit = require('express-rate-limit');

const app = express();

// PostgreSQL connection
const tls = require('tls');
const dbUrl = process.env.DATABASE_URL || '';
const isLocal = dbUrl.includes('localhost') || dbUrl.includes('127.0.0.1');
const isRailwayInternal = dbUrl.includes('.railway.internal');

// Strip sslmode from URL to avoid conflicts
const cleanDbUrl = dbUrl.replace(/\?sslmode=[^&]*/, '').replace(/&sslmode=[^&]*/, '');

const pool = new Pool({
  connectionString: cleanDbUrl,
  // Disable SSL for local and Railway internal connections
  ssl: (isLocal || isRailwayInternal) ? false : {
    rejectUnauthorized: false,
    // Force TLS 1.2 minimum
    minVersion: 'TLSv1.2',
    maxVersion: 'TLSv1.3',
  },
  // Connection pool settings for Railway
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000, // How long a client can be idle before being closed
  connectionTimeoutMillis: 10000, // How long to wait when connecting
  // Keep alive settings
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
});

console.log('🔗 DB URL pattern:', cleanDbUrl.replace(/:[^:@]+@/, ':****@'));
console.log('🔒 SSL:', (isLocal || isRailwayInternal) ? 'disabled (local or Railway internal)' : 'TLSv1.2-1.3, rejectUnauthorized=false');

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

    // Create anonymous subscriptions table for guest users
    await pool.query(`
      CREATE TABLE IF NOT EXISTS anonymous_subscriptions (
        id SERIAL PRIMARY KEY,
        anonymous_id VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) NOT NULL,
        customer_id VARCHAR(255),
        subscription_id VARCHAR(255) UNIQUE,
        plan_id VARCHAR(50),
        current_period_end TIMESTAMP,
        is_active BOOLEAN DEFAULT true,
        linked_user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        recovery_token VARCHAR(255),
        recovery_expires_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create indexes for anonymous subscriptions
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_anonymous_subscriptions_email ON anonymous_subscriptions(email);
      CREATE INDEX IF NOT EXISTS idx_anonymous_subscriptions_recovery_token ON anonymous_subscriptions(recovery_token);
      CREATE INDEX IF NOT EXISTS idx_anonymous_subscriptions_linked_user ON anonymous_subscriptions(linked_user_id);
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
    console.log('📦 Raw request body:', JSON.stringify(req.body));
    const { userId, planId, billingPeriod, userEmail, anonymousId, successUrl, cancelUrl } = req.body;

    console.log('Creating checkout session:', { userId, planId, billingPeriod, userEmail, anonymousId, successUrl, cancelUrl });

    // Validate inputs - either userId or anonymousId must be provided
    if ((!userId && !anonymousId) || !planId || !userEmail) {
      console.log('❌ Validation failed:', { userId, anonymousId, planId, userEmail });
      return res.status(400).json({
        error: 'Missing required fields: either userId or anonymousId, planId, userEmail'
      });
    }

    console.log('✅ Validation passed');

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

    console.log('🔵 About to create Stripe session with priceId:', priceId);

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
        userId: userId || null,
        anonymousId: anonymousId || null,
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
    console.error('Error details:', error.message, error.stack);
    res.status(500).json({ error: error.message });
  }
});

// 2. Verify Payment
app.post('/api/stripe/verify-payment', async (req, res) => {
  try {
    const { sessionId, userId, anonymousId } = req.body;

    console.log('Verifying payment:', { sessionId, userId, anonymousId });

    if (!sessionId || (!userId && !anonymousId)) {
      return res.status(400).json({
        error: 'Missing required fields: sessionId and either userId or anonymousId'
      });
    }

    // Retrieve the checkout session from Stripe
    const session = await stripe.checkout.sessions.retrieve(sessionId, {
      expand: ['subscription'],
    });

    console.log('Session payment status:', session.payment_status);

    if (session.payment_status === 'paid') {
      const subscription = session.subscription;
      const isAnonymous = !userId && anonymousId;

      // Store subscription in appropriate table
      if (isAnonymous) {
        // Generate recovery token for anonymous subscription
        const crypto = require('crypto');
        const recoveryToken = crypto.randomBytes(32).toString('hex');

        await pool.query(
          `INSERT INTO anonymous_subscriptions (anonymous_id, email, customer_id, subscription_id, plan_id, current_period_end, is_active, recovery_token, recovery_expires_at, updated_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (subscription_id)
           DO UPDATE SET
             plan_id = EXCLUDED.plan_id,
             current_period_end = EXCLUDED.current_period_end,
             is_active = EXCLUDED.is_active,
             updated_at = EXCLUDED.updated_at`,
          [anonymousId, session.customer_details.email, session.customer, subscription.id, session.metadata.planId,
           new Date(subscription.current_period_end * 1000), true, recoveryToken,
           new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), new Date()] // 1 year expiry
        );
      } else {
        // Regular authenticated subscription
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
      }

      console.log(`✅ Payment verified and stored ${isAnonymous ? '(anonymous)' : '(authenticated)'}`);

      res.json({
        isActive: true,
        planId: session.metadata.planId,
        customerId: session.customer,
        subscriptionId: subscription.id,
        currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
        isAnonymous: isAnonymous,
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
    const { userId, anonymousId } = req.query;

    console.log('Checking subscription status for:', { userId, anonymousId });

    if (!userId && !anonymousId) {
      return res.status(400).json({ error: 'Missing userId or anonymousId parameter' });
    }

    let subscriptionResult;
    let isAnonymous = false;

    if (userId) {
      // Check authenticated user subscription
      subscriptionResult = await pool.query(
        'SELECT * FROM subscriptions WHERE user_id = $1 AND is_active = true ORDER BY updated_at DESC LIMIT 1',
        [userId]
      );
    } else {
      // Check anonymous subscription
      subscriptionResult = await pool.query(
        'SELECT * FROM anonymous_subscriptions WHERE anonymous_id = $1 AND is_active = true ORDER BY updated_at DESC LIMIT 1',
        [anonymousId]
      );
      isAnonymous = true;
    }

    if (subscriptionResult.rows.length === 0) {
      console.log('No subscription found');
      return res.json({
        isActive: false,
        planId: 'free',
        customerId: null,
        subscriptionId: null,
        currentPeriodEnd: null,
        isAnonymous: isAnonymous,
      });
    }

    const subscriptionData = subscriptionResult.rows[0];

    // Fetch latest subscription status from Stripe
    const subscription = await stripe.subscriptions.retrieve(subscriptionData.subscription_id);

    const isActive = subscription.status === 'active';

    // Update database with latest status
    const tableName = isAnonymous ? 'anonymous_subscriptions' : 'subscriptions';
    await pool.query(
      `UPDATE ${tableName} SET is_active = $1, current_period_end = $2, updated_at = $3 WHERE subscription_id = $4`,
      [isActive, new Date(subscription.current_period_end * 1000), new Date(), subscriptionData.subscription_id]
    );

    console.log('Subscription status:', subscription.status);

    res.json({
      isActive,
      planId: subscriptionData.plan_id,
      customerId: subscriptionData.customer_id,
      subscriptionId: subscriptionData.subscription_id,
      currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
      isAnonymous: isAnonymous,
      recoveryToken: isAnonymous ? subscriptionData.recovery_token : null,
    });
  } catch (error) {
    console.error('❌ Error checking subscription:', error);
    res.status(500).json({ error: error.message });
  }
});

// 4. Cancel Subscription
app.post('/api/stripe/cancel-subscription', async (req, res) => {
  try {
    const { userId, anonymousId, subscriptionId } = req.body;

    console.log('Canceling subscription:', { userId, anonymousId, subscriptionId });

    if ((!userId && !anonymousId) || !subscriptionId) {
      return res.status(400).json({
        error: 'Missing required fields: either userId or anonymousId, and subscriptionId'
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

// 5. Link Anonymous Subscription to User Account
app.post('/api/stripe/link-anonymous-subscription', async (req, res) => {
  try {
    const { anonymousId, userId, email } = req.body;

    console.log('Linking anonymous subscription:', { anonymousId, userId, email });

    if (!anonymousId || !userId || !email) {
      return res.status(400).json({
        error: 'Missing required fields: anonymousId, userId, email'
      });
    }

    // Find the anonymous subscription
    const anonymousResult = await pool.query(
      'SELECT * FROM anonymous_subscriptions WHERE anonymous_id = $1 AND linked_user_id IS NULL',
      [anonymousId]
    );

    if (anonymousResult.rows.length === 0) {
      return res.status(404).json({
        error: 'Anonymous subscription not found or already linked'
      });
    }

    const anonymousSub = anonymousResult.rows[0];

    // Check if user already has an active subscription
    const existingSub = await pool.query(
      'SELECT * FROM subscriptions WHERE user_id = $1 AND is_active = true',
      [userId]
    );

    if (existingSub.rows.length > 0) {
      return res.status(409).json({
        error: 'User already has an active subscription'
      });
    }

    // Link the anonymous subscription to the user
    await pool.query(
      'UPDATE anonymous_subscriptions SET linked_user_id = $1, updated_at = $2 WHERE anonymous_id = $3',
      [userId, new Date(), anonymousId]
    );

    // Create a regular subscription record for the user
    await pool.query(
      `INSERT INTO subscriptions (user_id, customer_id, subscription_id, plan_id, current_period_end, is_active, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [userId, anonymousSub.customer_id, anonymousSub.subscription_id, anonymousSub.plan_id,
       anonymousSub.current_period_end, anonymousSub.is_active, anonymousSub.created_at, new Date()]
    );

    console.log('✅ Anonymous subscription linked to user account');

    res.json({
      success: true,
      subscriptionId: anonymousSub.subscription_id,
      planId: anonymousSub.plan_id,
    });
  } catch (error) {
    console.error('❌ Error linking anonymous subscription:', error);
    res.status(500).json({ error: error.message });
  }
});

// 6. Recover Anonymous Subscription by Recovery Token
app.get('/api/stripe/recover-anonymous-subscription', async (req, res) => {
  try {
    const { recoveryToken } = req.query;

    console.log('Recovering anonymous subscription with token:', recoveryToken?.substring(0, 8) + '...');

    if (!recoveryToken) {
      return res.status(400).json({ error: 'Missing recovery token' });
    }

    // Find anonymous subscription by recovery token
    const subscriptionResult = await pool.query(
      `SELECT anonymous_id, email, subscription_id, plan_id, current_period_end, is_active, recovery_expires_at
       FROM anonymous_subscriptions
       WHERE recovery_token = $1 AND recovery_expires_at > NOW() AND linked_user_id IS NULL`,
      [recoveryToken]
    );

    if (subscriptionResult.rows.length === 0) {
      return res.status(404).json({ error: 'Invalid or expired recovery token' });
    }

    const subscription = subscriptionResult.rows[0];

    // Check if subscription is still active
    const stripeSubscription = await stripe.subscriptions.retrieve(subscription.subscription_id);
    const isActive = stripeSubscription.status === 'active';

    if (!isActive) {
      return res.status(410).json({ error: 'Subscription is no longer active' });
    }

    console.log('✅ Anonymous subscription recovered');

    res.json({
      anonymousId: subscription.anonymous_id,
      email: subscription.email,
      subscriptionId: subscription.subscription_id,
      planId: subscription.plan_id,
      currentPeriodEnd: subscription.current_period_end.toISOString(),
      isActive: true,
    });
  } catch (error) {
    console.error('❌ Error recovering anonymous subscription:', error);
    res.status(500).json({ error: error.message });
  }
});

// Test endpoint to check if subscription tables are accessible
app.get('/api/stripe/test-tables', async (req, res) => {
  try {
    console.log('🧪 Testing database tables...');

    // Test subscriptions table
    const subsCount = await pool.query('SELECT COUNT(*) FROM subscriptions');
    console.log(`   - subscriptions table: ${subsCount.rows[0].count} records`);

    // Test anonymous_subscriptions table
    const anonCount = await pool.query('SELECT COUNT(*) FROM anonymous_subscriptions');
    console.log(`   - anonymous_subscriptions table: ${anonCount.rows[0].count} records`);

    res.json({
      success: true,
      tables: {
        subscriptions: parseInt(subsCount.rows[0].count),
        anonymous_subscriptions: parseInt(anonCount.rows[0].count)
      }
    });
  } catch (error) {
    console.error('❌ Table test error:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
      code: error.code
    });
  }
});

// 5. Restore Subscription by Email
// Rate limiting middleware for restore purchases (prevents email enumeration)
const restorePurchasesLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 5, // 5 attempts per window per IP
  message: {
    success: false,
    error: 'rate_limit_exceeded',
    message: 'Too many restore attempts. Please try again in 5 minutes.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.post('/api/stripe/restore-by-email', restorePurchasesLimiter, async (req, res) => {
  console.log('🚀 RESTORE ENDPOINT CALLED - START');
  console.log('   Request body:', req.body);
  try {
    const { email } = req.body;

    // Validate email
    if (!email || !email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
      console.log('❌ Invalid email:', email);
      return res.status(400).json({
        success: false,
        error: 'invalid_email',
        message: 'Please provide a valid email address.'
      });
    }

    console.log(`🔍 Restore request for email: ${email}`);

    // Search in both tables
    const authenticatedQuery = `
      SELECT s.*, u.email, 'authenticated' as subscription_type
      FROM subscriptions s
      INNER JOIN users u ON s.user_id = u.id
      WHERE u.email = $1 AND s.is_active = true
      ORDER BY s.updated_at DESC
      LIMIT 1
    `;

    const anonymousQuery = `
      SELECT *, 'anonymous' as subscription_type
      FROM anonymous_subscriptions
      WHERE email = $1 AND is_active = true AND linked_user_id IS NULL
      ORDER BY updated_at DESC
      LIMIT 1
    `;

    console.log('📊 Executing database queries...');
    let authenticatedResult, anonymousResult;
    try {
      [authenticatedResult, anonymousResult] = await Promise.all([
        pool.query(authenticatedQuery, [email.trim().toLowerCase()]),
        pool.query(anonymousQuery, [email.trim().toLowerCase()])
      ]);
      console.log('✅ Database queries completed');
      console.log(`   - Authenticated results: ${authenticatedResult.rows.length}`);
      console.log(`   - Anonymous results: ${anonymousResult.rows.length}`);
    } catch (dbError) {
      console.error('❌ Database query error:', dbError.message);
      console.error('   - Error code:', dbError.code);
      console.error('   - Error detail:', dbError.detail);
      throw dbError; // Re-throw to be caught by outer try-catch
    }

    // Collect all active subscriptions
    let allSubscriptions = [
      ...authenticatedResult.rows,
      ...anonymousResult.rows
    ];

    // If no active subscriptions found, check for expired ones
    if (allSubscriptions.length === 0) {
      console.log('📭 No active subscriptions found, checking for expired ones...');
      const expiredQuery = `
        SELECT s.plan_id, s.current_period_end, 'authenticated' as subscription_type
        FROM subscriptions s
        INNER JOIN users u ON s.user_id = u.id
        WHERE u.email = $1 AND s.is_active = false
        UNION ALL
        SELECT plan_id, current_period_end, 'anonymous' as subscription_type
        FROM anonymous_subscriptions
        WHERE email = $1 AND is_active = false AND linked_user_id IS NULL
        ORDER BY current_period_end DESC
        LIMIT 3
      `;

      const expiredResult = await pool.query(expiredQuery, [email.trim().toLowerCase()]);
      console.log(`   - Found ${expiredResult.rows.length} expired subscriptions`);

      return res.status(404).json({
        success: false,
        error: 'no_active_subscription',
        message: 'No active subscriptions found for this email address.',
        expiredSubscriptions: expiredResult.rows.map(row => ({
          planId: row.plan_id,
          expiredOn: row.current_period_end.toISOString()
        }))
      });
    }

    // Prioritize: authenticated over anonymous
    let selectedSubscription = allSubscriptions.find(sub => sub.subscription_type === 'authenticated')
                              || allSubscriptions[0];

    console.log(`💳 Found subscription - verifying with Stripe...`);
    console.log(`   - Subscription ID: ${selectedSubscription.subscription_id}`);
    console.log(`   - Type: ${selectedSubscription.subscription_type}`);

    // Verify with Stripe that subscription is still active
    try {
      const stripeSubscription = await stripe.subscriptions.retrieve(selectedSubscription.subscription_id);
      console.log('✅ Stripe verification completed');

      if (stripeSubscription.status !== 'active') {
        // Update database to reflect actual status
        const tableName = selectedSubscription.subscription_type === 'authenticated'
                         ? 'subscriptions'
                         : 'anonymous_subscriptions';
        await pool.query(
          `UPDATE ${tableName} SET is_active = false, updated_at = NOW() WHERE subscription_id = $1`,
          [selectedSubscription.subscription_id]
        );

        return res.status(404).json({
          success: false,
          error: 'subscription_inactive',
          message: 'This subscription is no longer active.',
          expiredOn: new Date(stripeSubscription.current_period_end * 1000).toISOString()
        });
      }

      // Update local database with latest info from Stripe
      const tableName = selectedSubscription.subscription_type === 'authenticated'
                       ? 'subscriptions'
                       : 'anonymous_subscriptions';
      await pool.query(
        `UPDATE ${tableName} SET current_period_end = $1, updated_at = NOW() WHERE subscription_id = $2`,
        [new Date(stripeSubscription.current_period_end * 1000), selectedSubscription.subscription_id]
      );

      console.log(`✅ Restored ${selectedSubscription.subscription_type} subscription for ${email}`);

      // Return subscription details
      res.json({
        success: true,
        subscription: {
          subscriptionId: selectedSubscription.subscription_id,
          planId: selectedSubscription.plan_id,
          customerId: selectedSubscription.customer_id,
          currentPeriodEnd: new Date(stripeSubscription.current_period_end * 1000).toISOString(),
          isActive: true,
          subscriptionType: selectedSubscription.subscription_type,
          userId: selectedSubscription.user_id ? selectedSubscription.user_id.toString() : null,
          anonymousId: selectedSubscription.anonymous_id || null
        }
      });

    } catch (stripeError) {
      console.error('❌ Stripe verification error:', stripeError);

      // If Stripe API fails, return cached data with warning
      return res.json({
        success: true,
        subscription: {
          subscriptionId: selectedSubscription.subscription_id,
          planId: selectedSubscription.plan_id,
          customerId: selectedSubscription.customer_id,
          currentPeriodEnd: selectedSubscription.current_period_end.toISOString(),
          isActive: true,
          subscriptionType: selectedSubscription.subscription_type,
          userId: selectedSubscription.user_id ? selectedSubscription.user_id.toString() : null,
          anonymousId: selectedSubscription.anonymous_id || null
        },
        warning: 'Unable to verify with Stripe. Using cached data.'
      });
    }

  } catch (error) {
    console.error('❌ Error restoring subscription by email:', error);
    console.error('   Error stack:', error.stack);
    console.error('   Error message:', error.message);
    console.error('   Error code:', error.code);
    res.status(500).json({
      success: false,
      error: 'server_error',
      message: 'Unable to process restore request. Please try again later.',
      debug: process.env.NODE_ENV === 'test' ? error.message : undefined
    });
  }
});

// 6. Webhook Handler (CRITICAL for production)
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

