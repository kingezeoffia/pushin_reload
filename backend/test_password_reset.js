require('dotenv').config();
const { Pool } = require('pg');
const auth = require('./auth');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: false
});

async function testPasswordReset() {
  try {
    console.log('🧪 Testing Password Reset Flow\n');

    // Test email
    const testEmail = 'test@example.com';

    // Step 1: Create a test user if doesn't exist
    console.log('1️⃣ Checking/Creating test user...');
    const userCheck = await pool.query('SELECT id, email FROM users WHERE email = $1', [testEmail]);

    let userId;
    if (userCheck.rows.length === 0) {
      console.log('   Creating test user...');
      const hashedPassword = await auth.hashPassword('TestPassword123!');
      const result = await pool.query(
        'INSERT INTO users (email, firstname, password_hash) VALUES ($1, $2, $3) RETURNING id',
        [testEmail, 'Test User', hashedPassword]
      );
      userId = result.rows[0].id;
      console.log(`   ✅ Test user created with ID: ${userId}`);
    } else {
      userId = userCheck.rows[0].id;
      console.log(`   ✅ Test user already exists with ID: ${userId}`);
    }

    // Step 2: Request password reset
    console.log('\n2️⃣ Requesting password reset...');
    const resetResult = await auth.initiatePasswordReset(
      pool,
      testEmail,
      '127.0.0.1',
      'Test Script'
    );

    if (resetResult.emailSent) {
      console.log('   ✅ Password reset email sent successfully!');
      console.log('\n📧 CHECK YOUR MAILTRAP INBOX:');
      console.log('   Go to: https://mailtrap.io/inboxes');
      console.log('   You should see an email with the password reset link');
    } else {
      console.log('   ❌ Failed to send password reset email');
    }

    // Step 3: Show the token from database (for testing)
    console.log('\n3️⃣ Checking database for reset token...');
    const tokenResult = await pool.query(
      'SELECT token_hash, expires_at, used FROM password_reset_tokens WHERE user_id = $1',
      [userId]
    );

    if (tokenResult.rows.length > 0) {
      const token = tokenResult.rows[0];
      console.log('   ✅ Reset token found in database:');
      console.log('      Token Hash:', token.token_hash.substring(0, 16) + '...');
      console.log('      Expires:', token.expires_at);
      console.log('      Used:', token.used);
    }

    console.log('\n✅ Test completed successfully!');
    console.log('\n📋 Next steps:');
    console.log('   1. Check your Mailtrap inbox at https://mailtrap.io/inboxes');
    console.log('   2. You should see a beautiful email with a reset link');
    console.log('   3. Test the full flow in your Flutter app');

  } catch (error) {
    console.error('\n❌ Test failed:', error.message);
    console.error(error);
  } finally {
    await pool.end();
  }
}

testPasswordReset();
