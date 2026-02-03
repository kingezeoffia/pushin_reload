require('dotenv').config();
const { Pool } = require('pg');

const dbUrl = process.env.DATABASE_URL || '';
const isLocal = dbUrl.includes('localhost') || dbUrl.includes('127.0.0.1');
const isRailwayInternal = dbUrl.includes('.railway.internal');

// Strip sslmode from URL to avoid conflicts
const cleanDbUrl = dbUrl.replace(/\?sslmode=[^&]*/, '').replace(/&sslmode=[^&]*/, '');

const pool = new Pool({
    connectionString: cleanDbUrl,
    ssl: (isLocal || isRailwayInternal) ? false : {
        rejectUnauthorized: false
    }
});

async function addUpdatedAtColumn() {
    let client;
    try {
        console.log('🔄 Connecting to database...');
        client = await pool.connect();
        console.log('✅ Connected successfully');

        console.log('🔄 Checking if updated_at column exists in users table...');
        const checkColumnResult = await client.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'users' AND column_name = 'updated_at'
    `);

        if (checkColumnResult.rows.length === 0) {
            console.log('🔄 Column updated_at does not exist. Adding it...');
            await client.query(`
        ALTER TABLE users ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
      `);
            console.log('✅ Column updated_at added to users table');
        } else {
            console.log('ℹ️ Column updated_at already exists in users table');
        }

        console.log('🎉 Migration completed successfully!');
    } catch (err) {
        console.error('❌ Error during migration:', err.message);
    } finally {
        if (client) client.release();
        await pool.end();
    }
}

addUpdatedAtColumn();
