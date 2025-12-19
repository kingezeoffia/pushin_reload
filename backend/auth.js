/**
 * Authentication Module for Pushin Reload Backend
 * Handles user authentication, OAuth, and JWT token management
 *
 * Features:
 * - Email/password authentication with bcrypt hashing
 * - Google OAuth integration
 * - Apple Sign In integration
 * - JWT access and refresh token management
 * - Secure token storage in database
 */

const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const axios = require('axios');

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'your-super-secret-refresh-key-change-in-production';
const JWT_EXPIRES_IN = '15m';
const JWT_REFRESH_EXPIRES_IN = '7d';

/**
 * Hash a password with bcrypt
 * @param {string} password - Plain text password
 * @returns {Promise<string>} Hashed password
 */
async function hashPassword(password) {
  const saltRounds = 12;
  return await bcrypt.hash(password, saltRounds);
}

/**
 * Verify a password against its hash
 * @param {string} password - Plain text password
 * @param {string} hash - Hashed password
 * @returns {Promise<boolean>} True if password matches
 */
async function verifyPassword(password, hash) {
  return await bcrypt.compare(password, hash);
}

/**
 * Generate JWT tokens for a user
 * @param {number} userId - User ID
 * @returns {Object} Access and refresh tokens
 */
function generateTokens(userId) {
  const accessToken = jwt.sign({ userId }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
  const refreshToken = jwt.sign({ userId }, JWT_REFRESH_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN });

  return { accessToken, refreshToken };
}

/**
 * Verify JWT token
 * @param {string} token - JWT token
 * @param {string} secret - Secret to verify against
 * @returns {Object|null} Decoded token or null if invalid
 */
function verifyToken(token, secret) {
  try {
    return jwt.verify(token, secret);
  } catch (error) {
    console.error('Token verification failed:', error.message);
    return null;
  }
}

/**
 * Store refresh token in database
 * @param {Object} pool - PostgreSQL pool
 * @param {number} userId - User ID
 * @param {string} refreshToken - Refresh token
 */
async function storeRefreshToken(pool, userId, refreshToken) {
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days

  await pool.query(
    'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
    [userId, refreshToken, expiresAt]
  );
}

/**
 * Remove refresh token from database
 * @param {Object} pool - PostgreSQL pool
 * @param {string} token - Refresh token to remove
 */
async function removeRefreshToken(pool, token) {
  await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [token]);
}

/**
 * Remove all refresh tokens for a user
 * @param {Object} pool - PostgreSQL pool
 * @param {number} userId - User ID
 */
async function removeUserRefreshTokens(pool, userId) {
  await pool.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);
}

/**
 * Verify Google OAuth token
 * @param {string} idToken - Google ID token
 * @returns {Promise<Object|null>} Google user data or null if invalid
 */
