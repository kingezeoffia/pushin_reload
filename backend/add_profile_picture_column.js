/**
 * Migration Script: Add profile_picture column to users table
 * 
 * Usage: node backend/add_profile_picture_column.js
 */

const { Pool } = require('pg');

// Load .env file
try {
    require('dotenv').config();
} catch (err) {
    // dotenv not installed, skip
}

// Get connection string
const connectionString = process.env.DATABASE_PRIVATE_URL || process.env.DATABASE_URL;

if (!connectionString) {
    console.error('❌ ERROR: No database connection string found!');
    process.exit(1);
}

// Configure SSL
const useInternalConnection = !!process.env.DATABASE_PRIVATE_URL;
const poolConfig = {
    connectionString,
    ssl: useInternalConnection ? false : {
        rejectUnauthorized: false
    }
};

const pool = new Pool(poolConfig);

async function migrate() {
    let client;
    try {
        console.log('🔄 Connecting to database...');
        client = await pool.connect();
        console.log('✅ Connected!');

        console.log('📋 Checking if profile_picture column exists...');

        // Check if column exists
        const checkResult = await client.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name='users' AND column_name='profile_picture'
    `);

        if (checkResult.rows.length > 0) {
            console.log('⚠️ Column profile_picture already exists. Skipping...');
        } else {
            console.log('➕ Adding profile_picture column to users table...');
            await client.query(`
        ALTER TABLE users 
        ADD COLUMN profile_picture TEXT
      `);
            console.log('✅ Column added successfully!');
        }

    } catch (err) {
        console.error('❌ Migration failed:', err.message);
        process.exit(1);
    } finally {
        if (client) client.release();
        await pool.end();
        console.log('🔌 Connection closed');
    }
}

migrate();
