// Step 1: Import 'pg'
const { Pool } = require('pg');

// Step 2: Define connection string
// Replace this with your actual Railway PostgreSQL connection string
const connectionString = 'postgresql://username:password@host:port/database?sslmode=require';

const pool = new Pool({
  connectionString: connectionString,
  ssl: { rejectUnauthorized: false }
});

// Step 3: Connect to database
async function createUsersTable() {
  let client;
  try {
    console.log('🔄 Connecting to Railway PostgreSQL database...');
    client = await pool.connect();
    console.log('✅ Successfully connected to database');

    // Step 4: Create 'users' table if not exists
    console.log('🔄 Creating users table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        firstname TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE
      );
    `);

    // Step 5: Log success and close connection
    console.log('✅ Table "users" created successfully');
    console.log('📋 Table structure: id (SERIAL PRIMARY KEY), firstname (TEXT NOT NULL), email (TEXT NOT NULL UNIQUE)');

  } catch (error) {
    console.error('❌ Error creating table:', error.message);
    console.error('❌ Full error details:', error);
  } finally {
    if (client) {
      client.release();
      console.log('🔌 Database connection closed');
    }
    await pool.end();
  }
}

// Run the function
createUsersTable();