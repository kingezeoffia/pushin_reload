/**
 * Railway PostgreSQL Table Creation Script
 * Supports: Local dev + Railway internal/external deployment
 *
 * USAGE:
 * 
 * 1) LOCAL DEVELOPMENT:
 *    Create .env file with:
 *      DATABASE_URL=postgresql://postgres:PASSWORD@HOST:PORT/railway
 *    Then run:
 *      node create_all_tables.js
 *
 * 2) RAILWAY DEPLOYMENT (automatic):
 *    Railway sets DATABASE_PRIVATE_URL (internal, no SSL) or
 *    DATABASE_URL (external proxy, SSL) automatically.
 *    Just run: node create_all_tables.js
 *
 * ENVIRONMENT VARIABLES:
 * - DATABASE_PRIVATE_URL: Railway internal network (preferred, no SSL)
 * - DATABASE_URL: External proxy or local development (requires SSL)
 * - RAILWAY_ENVIRONMENT: Auto-set by Railway
 */

const { Pool } = require('pg');

// Load .env file for local development (optional dependency)
try {
  require('dotenv').config();
} catch (err) {
  // dotenv not installed, skip (fine for Railway deployment)
}

// Step 1: Detect environment and get connection string
const isRailway = !!process.env.RAILWAY_ENVIRONMENT;
const connectionString = process.env.DATABASE_PRIVATE_URL || process.env.DATABASE_URL;

if (!connectionString) {
  console.error('❌ ERROR: No database connection string found!');
  console.error('');
  console.error('Local development:');
  console.error('  1. Create a .env file with: DATABASE_URL=postgresql://...');
  console.error('  2. Or export: export DATABASE_URL="postgresql://..."');
  console.error('');
  console.error('Railway deployment:');
  console.error('  - DATABASE_PRIVATE_URL or DATABASE_URL should be auto-set');
  console.error('  - Check Railway dashboard → Variables');
  process.exit(1);
}

// Step 2: Configure SSL based on connection type
const useInternalConnection = !!process.env.DATABASE_PRIVATE_URL;
const poolConfig = {
  connectionString,
  // Railway internal network doesn't need SSL, external proxy does
  ssl: useInternalConnection ? false : {
    rejectUnauthorized: false  // Allow Railway self-signed certificates
  }
};

const pool = new Pool(poolConfig);

// Log connection details (without exposing password)
const maskedUrl = connectionString.replace(/:[^:@]+@/, ':****@');
console.log('🔧 Environment:', isRailway ? 'Railway' : 'Local');
console.log('🔗 Connection:', useInternalConnection ? 'Internal (no SSL)' : 'External (SSL)');
console.log('🌐 Database:', maskedUrl);

