/**
 * Test Railway database connection using Railway environment variables
 */

// Simulate Railway environment
process.env.DATABASE_URL = 'postgresql://postgres:UJsYlePaRRjWcPbFKprmhExhCisXNERX@postgres-zvno.railway.internal:5432/railway';
process.env.JWT_SECRET = 'super-secret-jwt-key-2024-pushin';
process.env.JWT_REFRESH_SECRET = 'refresh-secret-key-2024-pushin';
process.env.NODE_ENV = 'production';

console.log('🔗 Testing Railway database connection...');
console.log('DATABASE_URL pattern:', process.env.DATABASE_URL.replace(/:[^:@]+@/, ':****@'));

const { Pool } = require('pg');

// Get database connection string
const dbUrl = process.env.DATABASE_URL;

const isLocal = dbUrl.includes('localhost') || dbUrl.includes('127.0.0.1');
const isRailwayProxy = dbUrl.includes('maglev.proxy.rlwy.net');
const isRailwayInternal = dbUrl.includes('.railway.internal');

console.log('🔍 Connection type analysis:');
console.log('  - isLocal:', isLocal);
console.log('  - isRailwayProxy:', isRailwayProxy);
console.log('  - isRailwayInternal:', isRailwayInternal);

// SSL configuration for different environments
let sslConfig;
if (isLocal) {
  sslConfig = false; // No SSL for local connections
} else if (isRailwayInternal) {
  sslConfig = false; // Railway internal connections don't need SSL
} else {
  // External connections (including Railway proxy) need SSL but relaxed validation
  sslConfig = { rejectUnauthorized: false };
}

console.log('🔒 SSL config:', sslConfig);

const pool = new Pool({
  connectionString: dbUrl,
  ssl: sslConfig,
  connectionTimeoutMillis: 10000,
});

async function testRailwayConnection() {
  try {
    console.log('🔄 Connecting to Railway database...');
    const client = await pool.connect();
    console.log('✅ Connected successfully!');

    // Test a simple query
    const result = await client.query('SELECT NOW() as time');
    console.log('⏰ Server time:', result.rows[0].time);

    // Check if users table exists
    const tablesResult = await client.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'users'
    `);

    if (tablesResult.rows.length > 0) {
      console.log('✅ Users table exists');

      // Check if we can insert a test user
      console.log('🔄 Testing user insertion...');
      try {
        const testEmail = `test-railway-${Date.now()}@example.com`;
        const testPasswordHash = '$2b$12$dummy.hash.for.testing.purposes.only'; // Dummy hash

        const insertResult = await client.query(
          'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id',
          [testEmail, testPasswordHash]
        );

        console.log('✅ User insertion successful, ID:', insertResult.rows[0].id);

        // Clean up
        await client.query('DELETE FROM users WHERE email = $1', [testEmail]);
        console.log('🧹 Test user cleaned up');

      } catch (insertError) {
        console.log('❌ User insertion failed:', insertError.message);
      }

    } else {
      console.log('❌ Users table does not exist');
      console.log('📋 Attempting to create tables...');

      // Try to create the users table
      await client.query(`
        CREATE TABLE IF NOT EXISTS users (
          id SERIAL PRIMARY KEY,
          email VARCHAR(255) UNIQUE NOT NULL,
          password_hash VARCHAR(255),
          apple_id VARCHAR(255) UNIQUE,
          google_id VARCHAR(255) UNIQUE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
      console.log('✅ Users table created');
    }

    client.release();
    console.log('✅ Railway database test completed successfully');
  } catch (error) {
    console.error('❌ Railway database connection failed:', error.message);
    console.error('Full error:', error);
  } finally {
    await pool.end();
  }
}

testRailwayConnection();