async function verifyGoogleToken(idToken) {
  try {
    const response = await axios.get(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
    return response.data;
  } catch (error) {
    console.error('Google token verification failed:', error.message);
    return null;
  }
}

/**
 * Register a new user with email and password
 * @param {Object} pool - PostgreSQL pool
 * @param {string} email - User email
 * @param {string} password - User password
 * @returns {Promise<Object>} User data and tokens
 */
async function registerUser(pool, email, password, firstname = null) {
  // Check if user already exists
  const existingUser = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  if (existingUser.rows.length > 0) {
    throw new Error('User already exists with this email');
  }

  // Hash password and create user
  const passwordHash = await hashPassword(password);
  const result = await pool.query(
    'INSERT INTO users (email, firstname, password_hash) VALUES ($1, $2, $3) RETURNING id, email, firstname, created_at',
    [email, firstname, passwordHash]
  );

  const user = result.rows[0];

  // Generate tokens
  const { accessToken, refreshToken } = generateTokens(user.id);

  // Store refresh token
  await storeRefreshToken(pool, user.id, refreshToken);

  return {
    user: {
      id: user.id,
      email: user.email,
      firstname: user.firstname,
      createdAt: user.created_at
    },
    isNewUser: true, // Always true for registration
    accessToken,
    refreshToken
  };
}

/**
 * Authenticate user with email and password
 * @param {Object} pool - PostgreSQL pool
 * @param {string} email - User email
 * @param {string} password - User password
 * @returns {Promise<Object>} User data and tokens
 */
async function loginUser(pool, email, password) {
  // Find user
  const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
  if (result.rows.length === 0) {
    throw new Error('Invalid email or password');
  }

  const user = result.rows[0];

  // Check if user has password (OAuth-only accounts)
  if (!user.password_hash) {
    throw new Error('Account registered with OAuth. Use Google or Apple sign in.');
  }

  // Verify password
  const isValidPassword = await verifyPassword(password, user.password_hash);
  if (!isValidPassword) {
    throw new Error('Invalid email or password');
  }

  // Generate tokens
  const { accessToken, refreshToken } = generateTokens(user.id);

  // Remove old refresh tokens and store new one
  await removeUserRefreshTokens(pool, user.id);
  await storeRefreshToken(pool, user.id, refreshToken);

  return {
    user: {
      id: user.id,
      email: user.email,
      firstname: user.firstname,
      createdAt: user.created_at
    },
    isNewUser: false, // Always false for login
    accessToken,
    refreshToken
  };
}

/**
 * Authenticate with Google OAuth
 * @param {Object} pool - PostgreSQL pool
 * @param {string} idToken - Google ID token
 * @returns {Promise<Object>} User data and tokens
 */
async function loginWithGoogle(pool, idToken) {
  // Verify Google token
  const googleUser = await verifyGoogleToken(idToken);
  if (!googleUser || !googleUser.sub) {
    throw new Error('Invalid Google token');
  }

  const googleId = googleUser.sub;
  const email = googleUser.email;

  // Check if user exists with this Google ID
  let user = await pool.query('SELECT * FROM users WHERE google_id = $1', [googleId]);
  let isNewUser = false;

  if (user.rows.length === 0) {
    // Check if user exists with this email (link accounts)
    const existingUser = await pool.query('SELECT * FROM users WHERE email = $1', [email]);

    if (existingUser.rows.length > 0) {
      // Link Google account to existing user
      await pool.query('UPDATE users SET google_id = $1 WHERE id = $2', [googleId, existingUser.rows[0].id]);
      user = await pool.query('SELECT * FROM users WHERE id = $1', [existingUser.rows[0].id]);
    } else {
      // Create new user
      const firstname = googleUser.given_name || googleUser.name?.split(' ')[0] || null;
      const result = await pool.query(
        'INSERT INTO users (email, firstname, google_id) VALUES ($1, $2, $3) RETURNING *',
        [email, firstname, googleId]
      );
      user = result;
      isNewUser = true;
    }
  }

  const userData = user.rows[0];

  // Generate tokens
  const { accessToken, refreshToken } = generateTokens(userData.id);

  // Remove old refresh tokens and store new one
  await removeUserRefreshTokens(pool, userData.id);
  await storeRefreshToken(pool, userData.id, refreshToken);

  return {
    user: {
      id: userData.id,
      email: userData.email,
      firstname: userData.firstname,
      createdAt: userData.created_at
    },
    isNewUser,
    accessToken,
    refreshToken
  };
}

/**
 * Authenticate with Apple Sign In
 * @param {Object} pool - PostgreSQL pool
 * @param {string} identityToken - Apple identity token
 * @param {Object} userData - Additional Apple user data
 * @returns {Promise<Object>} User data and tokens
 */
async function loginWithApple(pool, identityToken, userData = {}) {
  // Decode Apple identity token
  const tokenParts = identityToken.split('.');
  if (tokenParts.length !== 3) {
    throw new Error('Invalid Apple token format');
  }

  const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());

  if (!payload.sub) {
    throw new Error('Invalid Apple token payload');
  }

  const appleId = payload.sub;
  const email = payload.email || (userData && userData.email);

  if (!email) {
    throw new Error('Email is required for Apple Sign In');
  }

  // Check if user exists with this Apple ID
  let user = await pool.query('SELECT * FROM users WHERE apple_id = $1', [appleId]);
  let isNewUser = false;

  if (user.rows.length === 0) {
    // Check if user exists with this email (link accounts)
    const existingUser = await pool.query('SELECT * FROM users WHERE email = $1', [email]);

    if (existingUser.rows.length > 0) {
      // Link Apple account to existing user
      await pool.query('UPDATE users SET apple_id = $1 WHERE id = $2', [appleId, existingUser.rows[0].id]);
      user = await pool.query('SELECT * FROM users WHERE id = $1', [existingUser.rows[0].id]);
    } else {
      // Create new user
      const firstname = userData?.name?.firstName || null;
      const result = await pool.query(
        'INSERT INTO users (email, firstname, apple_id) VALUES ($1, $2, $3) RETURNING *',
        [email, firstname, appleId]
      );
      user = result;
      isNewUser = true;
    }
  }

  const userRecord = user.rows[0];

  // Generate tokens
  const { accessToken, refreshToken } = generateTokens(userRecord.id);

  // Remove old refresh tokens and store new one
  await removeUserRefreshTokens(pool, userRecord.id);
  await storeRefreshToken(pool, userRecord.id, refreshToken);

  return {
    user: {
      id: userRecord.id,
      email: userRecord.email,
      firstname: userRecord.firstname,
      createdAt: userRecord.created_at
    },
    isNewUser,
    accessToken,
    refreshToken
  };
}

