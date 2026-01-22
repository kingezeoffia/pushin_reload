/**
 * Simple database connection test for Railway
 */

require('dotenv').config();
const { Pool } = require('pg');

// Get database connection string
const dbUrl = process.env.DATABASE_URL || process.env.DATABASE_PRIVATE_URL;

if (!dbUrl) {
  console.error('❌ No DATABASE_URL found');
  process.exit(1);
}

console.log('🔗 Testing database connection...');
console.log('URL:', dbUrl.replace(/:[^:@]+@/, ':****@'));

// Configure SSL based on connection type
const isLocal = dbUrl.includes('localhost') || dbUrl.includes('127.0.0.1');
const isRailwayInternal = dbUrl.includes('.railway.internal');

let sslConfig;
if (isLocal) {
  sslConfig = false;
} else if (isRailwayInternal) {
  sslConfig = false; // Railway internal doesn't need SSL
} else {
  sslConfig = { rejectUnauthorized: false };
}

console.log('🔒 SSL config:', sslConfig);

const pool = new Pool({
  connectionString: dbUrl,
  ssl: sslConfig,
});

async function testConnection() {
  try {
    const client = await pool.connect();
    console.log('✅ Connected to database');

    // Test a simple query
    const result = await client.query('SELECT NOW() as time, version() as version');
    console.log('⏰ Server time:', result.rows[0].time);
    console.log('🐘 PostgreSQL version:', result.rows[0].version.split(',')[0]);

    // Check if users table exists
    const tablesResult = await client.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      ORDER BY table_name
    `);

    console.log('📊 Tables found:');
    tablesResult.rows.forEach(row => console.log(`   - ${row.table_name}`));

    client.release();
    console.log('✅ Database test completed successfully');
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    console.error('Full error:', error);
  } finally {
    await pool.end();
  }
}

testConnection();