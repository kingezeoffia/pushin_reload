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
const crypto = require('crypto');
const nodemailer = require('nodemailer');

/**
 * Validate password against security policy
 * @param {string} password - Password to validate
 * @returns {Object} Validation result with isValid and errors array
 */
function validatePasswordPolicy(password) {
  const errors = [];

  // Minimum length
  if (password.length < 8) {
    errors.push('Password must be at least 8 characters long');
  }

  // Maximum length (prevent DoS)
  if (password.length > 128) {
    errors.push('Password must be no more than 128 characters long');
  }

  // Require at least one uppercase letter
  if (!/[A-Z]/.test(password)) {
    errors.push('Password must contain at least one uppercase letter');
  }

  // Require at least one lowercase letter
  if (!/[a-z]/.test(password)) {
    errors.push('Password must contain at least one lowercase letter');
  }

  // Require at least one number
  if (!/\d/.test(password)) {
    errors.push('Password must contain at least one number');
  }

  // Require at least one special character
  if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
    errors.push('Password must contain at least one special character');
  }

  // Check for common weak passwords (basic check)
  const commonPasswords = ['password', '12345678', 'qwerty', 'abc123', 'password123'];
  if (commonPasswords.includes(password.toLowerCase())) {
    errors.push('Password is too common and easily guessable');
  }

  // Check for repeated characters (more than 3 in a row)
  if (/(.)\1{3,}/.test(password)) {
    errors.push('Password cannot contain more than 3 repeated characters in a row');
  }

  return {
    isValid: errors.length === 0,
    errors: errors
  };
}

/**
 * Log security audit event
 * @param {Object} pool - Database connection pool
 * @param {string} eventType - Type of event (e.g., 'password_reset_initiated')
 * @param {number|null} userId - User ID if applicable
 * @param {string} ipAddress - Client IP address
 * @param {string} userAgent - Client user agent
 * @param {Object} metadata - Additional event data
 */
async function logAuditEvent(pool, eventType, userId = null, ipAddress = null, userAgent = null, metadata = {}) {
  try {
    await pool.query(
      `INSERT INTO audit_logs (event_type, user_id, ip_address, user_agent, metadata, created_at)
       VALUES ($1, $2, $3, $4, $5, NOW())`,
      [eventType, userId, ipAddress, userAgent, JSON.stringify(metadata)]
    );
  } catch (error) {
    // Log to console as fallback, but don't fail the operation
    console.error('Failed to write audit log:', error.message);
  }
}

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
    'SELECT id, email, firstname, profile_picture, created_at FROM users WHERE id = $1',
    [userId]
  );

  if (result.rows.length === 0) {
    throw new Error('User not found');
  }

  return result.rows[0];
}

/**
 * Update user profile
 * @param {Object} pool - PostgreSQL pool
 * @param {number} userId - User ID
 * @param {Object} updates - Object containing fields to update (email, firstname, password)
 * @returns {Object} Updated user data
 */
