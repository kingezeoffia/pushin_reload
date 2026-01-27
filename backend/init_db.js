require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: false  // Disable SSL for local development
});

async function initDatabase() {
  try {
    console.log('🔄 Attempting database connection and table initialization...');

    // Test connection first
    const client = await pool.connect();
    console.log('✅ Database connection successful');
    client.release();

    // Create users table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255),
        firstname VARCHAR(255),
        apple_id VARCHAR(255) UNIQUE,
        google_id VARCHAR(255) UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create refresh tokens table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        token VARCHAR(500) UNIQUE NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create subscriptions table for Stripe
    await pool.query(`
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
      )
    `);

    // Create anonymous subscriptions table for guest users
    await pool.query(`
      CREATE TABLE IF NOT EXISTS anonymous_subscriptions (
        id SERIAL PRIMARY KEY,
        anonymous_id VARCHAR(255) UNIQUE NOT NULL,
        email VARCHAR(255) NOT NULL,
        customer_id VARCHAR(255),
        subscription_id VARCHAR(255) UNIQUE,
        plan_id VARCHAR(50),
        current_period_end TIMESTAMP,
        is_active BOOLEAN DEFAULT true,
        linked_user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        recovery_token VARCHAR(255),
        recovery_expires_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create indexes for anonymous subscriptions
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_anonymous_subscriptions_email ON anonymous_subscriptions(email);
      CREATE INDEX IF NOT EXISTS idx_anonymous_subscriptions_recovery_token ON anonymous_subscriptions(recovery_token);
      CREATE INDEX IF NOT EXISTS idx_anonymous_subscriptions_linked_user ON anonymous_subscriptions(linked_user_id);
    `);

    // Create password reset tokens table
    await pool.query(`
      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        token_hash VARCHAR(255) UNIQUE NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        used BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create unique index on user_id for password reset tokens (one active token per user)
    await pool.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_password_reset_user_id ON password_reset_tokens(user_id);
    `);

    // Create audit logs table for security tracking
    await pool.query(`
      CREATE TABLE IF NOT EXISTS audit_logs (
        id SERIAL PRIMARY KEY,
        event_type VARCHAR(100) NOT NULL,
        user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        ip_address VARCHAR(50),
        user_agent TEXT,
        metadata JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Create indexes for audit logs
    await pool.query(`
      CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON audit_logs(event_type);
      CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
      CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);
    `);

    console.log('✅ Database connected and tables initialized');
  } catch (error) {
    console.error('❌ Database initialization error:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

initDatabase();