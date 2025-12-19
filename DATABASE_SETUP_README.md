# Railway PostgreSQL Database Setup

## Overview
This guide explains how to set up and use the `create_all_tables.js` script to create all required database tables for the Pushin Flutter app.

## Prerequisites

### 1. Railway PostgreSQL Database
- Railway account and CLI installed
- PostgreSQL database created in Railway
- Database URL available via `railway variables get DATABASE_URL`
- **Note**: Railway charges egress fees for public endpoints. Consider using private domains (`RAILWAY_PRIVATE_DOMAIN`) for production to avoid fees.

### 2. Node.js Environment
- Node.js 18+ installed
- `pg` package available (already in `backend/package.json`)

### 3. Railway Domain Configuration

Railway provides both public and private database endpoints:

- **Public Domain** (DATABASE_PUBLIC_URL): Accessible from anywhere, but incurs egress fees
- **Private Domain** (RAILWAY_PRIVATE_DOMAIN): Only accessible within Railway network, no egress fees

**Current Setup**: Uses Railway internal domain for zero egress fees within Railway environment.
**Local Development**: Use Railway CLI tunnel or public domain.

## Usage

### Step 1: Set Environment Variable
```bash
# Get your Railway database URL
railway variables get DATABASE_URL

# Set the environment variable (replace with your actual URL)
export DATABASE_URL="postgresql://postgres:YOUR_ACTUAL_PASSWORD@postgres.railway.internal:5432/railway"
```

### Step 2: Run the Script
```bash
# From project root
node create_all_tables.js
```

## Tables Created

The script creates 5 essential tables:

1. **`users`** - User accounts and authentication
   - `id` (SERIAL PRIMARY KEY)
   - `email` (VARCHAR(255) UNIQUE NOT NULL)
   - `password_hash` (VARCHAR(255))
   - `apple_id` (VARCHAR(255) UNIQUE)
   - `google_id` (VARCHAR(255) UNIQUE)
   - `created_at` (TIMESTAMP)

2. **`refresh_tokens`** - JWT authentication tokens
   - `id` (SERIAL PRIMARY KEY)
   - `user_id` (INTEGER REFERENCES users(id))
   - `token` (VARCHAR(500) UNIQUE NOT NULL)
   - `expires_at` (TIMESTAMP NOT NULL)
   - `created_at` (TIMESTAMP)

3. **`subscriptions`** - Stripe payment subscriptions
   - `id` (SERIAL PRIMARY KEY)
   - `user_id` (INTEGER REFERENCES users(id))
   - `customer_id` (VARCHAR(255))
   - `subscription_id` (VARCHAR(255) UNIQUE)
   - `plan_id` (VARCHAR(50))
   - `current_period_end` (TIMESTAMP)
   - `is_active` (BOOLEAN DEFAULT true)
   - `created_at` (TIMESTAMP)
   - `updated_at` (TIMESTAMP)

4. **`workouts`** - Workout completion tracking
   - `id` (SERIAL PRIMARY KEY)
   - `user_id` (INTEGER REFERENCES users(id))
   - `workout_type` (VARCHAR(50) NOT NULL)
   - `reps_completed` (INTEGER NOT NULL DEFAULT 0)
   - `earned_seconds` (INTEGER NOT NULL DEFAULT 0)
   - `completed_at` (TIMESTAMP)
   - `created_at` (TIMESTAMP)

5. **`daily_usage`** - Daily unlock time usage tracking
   - `id` (SERIAL PRIMARY KEY)
   - `user_id` (INTEGER REFERENCES users(id))
   - `date` (DATE NOT NULL)
   - `earned_seconds` (INTEGER NOT NULL DEFAULT 0)
   - `consumed_seconds` (INTEGER NOT NULL DEFAULT 0)
   - `plan_tier` (VARCHAR(20) NOT NULL DEFAULT 'free')
   - `last_updated` (TIMESTAMP)
   - UNIQUE(user_id, date)

## Verification

After running the script successfully, verify table creation:

### Railway Dashboard Method
1. Log into [Railway Dashboard](https://railway.app)
2. Navigate to your PostgreSQL database
3. Open the **Query** tab
4. Run this query:
   ```sql
   SELECT table_name
   FROM information_schema.tables
   WHERE table_schema = 'public'
   ORDER BY table_name;
   ```
5. Verify all 5 tables appear: `daily_usage`, `refresh_tokens`, `subscriptions`, `users`, `workouts`

### Command Line Method
```bash
# Using Railway CLI
railway connect postgres

# Then in psql:
# \dt
# SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
```

## Adding New Tables

To add new tables, simply append to the `tables` array in `create_all_tables.js`:

```javascript
{
  name: 'new_table',
  sql: `
    CREATE TABLE IF NOT EXISTS new_table (
      id SERIAL PRIMARY KEY,
      -- your columns here
    );
  `
}
```

## Error Handling

The script includes comprehensive error handling:
- Environment variable validation
- Connection failure detection
- Individual table creation error reporting
- Detailed error messages with SQL that failed
- Clean connection cleanup

## Security Notes

- Uses SSL with `rejectUnauthorized: false` for Railway compatibility
- Automatically detects Railway private domains (`.railway.internal`) and disables SSL for internal connections
- Never commit database credentials to version control
- Always use Railway environment variables for production
- Consider using Railway private domains in production to avoid egress fees

## Troubleshooting

### DATABASE_URL Not Set
```
❌ DATABASE_URL environment variable is not set!
```
**Solution**: Set the environment variable as shown in Step 1.

### Connection Failed
```
❌ Error in Railway database operations: getaddrinfo ENOTFOUND
```
**Solution**: Check that DATABASE_URL is correct and Railway database is running.

### Table Creation Failed
```
❌ Error creating table 'table_name': relation already exists
```
**Solution**: Tables already exist (IF NOT EXISTS prevents recreation).

### Permission Denied
```
❌ Error creating table: permission denied for schema public
```
**Solution**: Check Railway database user permissions.