/**
 * Refresh access token using refresh token
 * @param {Object} pool - PostgreSQL pool
 * @param {string} refreshToken - Refresh token
 * @returns {Promise<Object>} New tokens
 */
async function refreshAccessToken(pool, refreshToken) {
  // Verify refresh token
  const decoded = verifyToken(refreshToken, JWT_REFRESH_SECRET);
  if (!decoded) {
    throw new Error('Invalid or expired refresh token');
  }

  // Check if refresh token exists in database
  const tokenResult = await pool.query(
    'SELECT * FROM refresh_tokens WHERE token = $1 AND expires_at > NOW()',
    [refreshToken]
  );

  if (tokenResult.rows.length === 0) {
    throw new Error('Invalid or expired refresh token');
  }

  const userId = decoded.userId;

  // Generate new tokens
  const { accessToken, newRefreshToken } = generateTokens(userId);

  // Remove old refresh token and store new one
  await removeRefreshToken(refreshToken);
  await storeRefreshToken(pool, userId, newRefreshToken);

  return {
    accessToken,
    refreshToken: newRefreshToken
  };
}

/**
 * Get user profile by ID
 * @param {Object} pool - PostgreSQL pool
 * @param {number} userId - User ID
 * @returns {Promise<Object>} User profile data
 */
async function getUserProfile(pool, userId) {
  const result = await pool.query(
    'SELECT id, email, firstname, created_at FROM users WHERE id = $1',
    [userId]
  );

  if (result.rows.length === 0) {
    throw new Error('User not found');
  }

  return result.rows[0];
}

/**
 * Logout user (invalidate refresh tokens)
 * @param {Object} pool - PostgreSQL pool
 * @param {number} userId - User ID
 */
async function logoutUser(pool, userId) {
  await removeUserRefreshTokens(pool, userId);
}

module.exports = {
  // Password utilities
  hashPassword,
  verifyPassword,

  // Token utilities
  generateTokens,
  verifyToken,
  storeRefreshToken,
  removeRefreshToken,
  removeUserRefreshTokens,

  // OAuth utilities
  verifyGoogleToken,

  // Authentication methods
  registerUser,
  loginUser,
  loginWithGoogle,
  loginWithApple,
  refreshAccessToken,
  getUserProfile,
  logoutUser,

  // JWT configuration
  JWT_SECRET,
  JWT_REFRESH_SECRET
};
