const express = require('express');
const { Pool } = require('pg');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const jwkToPem = require('jwk-to-pem');
const axios = require('axios');

// Use test key if in test mode, otherwise use live key
const stripeSecretKey = process.env.NODE_ENV === 'test'
  ? process.env.STRIPE_TEST_SECRET_KEY || 'sk_test_YOUR_TEST_KEY_HERE'
  : process.env.STRIPE_SECRET_KEY;

const stripe = require('stripe')(stripeSecretKey);
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();

// PostgreSQL connection
console.log('🔍 DATABASE_URL present:', !!process.env.DATABASE_URL);
console.log('🔍 DATABASE_URL starts with:', process.env.DATABASE_URL?.substring(0, 20) + '...');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false,
});

// Log successful database connection
pool.on('connect', () => {
  console.log('✅ Connected to Railway PostgreSQL database');
});

// Log connection errors
pool.on('error', (err) => {
  console.error('❌ Unexpected error on idle client:', err);
});

// JWT configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'your-super-secret-refresh-key-change-in-production';
const JWT_EXPIRES_IN = '15m'; // 15 minutes for access tokens
const JWT_REFRESH_EXPIRES_IN = '7d'; // 7 days for refresh tokens

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

// JWT Authentication Middleware
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({
      success: false,
      error: 'Access token required',
      code: 'TOKEN_MISSING'
    });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({
        success: false,
        error: 'Invalid or expired access token',
        code: 'TOKEN_INVALID'
      });
    }
    req.user = user;
    next();
  });
}

// Generate JWT tokens
function generateTokens(userId) {
  const accessToken = jwt.sign({ userId }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
  const refreshToken = jwt.sign({ userId }, JWT_REFRESH_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN });

  return { accessToken, refreshToken };
}

// Store refresh token in database
async function storeRefreshToken(userId, refreshToken) {
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

  await pool.query(
    'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
    [userId, refreshToken, expiresAt]
  );
}

// Remove refresh token from database
async function removeRefreshToken(token) {
  await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [token]);
}

// Initialize database on startup
initDatabase();

// ===========================
// AUTHENTICATION ENDPOINTS
// ===========================

// Register with email and password
app.post('/api/auth/register', async (req, res) => {
  try {
    console.log('Register request body:', req.body);
    const { email, password, name } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email and password are required',
        code: 'MISSING_FIELDS'
      });
    }

    // Check if user already exists
    const existingUser = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'User already exists with this email',
        code: 'USER_EXISTS'
      });
    }

    // Hash password
    const saltRounds = 12;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Create user
    const result = await pool.query(
      'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email, created_at',
      [email, passwordHash]
    );

    const user = result.rows[0];

    // Generate tokens
    const { accessToken, refreshToken } = generateTokens(user.id);

    // Store refresh token
    await storeRefreshToken(user.id, refreshToken);

    res.json({
      success: true,
      message: 'User registered successfully',
      data: {
        user: {
          id: user.id,
          email: user.email,
          createdAt: user.created_at
        },
        accessToken,
        refreshToken
      }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      error: 'Registration failed',
      code: 'REGISTRATION_ERROR'
    });
  }
});

// Login with email and password
app.post('/api/auth/login', async (req, res) => {
  try {
    console.log('Login request body:', req.body);
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email and password are required',
        code: 'MISSING_FIELDS'
      });
    }

    // Find user
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(401).json({
        success: false,
        error: 'Invalid email or password',
        code: 'INVALID_CREDENTIALS'
      });
    }

    const user = result.rows[0];

    // Check password
    if (!user.password_hash) {
      return res.status(401).json({
        success: false,
        error: 'Account registered with OAuth. Use Google or Apple sign in.',
        code: 'OAUTH_ONLY'
      });
    }

    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({
        success: false,
        error: 'Invalid email or password',
        code: 'INVALID_CREDENTIALS'
      });
    }

    // Generate tokens
    const { accessToken, refreshToken } = generateTokens(user.id);

    // Store refresh token (remove old ones first)
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [user.id]);
    await storeRefreshToken(user.id, refreshToken);

    res.json({
      success: true,
      message: 'Login successful',
      data: {
        user: {
          id: user.id,
          email: user.email,
          createdAt: user.created_at
        },
        accessToken,
        refreshToken
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      error: 'Login failed',
      code: 'LOGIN_ERROR'
    });
  }
});

// Google OAuth
app.post('/api/auth/google', async (req, res) => {
  try {
    const { idToken } = req.body;

    if (!idToken) {
      return res.status(400).json({
        success: false,
        error: 'Google ID token is required',
        code: 'MISSING_TOKEN'
      });
    }

    // Verify Google token
    const googleResponse = await axios.get(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);

    if (!googleResponse.data || !googleResponse.data.sub) {
      return res.status(401).json({
        success: false,
        error: 'Invalid Google token',
        code: 'INVALID_GOOGLE_TOKEN'
      });
    }

    const googleUser = googleResponse.data;
    const googleId = googleUser.sub;
    const email = googleUser.email;

    // Check if user exists with this Google ID
    let user = await pool.query('SELECT * FROM users WHERE google_id = $1', [googleId]);

    if (user.rows.length === 0) {
      // Check if user exists with this email (link accounts)
      const existingUser = await pool.query('SELECT * FROM users WHERE email = $1', [email]);

      if (existingUser.rows.length > 0) {
        // Link Google account to existing user
        await pool.query('UPDATE users SET google_id = $1 WHERE id = $2', [googleId, existingUser.rows[0].id]);
        user = await pool.query('SELECT * FROM users WHERE id = $1', [existingUser.rows[0].id]);
      } else {
        // Create new user
        const result = await pool.query(
          'INSERT INTO users (email, google_id) VALUES ($1, $2) RETURNING *',
          [email, googleId]
        );
        user = result;
      }
    }

    const userData = user.rows[0];

    // Generate tokens
    const { accessToken, refreshToken } = generateTokens(userData.id);

    // Store refresh token (remove old ones first)
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userData.id]);
    await storeRefreshToken(userData.id, refreshToken);

    res.json({
      success: true,
      message: 'Google authentication successful',
      data: {
        user: {
          id: userData.id,
          email: userData.email,
          createdAt: userData.created_at
        },
        accessToken,
        refreshToken
      }
    });
  } catch (error) {
    console.error('Google auth error:', error);
    res.status(500).json({
      success: false,
      error: 'Google authentication failed',
      code: 'GOOGLE_AUTH_ERROR'
    });
  }
});