// Step 3: Define tables
const tables = [
  {
    name: 'users',
    sql: `
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        firstname VARCHAR(100),
        password_hash VARCHAR(255),
        apple_id VARCHAR(255) UNIQUE,
        google_id VARCHAR(255) UNIQUE,
  
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `
  },

  {
    name: 'refresh_tokens',
    sql: `
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        token VARCHAR(500) UNIQUE NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `
  },
  {
    name: 'password_reset_tokens',
    sql: `
      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        token_hash TEXT NOT NULL UNIQUE,
        expires_at TIMESTAMP NOT NULL,
        used BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

        UNIQUE(user_id) -- Only one active reset per user
      );
    `
  },
  {
    name: 'audit_logs',
    sql: `
      CREATE TABLE IF NOT EXISTS audit_logs (
        id SERIAL PRIMARY KEY,
        event_type VARCHAR(100) NOT NULL,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        ip_address INET,
        user_agent TEXT,
        metadata JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

        INDEX idx_audit_logs_event_type (event_type),
        INDEX idx_audit_logs_user_id (user_id),
        INDEX idx_audit_logs_created_at (created_at)
      );
    `
  },
  {
    name: 'subscriptions',
    sql: `
      CREATE TABLE IF NOT EXISTS subscriptions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        customer_id VARCHAR(255),
        subscription_id VARCHAR(255) UNIQUE,
        plan_id VARCHAR(50),
        current_period_end TIMESTAMP,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `
  },
  {
    name: 'anonymous_subscriptions',
    sql: `
      CREATE TABLE IF NOT EXISTS anonymous_subscriptions (
        id SERIAL PRIMARY KEY,
        anonymous_id VARCHAR(255) UNIQUE NOT NULL, -- UUID or random identifier for anonymous user
        email VARCHAR(255) NOT NULL,
        customer_id VARCHAR(255),
        subscription_id VARCHAR(255) UNIQUE,
        plan_id VARCHAR(50),
        current_period_end TIMESTAMP,
        is_active BOOLEAN DEFAULT true,
        linked_user_id INTEGER REFERENCES users(id) ON DELETE CASCADE, -- NULL until linked to real account
        recovery_token VARCHAR(255), -- For account linking/recovery
        recovery_expires_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

        INDEX idx_anonymous_subscriptions_email (email),
        INDEX idx_anonymous_subscriptions_recovery_token (recovery_token),
        INDEX idx_anonymous_subscriptions_linked_user (linked_user_id)
      );
    `
  },
  {
    name: 'workouts',
    sql: `
      CREATE TABLE IF NOT EXISTS workouts (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        workout_type VARCHAR(50) NOT NULL,
        reps_completed INTEGER NOT NULL DEFAULT 0,
        earned_seconds INTEGER NOT NULL DEFAULT 0,
        completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `
  },
  {
    name: 'daily_usage',
    sql: `
      CREATE TABLE IF NOT EXISTS daily_usage (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        date DATE NOT NULL,
        earned_seconds INTEGER NOT NULL DEFAULT 0,
        consumed_seconds INTEGER NOT NULL DEFAULT 0,
        plan_tier VARCHAR(20) NOT NULL DEFAULT 'free',
        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, date)
      );
    `
  }
];

// Step 4: Connect and create tables
async function createAllTables() {
  let client;
  try {
    console.log('');
    console.log('🔄 Connecting to PostgreSQL database...');

    // Test connection with timeout
    client = await pool.connect();
    console.log('✅ Connected successfully!');

    // Verify connection with a simple query
    const result = await client.query('SELECT NOW() as current_time, version() as pg_version');
    console.log('⏰ Server time:', result.rows[0].current_time);
    console.log('🐘 PostgreSQL:', result.rows[0].pg_version.split(',')[0]);
    console.log('');

    // Create tables in order (respecting foreign key dependencies)
    for (const table of tables) {
      console.log(`📋 Creating table '${table.name}'...`);
      await client.query(table.sql);
      console.log(`✅ Table '${table.name}' ready`);
    }

    console.log('');
    console.log('🎉 SUCCESS! All tables created/verified!');
    console.log('');

    // Show table summary
    const tablesQuery = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `);
    console.log('📊 Tables in database:');
    tablesQuery.rows.forEach(row => console.log(`   - ${row.table_name}`));

  } catch (err) {
    console.error('');
    console.error('❌ DATABASE ERROR:');
    console.error('Message:', err.message);
    console.error('');

    // Show full stack trace for debugging
    if (err.stack) {
      console.error('Stack trace:');
      console.error(err.stack);
    }

    // Specific error hints
    if (err.message.includes('ENOTFOUND') || err.message.includes('ECONNREFUSED')) {
      console.error('');
      console.error('💡 Hint: Check your DATABASE_URL host and port are correct');
    } else if (err.message.includes('password authentication failed')) {
      console.error('');
      console.error('💡 Hint: Check your database password is correct');
    } else if (err.message.includes('SSL')) {
      console.error('');
      console.error('💡 Hint: SSL connection issue. Use DATABASE_PRIVATE_URL for Railway internal connection');
    }

    process.exit(1);
  } finally {
    if (client) {
      client.release();
    }
    await pool.end();
    console.log('');
    console.log('🔌 Connection closed');
  }
}

// Run the script
createAllTables();
