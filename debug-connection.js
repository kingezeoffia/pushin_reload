/**
 * Railway PostgreSQL Debug Connection Script
 *
 * Tests multiple SSL configurations to diagnose connection issues.
 * Run: node debug-connection.js
 */

const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error('❌ DATABASE_URL not set!');
  console.log('💡 Set it with: export DATABASE_URL="postgresql://postgres:OTSfjiuRyXCzKobyUbReJzQSWeuSrWIM@hopper.proxy.rlwy.net:25708/railway"');
  process.exit(1);
}

// Test different SSL configurations
const sslConfigs = [
  {
    name: 'Standard Railway SSL',
    config: { require: true, rejectUnauthorized: false }
  },
  {
    name: 'SSL with CA bypass',
    config: { rejectUnauthorized: false, ca: null }
  },
  {
    name: 'SSL with identity check disabled',
    config: { rejectUnauthorized: false, checkServerIdentity: () => undefined }
  }
];

async function testSSLConfig(name, sslConfig) {
  console.log(`🔄 Testing: ${name}`);

  const pool = new Pool({
    connectionString,
    ssl: sslConfig,
    connectionTimeoutMillis: 10000
  });

  let client;
  try {
    client = await pool.connect();
    console.log('   ✅ Connection successful!');
    return true;
  } catch (err) {
    console.log(`   ❌ Failed: ${err.message}`);
    return false;
  } finally {
    if (client) client.release();
    await pool.end();
  }
}

async function runDiagnostics() {
  console.log('🚀 Railway PostgreSQL SSL Diagnostics\n');

  let successCount = 0;
  for (const test of sslConfigs) {
    const success = await testSSLConfig(test.name, test.config);
    if (success) successCount++;
    console.log('');
  }

  console.log(`📊 Results: ${successCount}/${sslConfigs.length} configurations worked`);

  if (successCount === 0) {
    console.log('\n🔧 Try these solutions:');
    console.log('   1. Check Railway service is running');
    console.log('   2. Use Railway CLI tunnel: railway connect postgres');
    console.log('   3. Test with Pgweb: pgweb --url "$DATABASE_URL"');
  }
}

runDiagnostics();












