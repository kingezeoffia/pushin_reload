/**
 * Railway PostgreSQL Connection Test
 *
 * Simple test to verify database connection works.
 * Run: node test-connection.js
 */

const { Pool } = require('pg');

// Get connection string
const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error('❌ DATABASE_URL not set!');
  console.log('💡 Set it with: export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"');
  process.exit(1);
}

// Configure pool with Railway SSL
const pool = new Pool({
  connectionString,
  ssl: {
    require: true,
    rejectUnauthorized: false
  }
});

async function testConnection() {
  let client;
  try {
    console.log('🔄 Testing connection to Railway PostgreSQL...');
    client = await pool.connect();
    console.log('✅ Connection successful!');

    // Get PostgreSQL version
    const result = await client.query('SELECT version()');
    const version = result.rows[0].version.split(' ')[1];
    console.log(`📊 PostgreSQL version: ${version}`);

    // Count public tables
    const tableResult = await client.query(`
      SELECT COUNT(*) as table_count
      FROM information_schema.tables
      WHERE table_schema = 'public'
    `);
    console.log(`📋 Public tables count: ${tableResult.rows[0].table_count}`);

  } catch (err) {
    console.error('❌ Connection failed:', err.message);
  } finally {
    if (client) client.release();
    await pool.end();
    console.log('🔌 Connection closed');
  }
}

testConnection();












