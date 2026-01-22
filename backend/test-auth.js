/**
 * Authentication Module Test
 * Tests the modular auth system without starting the full server
 */

require('dotenv').config();
const { Pool } = require('pg');
const auth = require('./auth');

// Test database connection
const dbUrl = process.env.DATABASE_URL || '';
const isLocal = dbUrl.includes('localhost') || dbUrl.includes('127.0.0.1');

// SSL configuration for different environments
let sslConfig;
if (isLocal) {
  sslConfig = false; // No SSL for local connections
} else {
  // Railway/external connections need SSL but relaxed validation
  sslConfig = { rejectUnauthorized: false };
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: sslConfig
});

async function testAuthModule() {
  console.log('🧪 Testing Authentication Module\n');

  try {
    // Test 1: Password hashing and verification
    console.log('1️⃣ Testing password utilities...');
    const password = 'testPassword123!';
    const hash = await auth.hashPassword(password);
    const isValid = await auth.verifyPassword(password, hash);

    if (isValid) {
      console.log('✅ Password hashing and verification works');
    } else {
      console.log('❌ Password verification failed');
    }

    // Test 2: Token generation
    console.log('\n2️⃣ Testing token generation...');
    const tokens = auth.generateTokens(123);
    if (tokens.accessToken && tokens.refreshToken) {
      console.log('✅ Token generation works');
    } else {
      console.log('❌ Token generation failed');
    }

    // Test 3: Token verification
    console.log('\n3️⃣ Testing token verification...');
    const decoded = auth.verifyToken(tokens.accessToken, auth.JWT_SECRET);
    if (decoded && decoded.userId === 123) {
      console.log('✅ Token verification works');
    } else {
      console.log('❌ Token verification failed');
    }

    // Test 4: Database connection
    console.log('\n4️⃣ Testing database connection...');
    const client = await pool.connect();
    console.log('✅ Database connection successful');
    client.release();

    // Test 5: User registration (if tables exist)
    console.log('\n5️⃣ Testing user registration...');
    try {
      const testEmail = `test-${Date.now()}@example.com`;
      const result = await auth.registerUser(pool, testEmail, 'testPassword123');

      if (result.user && result.accessToken && result.refreshToken) {
        console.log('✅ User registration works');
        console.log('   User ID:', result.user.id);
        console.log('   Email:', result.user.email);

        // Test 6: User login
        console.log('\n6️⃣ Testing user login...');
        const loginResult = await auth.loginUser(pool, testEmail, 'testPassword123');

        if (loginResult.user && loginResult.accessToken) {
          console.log('✅ User login works');

          // Test 7: Get user profile
          console.log('\n7️⃣ Testing user profile retrieval...');
          const profile = await auth.getUserProfile(pool, result.user.id);

          if (profile.email === testEmail) {
            console.log('✅ User profile retrieval works');
          } else {
            console.log('❌ User profile retrieval failed');
          }

          // Test 8: Token refresh
          console.log('\n8️⃣ Testing token refresh...');
          const refreshResult = await auth.refreshAccessToken(pool, loginResult.refreshToken);

          if (refreshResult.accessToken && refreshResult.refreshToken) {
            console.log('✅ Token refresh works');
          } else {
            console.log('❌ Token refresh failed');
          }

          // Test 9: Logout
          console.log('\n9️⃣ Testing user logout...');
          await auth.logoutUser(pool, result.user.id);
          console.log('✅ User logout works');

        } else {
          console.log('❌ User login failed');
        }

      } else {
        console.log('❌ User registration failed');
      }
    } catch (error) {
      console.log('❌ User operations failed (tables may not exist):', error.message);
      console.log('💡 Run create_all_tables.js first to set up database schema');
    }

    console.log('\n🎉 Authentication module tests completed!');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await pool.end();
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  testAuthModule();
}

module.exports = { testAuthModule };