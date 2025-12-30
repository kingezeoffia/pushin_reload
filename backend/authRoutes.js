/**
 * Authentication Routes for Pushin Reload Backend
 * Express routes for user authentication endpoints
 */

const express = require('express');
const auth = require('./auth');

const router = express.Router();

/**
 * JWT Authentication Middleware
 * Verifies access token and adds user to request
 */
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

  const decoded = auth.verifyToken(token, auth.JWT_SECRET);
  if (!decoded) {
    return res.status(403).json({
      success: false,
      error: 'Invalid or expired access token',
      code: 'TOKEN_INVALID'
    });
  }

  req.user = decoded;
  next();
}

// ===========================
// AUTHENTICATION ENDPOINTS
// ===========================

/**
 * POST /api/auth/register
 * Register a new user with email and password
 */
router.post('/register', async (req, res) => {
  try {
    console.log('📝 Register request:', { email: req.body.email, name: req.body.name });

    const { email, password, name } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email and password are required',
        code: 'MISSING_FIELDS'
      });
    }

    // Get pool from app locals (set in main server.js)
    const pool = req.app.locals.pool;

    const result = await auth.registerUser(pool, email, password, name);

    console.log('✅ User registered successfully:', result.user.id);

    res.json({
      success: true,
      message: 'User registered successfully',
      data: result
    });
  } catch (error) {
    console.error('❌ Registration error:', error.message);

    if (error.message.includes('already exists')) {
      return res.status(409).json({
        success: false,
        error: 'User already exists with this email',
        code: 'USER_EXISTS'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Registration failed',
      code: 'REGISTRATION_ERROR'
    });
  }
});

/**
 * POST /api/auth/login
 * Login with email and password
 */
router.post('/login', async (req, res) => {
  try {
    console.log('🔐 Login request:', { email: req.body.email });

    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email and password are required',
        code: 'MISSING_FIELDS'
      });
    }

    const pool = req.app.locals.pool;
    const result = await auth.loginUser(pool, email, password);

    console.log('✅ User logged in successfully:', result.user.id);

    res.json({
      success: true,
      message: 'Login successful',
      data: result
    });
  } catch (error) {
    console.error('❌ Login error:', error.message);

    let statusCode = 500;
    let errorCode = 'LOGIN_ERROR';

    if (error.message.includes('Invalid email or password')) {
      statusCode = 401;
      errorCode = 'INVALID_CREDENTIALS';
    } else if (error.message.includes('OAuth')) {
      statusCode = 401;
      errorCode = 'OAUTH_ONLY';
    }

    res.status(statusCode).json({
      success: false,
      error: error.message,
      code: errorCode
    });
  }
});

/**
 * POST /api/auth/google
 * Login with Google OAuth
 */
router.post('/google', async (req, res) => {
  try {
    console.log('🔵 Google auth request');

    const { idToken } = req.body;

    if (!idToken) {
      return res.status(400).json({
        success: false,
        error: 'Google ID token is required',
        code: 'MISSING_TOKEN'
      });
    }

    const pool = req.app.locals.pool;
    const result = await auth.loginWithGoogle(pool, idToken);

    console.log('✅ Google authentication successful:', result.user.id);

    res.json({
      success: true,
      message: 'Google authentication successful',
      data: result
    });
  } catch (error) {
    console.error('❌ Google auth error:', error.message);

    let statusCode = 500;
    let errorCode = 'GOOGLE_AUTH_ERROR';

    if (error.message.includes('Invalid Google token')) {
      statusCode = 401;
      errorCode = 'INVALID_GOOGLE_TOKEN';
    }

    res.status(statusCode).json({
      success: false,
      error: error.message,
      code: errorCode
    });
  }
});

/**
 * POST /api/auth/apple
 * Login with Apple Sign In
 */
router.post('/apple', async (req, res) => {
  try {
    console.log('🍎 Apple auth request');

    const { identityToken, authorizationCode, user: appleUser } = req.body;

    if (!identityToken) {
      return res.status(400).json({
        success: false,
        error: 'Apple identity token is required',
        code: 'MISSING_TOKEN'
      });
    }

    const pool = req.app.locals.pool;
    const result = await auth.loginWithApple(pool, identityToken, appleUser);

    console.log('✅ Apple authentication successful:', result.user.id);

    res.json({
      success: true,
      message: 'Apple authentication successful',
      data: result
    });
  } catch (error) {
    console.error('❌ Apple auth error:', error.message);

    let statusCode = 500;
    let errorCode = 'APPLE_AUTH_ERROR';

    if (error.message.includes('Invalid Apple token') || error.message.includes('Email is required')) {
      statusCode = 400;
      errorCode = 'INVALID_APPLE_TOKEN';
    }

    res.status(statusCode).json({
      success: false,
      error: error.message,
      code: errorCode
    });
  }
});

