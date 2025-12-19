/**
 * Test Database Connection
 * Quick script to verify DATABASE_URL is working
 */

require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function testConnection() {
  console.log('🧪 Testing Database Connection');
  console.log('DATABASE_URL:', process.env.DATABASE_URL ? 'SET' : 'NOT SET');
  
  try {
    const client = await pool.connect();
    console.log('✅ Connected to database successfully!');
    
    // Test if tables exist
    const result = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
    `);
    
    console.log('📋 Tables found:', result.rows.map(r => r.table_name));
    
    // Check specifically for users table
    const usersTable = result.rows.find(r => r.table_name === 'users');
    if (usersTable) {
      console.log('✅ Users table exists!');
    } else {
      console.log('❌ Users table not found!');
    }
    
    client.release();
  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
  } finally {
    await pool.end();
  }
}

testConnection();
