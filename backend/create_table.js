require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: false  // Disable SSL for local development
});

async function createTable() {
  try {
    console.log('🔄 Connecting to PostgreSQL...');
    const client = await pool.connect();
    console.log('✅ Connected to PostgreSQL');

    console.log('🔄 Creating users table...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        firstname TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE
      );
    `);
    console.log('✅ Users table created');

    console.log('🔄 Inserting test user...');
    await client.query("INSERT INTO users (firstname, email) VALUES ('Test', 'test@example.com');");
    console.log('✅ Test user inserted');

    console.log('🔄 Checking tables...');
    const result = await client.query("\\dt");
    console.log('Tables:', result.rows);

    client.release();
    console.log('✅ Database operations completed successfully');
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('❌ Error details:', error);
  } finally {
    await pool.end();
  }
}

createTable();