// Apple Sign In
app.post('/api/auth/apple', async (req, res) => {
  try {
    const { identityToken, authorizationCode, user: appleUser } = req.body;

    if (!identityToken) {
      return res.status(400).json({
        success: false,
        error: 'Apple identity token is required',
        code: 'MISSING_TOKEN'
      });
    }

    // Decode Apple identity token to get user ID
    const tokenParts = identityToken.split('.');
    if (tokenParts.length !== 3) {
      return res.status(401).json({
        success: false,
        error: 'Invalid Apple token format',
        code: 'INVALID_APPLE_TOKEN'
      });
    }

    const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());

    if (!payload.sub) {
      return res.status(401).json({
        success: false,
        error: 'Invalid Apple token payload',
        code: 'INVALID_APPLE_TOKEN'
      });
    }

    const appleId = payload.sub;
    const email = payload.email || (appleUser && appleUser.email);

    if (!email) {
      return res.status(400).json({
        success: false,
        error: 'Email is required for Apple Sign In',
        code: 'MISSING_EMAIL'
      });
    }

    // Check if user exists with this Apple ID
    let user = await pool.query('SELECT * FROM users WHERE apple_id = $1', [appleId]);

    if (user.rows.length === 0) {
      // Check if user exists with this email (link accounts)
      const existingUser = await pool.query('SELECT * FROM users WHERE email = $1', [email]);

      if (existingUser.rows.length > 0) {
        // Link Apple account to existing user
        await pool.query('UPDATE users SET apple_id = $1 WHERE id = $2', [appleId, existingUser.rows[0].id]);
        user = await pool.query('SELECT * FROM users WHERE id = $1', [existingUser.rows[0].id]);
      } else {
        // Create new user
        const result = await pool.query(
          'INSERT INTO users (email, apple_id) VALUES ($1, $2) RETURNING *',
          [email, appleId]
        );
        user = result;
      }
    }

    const userData = user.rows[0];

    // Generate tokens
    const { accessToken, refreshToken } = generateTokens(userData.id);

    // Store refresh token (remove old ones first)
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userData.id]);
    await storeRefreshToken(userData.id, refreshToken);

    res.json({
      success: true,
      message: 'Apple authentication successful',
      data: {
        user: {
          id: userData.id,
          email: userData.email,
          createdAt: userData.created_at
        },
        accessToken,
        refreshToken
      }
    });
  } catch (error) {
    console.error('Apple auth error:', error);
    res.status(500).json({
      success: false,
      error: 'Apple authentication failed',
      code: 'APPLE_AUTH_ERROR'
    });
  }
});

// Refresh access token
app.post('/api/auth/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        error: 'Refresh token is required',
        code: 'MISSING_REFRESH_TOKEN'
      });
    }

    // Verify refresh token
    const decoded = jwt.verify(refreshToken, JWT_REFRESH_SECRET);

    // Check if refresh token exists in database
    const tokenResult = await pool.query(
      'SELECT * FROM refresh_tokens WHERE token = $1 AND expires_at > NOW()',
      [refreshToken]
    );

    if (tokenResult.rows.length === 0) {
      return res.status(403).json({
        success: false,
        error: 'Invalid or expired refresh token',
        code: 'INVALID_REFRESH_TOKEN'
      });
    }

    const userId = decoded.userId;

    // Generate new tokens
    const { accessToken, newRefreshToken } = generateTokens(userId);

    // Remove old refresh token and store new one
    await removeRefreshToken(refreshToken);
    await storeRefreshToken(userId, newRefreshToken);

    res.json({
      success: true,
      message: 'Token refreshed successfully',
      data: {
        accessToken,
        refreshToken: newRefreshToken
      }
    });
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(403).json({
      success: false,
      error: 'Token refresh failed',
      code: 'REFRESH_ERROR'
    });
  }
});

// Get current user profile
app.get('/api/auth/me', authenticateToken, async (req, res) => {
  try {
    const userResult = await pool.query(
      'SELECT id, email, created_at FROM users WHERE id = $1',
      [req.user.userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found',
        code: 'USER_NOT_FOUND'
      });
    }

    res.json({
      success: true,
      data: {
        user: userResult.rows[0]
      }
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get user data',
      code: 'GET_USER_ERROR'
    });
  }
});

// Logout (invalidate refresh tokens)
app.post('/api/auth/logout', authenticateToken, async (req, res) => {
  try {
    // Remove all refresh tokens for this user
    await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [req.user.userId]);

    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({
      success: false,
      error: 'Logout failed',
      code: 'LOGOUT_ERROR'
    });
  }
});

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
app.listen(PORT, async () => {
  console.log(`🚀 PUSHIN' API running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/api/health`);

  // Initialize database tables
  await initDatabase();
});

