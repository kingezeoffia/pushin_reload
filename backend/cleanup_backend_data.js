require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: {
        rejectUnauthorized: false
    }
});

async function cleanupData() {
    try {
        console.log('🔄 Attempting to cleanup all user data and subscriptions...');

        // Test connection
        const client = await pool.connect();
        console.log('✅ Database connection successful');

        // List of tables to truncate
        // Order matters for foreign key constraints if not using CASCADE
        // But TRUNCATE ... CASCADE is safer
        const tables = [
            'audit_logs',
            'password_reset_tokens',
            'refresh_tokens',
            'subscriptions',
            'anonymous_subscriptions',
            'users'
        ];

        for (const table of tables) {
            console.log(`🧹 Truncating table: ${table}...`);
            try {
                await client.query(`TRUNCATE TABLE ${table} RESTART IDENTITY CASCADE`);
                console.log(`✅ ${table} truncated.`);
            } catch (e) {
                if (e.code === '42P01') {
                    console.log(`ℹ️ Table ${table} does not exist, skipping.`);
                } else {
                    console.warn(`⚠️ Warning: Could not truncate ${table}: ${e.message}`);
                }
            }
        }

        console.log('✅ All user data and subscriptions have been cleared from the database.');
        client.release();
    } catch (error) {
        console.error('❌ Cleanup error:', error);
    } finally {
        await pool.end();
    }
}

cleanupData();