async function updateUserProfile(pool, userId, updates) {
  const updateFields = [];
  const updateValues = [];
  let paramIndex = 1;

  // Build dynamic update query
  if (updates.email !== undefined) {
    updateFields.push(`email = $${paramIndex}`);
    updateValues.push(updates.email);
    paramIndex++;
  }

  if (updates.firstname !== undefined) {
    updateFields.push(`firstname = $${paramIndex}`);
    updateValues.push(updates.firstname);
    paramIndex++;
  }

  if (updates.password !== undefined) {
    // Hash the new password
    const hashedPassword = await hashPassword(updates.password);
    updateFields.push(`password_hash = $${paramIndex}`);
    updateValues.push(hashedPassword);
    paramIndex++;
  }

  if (updates.profile_picture !== undefined) {
    updateFields.push(`profile_picture = $${paramIndex}`);
    updateValues.push(updates.profile_picture);
    paramIndex++;
  }

  if (updateFields.length === 0) {
    throw new Error('No valid fields to update');
  }

  // Add userId at the end
  updateValues.push(userId);

  const query = `
    UPDATE users
    SET ${updateFields.join(', ')}, updated_at = NOW()
    WHERE id = $${paramIndex}
    RETURNING id, email, firstname, profile_picture, created_at, updated_at
  `;

  const result = await pool.query(query, updateValues);

  if (result.rows.length === 0) {
    throw new Error('User not found or update failed');
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

/**
 * Initiate password reset by generating secure token and sending email
 * @param {Object} pool - Database connection pool
 * @param {string} email - User email
 * @param {string} clientIp - Client IP address
 * @param {string} userAgent - Client user agent
 */
async function initiatePasswordReset(pool, email, clientIp, userAgent) {
  console.log(`🔑 Password reset initiated - Email: ${email}, IP: ${clientIp}`);

  // Check if user exists
  const userResult = await pool.query(
    'SELECT id, email FROM users WHERE email = $1',
    [email.toLowerCase()]
  );

  let userExists = true;
  let userId = null;

  if (userResult.rows.length === 0) {
    userExists = false;
  } else {
    userId = userResult.rows[0].id;
  }

  // Log the attempt
  await logAuditEvent(pool, 'password_reset_initiated', userId, clientIp, userAgent, {
    email: email,
    user_exists: userExists
  });

  if (!userExists) {
    // Don't throw error - return success for security
    console.log(`🔑 Password reset attempted for non-existent email: ${email}`);
    return { emailSent: true };
  }

  const user = userResult.rows[0];

  // Generate cryptographically secure random token (32 bytes = 64 hex chars)
  const resetToken = crypto.randomBytes(32).toString('hex');
  const tokenHash = crypto.createHash('sha256').update(resetToken).digest('hex');

  // Store only the hashed token in database with expiration
  await pool.query(
    `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at, used, created_at)
     VALUES ($1, $2, $3, false, NOW())
     ON CONFLICT (user_id)
     DO UPDATE SET token_hash = $2, expires_at = $3, used = false, created_at = NOW()`,
    [user.id, tokenHash, new Date(Date.now() + 15 * 60 * 1000)]
  );

  // Log security event (don't log the actual token)
  console.log(`✅ Password reset token created for user ${user.id} (${email})`);

  try {
    // Send reset email with the actual token (not the hash)
    await sendPasswordResetEmail(user.email, resetToken);

    await logAuditEvent(pool, 'password_reset_email_sent', user.id, clientIp, userAgent, {
      email: email
    });

    console.log(`📧 Password reset email sent to ${email}`);
    return { emailSent: true };
  } catch (emailError) {
    // Email failed - clean up the token to prevent orphaned tokens
    await pool.query(
      'DELETE FROM password_reset_tokens WHERE token_hash = $1',
      [tokenHash]
    );

    await logAuditEvent(pool, 'password_reset_email_failed', user.id, clientIp, userAgent, {
      email: email,
      error: emailError.message
    });

    console.error(`❌ Password reset email failed for ${email}: ${emailError.message}`);
    throw new Error('Failed to send password reset email');
  }
}

/**
 * Reset password using valid token
 * @param {Object} pool - Database connection pool
 * @param {string} token - Reset token
 * @param {string} newPassword - New password
 */
async function resetPassword(pool, token, newPassword, clientIp, userAgent) {
  console.log(`🔄 Password reset attempt - TokenHash: ${crypto.createHash('sha256').update(token).digest('hex').substring(0, 8)}..., IP: ${clientIp}`);

  try {
    // Hash the provided token to compare with stored hash
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

    // Check if token hash exists and is valid (atomic check)
    const tokenResult = await pool.query(
      `SELECT user_id, used FROM password_reset_tokens
       WHERE token_hash = $1 AND expires_at > NOW()`,
      [tokenHash]
    );

    if (tokenResult.rows.length === 0) {
      await logAuditEvent(pool, 'password_reset_token_invalid', null, clientIp, userAgent, {
        token_hash_prefix: tokenHash.substring(0, 8),
        reason: 'token_not_found_or_expired'
      });
      console.log(`❌ Password reset attempted with invalid/expired token`);
      throw new Error('Invalid or expired token');
    }

    const tokenData = tokenResult.rows[0];
    const userId = tokenData.user_id;

    // Check if token was already used (double-check after initial query)
    if (tokenData.used) {
      await logAuditEvent(pool, 'password_reset_token_reused', userId, clientIp, userAgent, {
        token_hash_prefix: tokenHash.substring(0, 8)
      });
      console.log(`❌ Password reset attempted with already used token`);
      throw new Error('Token has already been used');
    }

    // Validate password policy
    const passwordValidation = validatePasswordPolicy(newPassword);
    if (!passwordValidation.isValid) {
      await logAuditEvent(pool, 'password_reset_policy_violation', userId, clientIp, userAgent, {
        token_hash_prefix: tokenHash.substring(0, 8),
        violations: passwordValidation.errors
      });
      throw new Error(`Password does not meet security requirements: ${passwordValidation.errors.join(', ')}`);
    }

    // Hash new password
    const hashedPassword = await hashPassword(newPassword);

    // Update password and mark token as used in a single atomic transaction
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Double-check token is still unused (race condition protection)
      const tokenCheck = await client.query(
        'SELECT used FROM password_reset_tokens WHERE token_hash = $1 AND used = false',
        [tokenHash]
      );

      if (tokenCheck.rows.length === 0) {
        await client.query('ROLLBACK');
        await logAuditEvent(pool, 'password_reset_token_reused', userId, clientIp, userAgent, {
          token_hash_prefix: tokenHash.substring(0, 8),
          reason: 'concurrent_usage'
        });
        throw new Error('Token has already been used');
      }

      // Update password
      await client.query(
        'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
        [hashedPassword, userId]
      );

      // Mark token as used with timestamp
      await client.query(
        'UPDATE password_reset_tokens SET used = true WHERE token_hash = $1',
        [tokenHash]
      );

      // CRITICAL: Invalidate ALL refresh tokens for this user
      await client.query(
        'DELETE FROM refresh_tokens WHERE user_id = $1',
        [userId]
      );

      await client.query('COMMIT');

      // Log successful reset
      await logAuditEvent(pool, 'password_reset_successful', userId, clientIp, userAgent, {
        token_hash_prefix: tokenHash.substring(0, 8)
      });

      console.log(`✅ Password reset successful for user ${userId} - all sessions invalidated`);

    } catch (error) {
      await client.query('ROLLBACK');
      console.log(`❌ Password reset transaction failed for user ${userId}: ${error.message}`);
      throw error;
    } finally {
      client.release();
    }

    return { passwordReset: true };
  } catch (error) {
    console.log(`❌ Password reset failed: ${error.message}`);
    throw error;
  }
}

/**
 * Send password reset email using nodemailer
 * @param {string} email - User email
 * @param {string} resetToken - Reset token
 */
async function sendPasswordResetEmail(email, resetToken) {
  // Build reset URL
  const resetUrl = `${process.env.FRONTEND_URL || 'pushinapp://reset-password'}?token=${resetToken}`;

  console.log(`📧 Sending password reset email to ${email}`);
  console.log(`🔗 Reset URL: ${resetUrl}`);

  // Configure email transporter
  // Supports multiple email services via SMTP
  const transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587'),
    secure: process.env.SMTP_SECURE === 'true', // true for 465, false for other ports
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    },
    // For development/testing with services like Mailtrap
    ...(process.env.NODE_ENV === 'test' && {
      host: process.env.SMTP_HOST || 'sandbox.smtp.mailtrap.io',
      port: parseInt(process.env.SMTP_PORT || '2525'),
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS
      }
    })
  });

  // Verify transporter configuration
  try {
    await transporter.verify();
    console.log('✅ SMTP server is ready to send emails');
  } catch (error) {
    console.error('❌ SMTP verification failed:', error.message);
    throw new Error(`Email service configuration error: ${error.message}`);
  }

  // Email template
  const mailOptions = {
    from: process.env.EMAIL_FROM || '"PUSHIN" <noreply@pushinapp.com>',
    to: email,
    subject: 'Reset your PUSHIN password',
    html: `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Reset Your Password</title>
        </head>
        <body style="margin: 0; padding: 0; background-color: #f5f5f5; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;">
          <div style="max-width: 600px; margin: 40px auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
            <!-- Header -->
            <div style="background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%); padding: 40px 30px; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 800; letter-spacing: -0.5px;">
                Reset Your Password
              </h1>
            </div>

            <!-- Body -->
            <div style="padding: 40px 30px;">
              <p style="margin: 0 0 16px; color: #1f2937; font-size: 16px; line-height: 1.5;">
                Hello,
              </p>

              <p style="margin: 0 0 24px; color: #4b5563; font-size: 15px; line-height: 1.6;">
                You requested to reset your password for your PUSHIN account. Click the button below to create a new password:
              </p>

              <!-- CTA Button -->
              <div style="text-align: center; margin: 32px 0;">
                <a href="${resetUrl}" style="display: inline-block; background: linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%); color: #ffffff; text-decoration: none; padding: 14px 32px; border-radius: 100px; font-size: 16px; font-weight: 600; letter-spacing: -0.3px; box-shadow: 0 4px 12px rgba(139, 92, 246, 0.3);">
                  Reset Password
                </a>
              </div>

              <!-- Expiration Notice -->
              <div style="background-color: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; margin: 24px 0; border-radius: 8px;">
                <p style="margin: 0; color: #92400e; font-size: 14px; font-weight: 600;">
                  ⚠️ This link expires in 15 minutes
                </p>
              </div>

              <p style="margin: 0 0 8px; color: #6b7280; font-size: 14px; line-height: 1.5;">
                If the button doesn't work, copy and paste this link into your browser:
              </p>

              <p style="margin: 0 0 24px; color: #8B5CF6; font-size: 13px; word-break: break-all; line-height: 1.4;">
                ${resetUrl}
              </p>

              <p style="margin: 0; color: #6b7280; font-size: 14px; line-height: 1.5;">
                If you didn't request this password reset, you can safely ignore this email. Your password will remain unchanged.
              </p>
            </div>

            <!-- Footer -->
            <div style="background-color: #f9fafb; padding: 24px 30px; border-top: 1px solid #e5e7eb;">
              <p style="margin: 0 0 8px; color: #1f2937; font-size: 14px; font-weight: 600;">
                Best regards,<br>The PUSHIN Team
              </p>

              <p style="margin: 0; color: #9ca3af; font-size: 12px; line-height: 1.4;">
                This is an automated email. Please do not reply to this message.
              </p>
            </div>
          </div>

          <!-- Legal Footer -->
          <div style="max-width: 600px; margin: 0 auto; padding: 20px; text-align: center;">
            <p style="margin: 0; color: #9ca3af; font-size: 12px; line-height: 1.5;">
              © ${new Date().getFullYear()} PUSHIN. All rights reserved.
            </p>
          </div>
        </body>
      </html>
    `,
    // Plain text version for email clients that don't support HTML
    text: `
Reset Your PUSHIN Password

Hello,

You requested to reset your password for your PUSHIN account.

To reset your password, click this link or copy it into your browser:
${resetUrl}

⚠️ This link expires in 15 minutes.

If you didn't request this password reset, you can safely ignore this email. Your password will remain unchanged.

Best regards,
The PUSHIN Team

---
This is an automated email. Please do not reply to this message.
© ${new Date().getFullYear()} PUSHIN. All rights reserved.
    `.trim()
  };

  // Send email
  try {
    const info = await transporter.sendMail(mailOptions);
    console.log('✅ Password reset email sent successfully:', info.messageId);
    return info;
  } catch (error) {
    console.error('❌ Failed to send password reset email:', error);
    throw new Error(`Failed to send email: ${error.message}`);
  }
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
  updateUserProfile,
  logoutUser,

  // JWT configuration
  JWT_SECRET,
  JWT_REFRESH_SECRET,

  // Password validation
  validatePasswordPolicy,

  // Audit logging
  logAuditEvent,

  // Password reset functions
  initiatePasswordReset,
  resetPassword
};