/**
 * POST /api/auth/refresh
 * Refresh access token using refresh token
 */
router.post('/refresh', async (req, res) => {
  try {
    console.log('🔄 Token refresh request');

    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        error: 'Refresh token is required',
        code: 'MISSING_REFRESH_TOKEN'
      });
    }

    const pool = req.app.locals.pool;
    const result = await auth.refreshAccessToken(pool, refreshToken);

    console.log('✅ Token refreshed successfully');

    res.json({
      success: true,
      message: 'Token refreshed successfully',
      data: result
    });
  } catch (error) {
    console.error('❌ Token refresh error:', error.message);

    res.status(403).json({
      success: false,
      error: 'Token refresh failed',
      code: 'REFRESH_ERROR'
    });
  }
});

/**
 * GET /api/auth/me
 * Get current user profile
 */
router.get('/me', authenticateToken, async (req, res) => {
  try {
    console.log('👤 Get user profile request:', req.user.userId);

    const pool = req.app.locals.pool;
    const user = await auth.getUserProfile(pool, req.user.userId);

    res.json({
      success: true,
      data: {
        user
      }
    });
  } catch (error) {
    console.error('❌ Get user error:', error.message);

    res.status(500).json({
      success: false,
      error: 'Failed to get user data',
      code: 'GET_USER_ERROR'
    });
  }
});

/**
 * PUT /api/auth/me
 * Update current user profile
 */
router.put('/me', authenticateToken, async (req, res) => {
  try {
    console.log('✏️ Update user profile request:', req.user.userId);

    const { email, name, password } = req.body;
    const updates = {};

    // Validate and prepare updates
    if (email !== undefined) {
      if (!email || !email.includes('@')) {
        return res.status(400).json({
          success: false,
          error: 'Valid email is required',
          code: 'INVALID_EMAIL'
        });
      }
      updates.email = email;
    }

    if (name !== undefined) {
      if (typeof name !== 'string' || name.trim().length === 0) {
        return res.status(400).json({
          success: false,
          error: 'Valid name is required',
          code: 'INVALID_NAME'
        });
      }
      updates.firstname = name.trim();
    }

    if (password !== undefined) {
      if (!password || password.length < 6) {
        return res.status(400).json({
          success: false,
          error: 'Password must be at least 6 characters',
          code: 'INVALID_PASSWORD'
        });
      }
      updates.password = password;
    }

    if (Object.keys(updates).length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No valid fields to update',
        code: 'NO_UPDATES'
      });
    }

    const pool = req.app.locals.pool;
    const updatedUser = await auth.updateUserProfile(pool, req.user.userId, updates);

    console.log('✅ User profile updated successfully:', updatedUser.id);

    res.json({
      success: true,
      message: 'Profile updated successfully',
      data: {
        user: updatedUser
      }
    });
  } catch (error) {
    console.error('❌ Update user error:', error.message);

    let statusCode = 500;
    let errorCode = 'UPDATE_USER_ERROR';

    if (error.message.includes('already exists')) {
      statusCode = 409;
      errorCode = 'EMAIL_EXISTS';
    }

    res.status(statusCode).json({
      success: false,
      error: error.message,
      code: errorCode
    });
  }
});

/**
 * POST /api/auth/logout
 * Logout user (invalidate refresh tokens)
 */
router.post('/logout', authenticateToken, async (req, res) => {
  try {
    console.log('🚪 Logout request:', req.user.userId);

    const pool = req.app.locals.pool;
    await auth.logoutUser(pool, req.user.userId);

    console.log('✅ User logged out successfully');

    res.json({
      success: true,
      message: 'Logged out successfully'
    });
  } catch (error) {
    console.error('❌ Logout error:', error.message);

    res.status(500).json({
      success: false,
      error: 'Logout failed',
      code: 'LOGOUT_ERROR'
    });
  }
});

module.exports = router;













