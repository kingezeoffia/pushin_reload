require('dotenv').config();
const { Pool } = require('pg');

async function testConnection() {
  const dbUrl = process.env.DATABASE_URL || '';
  console.log('Testing database connection...');
  console.log('DATABASE_URL:', dbUrl.replace(/:[^:@]+@/, ':****@'));

  const isLocal = dbUrl.includes('localhost') || dbUrl.includes('127.0.0.1');
  const isRailwayInternal = dbUrl.includes('.railway.internal');

  const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: isLocal ? false : { rejectUnauthorized: false }
  });

  try {
    console.log('Attempting connection...');
    const client = await pool.connect();
    console.log('✅ SUCCESS: Connected to PostgreSQL');

    // Test a simple query
    const result = await client.query('SELECT NOW()');
    console.log('✅ SUCCESS: Query executed, current time:', result.rows[0].now);

    client.release();
    await pool.end();
    console.log('✅ SUCCESS: Connection test completed');
  } catch (error) {
    console.error('❌ FAILED: Database connection error');
    console.error('Error message:', error.message);
    console.error('Error code:', error.code);
    console.error('Error details:', {
      errno: error.errno,
      syscall: error.syscall,
      hostname: error.hostname,
      host: error.host,
      port: error.port
    });

    if (error.code === 'ECONNREFUSED') {
      console.log('\n💡 TROUBLESHOOTING:');
      console.log('1. Check if PostgreSQL service is running in Railway dashboard');
      console.log('2. Verify DATABASE_URL is using the internal URL:');
      console.log('   postgresql://postgres:[PASSWORD]@postgres-[ID].railway.internal:5432/railway');
      console.log('3. NOT the public proxy URL ending in maglev.proxy.rlwy.net');
    }
  }
}

testConnection();