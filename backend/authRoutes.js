/**
 * Authentication Routes for Pushin Reload Backend
 * Express routes for user authentication endpoints
 */

const express = require('express');
const rateLimit = require('express-rate-limit');
const auth = require('./auth');

const router = express.Router();

// Rate limiting for password reset endpoints
const forgotPasswordLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 requests per windowMs
  message: {
    success: false,
    error: 'Too many password reset attempts. Please try again later.',
    code: 'RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false,
  // Use IP + email combination for more sophisticated limiting
  keyGenerator: (req) => `${req.ip}:${req.body.email || 'unknown'}`,
  skip: (req) => !req.body.email // Don't rate limit malformed requests
});

const resetPasswordLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10, // Limit each IP to 10 reset attempts per windowMs
  message: {
    success: false,
    error: 'Too many password reset attempts. Please try again later.',
    code: 'RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

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

    // Validate password policy
    const passwordValidation = auth.validatePasswordPolicy(password);
    if (!passwordValidation.isValid) {
      return res.status(400).json({
        success: false,
        error: `Password does not meet security requirements: ${passwordValidation.errors.join(', ')}`,
        code: 'INVALID_PASSWORD_POLICY',
        violations: passwordValidation.errors
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

    console.error('📝 Registration error details:', {
      message: error.message,
      code: error.code,
      table: error.table,
      constraint: error.constraint
    });

    res.status(500).json({
      success: false,
      error: 'Registration failed',
      code: 'REGISTRATION_ERROR',
      details: error.message // Temporary for debugging
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
      if (!password) {
        return res.status(400).json({
          success: false,
          error: 'Password is required',
          code: 'MISSING_PASSWORD'
        });
      }

      // Validate password policy
      const passwordValidation = auth.validatePasswordPolicy(password);
      if (!passwordValidation.isValid) {
        return res.status(400).json({
          success: false,
          error: `Password does not meet security requirements: ${passwordValidation.errors.join(', ')}`,
          code: 'INVALID_PASSWORD_POLICY',
          violations: passwordValidation.errors
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

/**
 * POST /api/auth/forgot-password
 * Initiate password reset by sending email with reset token
 */
router.post('/forgot-password', forgotPasswordLimiter, async (req, res) => {
  try {
    console.log('🔑 Forgot password request:', { email: req.body.email });

    const { email } = req.body;

    if (!email || !email.includes('@')) {
      return res.status(400).json({
        success: false,
        error: 'Valid email is required',
        code: 'INVALID_EMAIL'
      });
    }

    const pool = req.app.locals.pool;
    const clientIp = req.ip || req.connection.remoteAddress || 'unknown';
    const userAgent = req.headers['user-agent'] || 'unknown';

    const result = await auth.initiatePasswordReset(pool, email, clientIp, userAgent);

    console.log('✅ Password reset initiated for:', email);

    res.json({
      success: true,
      message: 'Password reset email sent',
      data: result
    });
  } catch (error) {
    console.error('❌ Forgot password error:', error.message);

    if (error.message.includes('User not found')) {
      // Don't reveal if user exists for security
      return res.json({
        success: true,
        message: 'If an account with that email exists, a password reset link has been sent.'
      });
    }

    res.status(500).json({
      success: false,
      error: 'Failed to send password reset email',
      code: 'RESET_EMAIL_ERROR'
    });
  }
});

/**
 * POST /api/auth/reset-password
 * Complete password reset using token
 */
router.post('/reset-password', resetPasswordLimiter, async (req, res) => {
  try {
    console.log('🔄 Reset password request');

    const { token, newPassword } = req.body;

    if (!token || !newPassword) {
      return res.status(400).json({
        success: false,
        error: 'Token and new password are required',
        code: 'MISSING_FIELDS'
      });
    }

    // Validate password policy
    const passwordValidation = auth.validatePasswordPolicy(newPassword);
    if (!passwordValidation.isValid) {
      return res.status(400).json({
        success: false,
        error: `Password does not meet security requirements: ${passwordValidation.errors.join(', ')}`,
        code: 'INVALID_PASSWORD_POLICY',
        violations: passwordValidation.errors
      });
    }

    const pool = req.app.locals.pool;
    const clientIp = req.ip || req.connection.remoteAddress || 'unknown';
    const userAgent = req.headers['user-agent'] || 'unknown';

    const result = await auth.resetPassword(pool, token, newPassword, clientIp, userAgent);

    console.log('✅ Password reset successful');

    res.json({
      success: true,
      message: 'Password reset successfully',
      data: result
    });
  } catch (error) {
    console.error('❌ Reset password error:', error.message);

    let statusCode = 500;
    let errorCode = 'RESET_ERROR';

    if (error.message.includes('Invalid or expired token')) {
      statusCode = 400;
      errorCode = 'INVALID_TOKEN';
    } else if (error.message.includes('Token already used')) {
      statusCode = 400;
      errorCode = 'TOKEN_USED';
    }

    res.status(statusCode).json({
      success: false,
      error: error.message,
      code: errorCode
    });
  }
});

/**
 * POST /api/auth/validate-reset-token
 * Validate a password reset token without consuming it
 */
router.post('/validate-reset-token', resetPasswordLimiter, async (req, res) => {
  try {
    console.log('🔍 Token validation request');

    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        success: false,
        error: 'Token is required',
        code: 'MISSING_TOKEN'
      });
    }

    // Basic format validation (64 hex characters)
    if (!/^[a-f0-9]{64}$/i.test(token)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid token format',
        code: 'INVALID_TOKEN_FORMAT'
      });
    }

    const pool = req.app.locals.pool;
    const tokenHash = require('crypto').createHash('sha256').update(token).digest('hex');

    // Check if token exists and is valid
    const tokenResult = await pool.query(
      `SELECT user_id, expires_at, used FROM password_reset_tokens
       WHERE token_hash = $1`,
      [tokenHash]
    );

    if (tokenResult.rows.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Token not found',
        code: 'TOKEN_NOT_FOUND'
      });
    }

    const tokenData = tokenResult.rows[0];

    if (tokenData.used) {
      return res.status(400).json({
        success: false,
        error: 'Token has already been used',
        code: 'TOKEN_USED'
      });
    }

    if (new Date() > tokenData.expires_at) {
      return res.status(400).json({
        success: false,
        error: 'Token has expired',
        code: 'TOKEN_EXPIRED'
      });
    }

    // Token is valid
    res.json({
      success: true,
      message: 'Token is valid',
      data: {
        expiresAt: tokenData.expires_at,
        userId: tokenData.user_id
      }
    });

  } catch (error) {
    console.error('❌ Token validation error:', error.message);
    res.status(500).json({
      success: false,
      error: 'Token validation failed',
      code: 'VALIDATION_ERROR'
    });
  }
});

module.exports = router;













