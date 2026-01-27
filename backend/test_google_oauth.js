// Test Google OAuth SSL connection
const axios = require('axios');
const https = require('https');
const tls = require('tls');

async function testGoogleOAuth() {
  console.log('Testing Google OAuth SSL connection...');

  try {
    // Configure axios with proper SSL settings for Google OAuth
    const httpsAgent = new https.Agent({
      rejectUnauthorized: true, // Enable SSL certificate validation
      // Use standard root certificates
      ca: tls.rootCertificates,
      // Additional timeout and retry settings
      timeout: 10000,
      keepAlive: false
    });

    // Test with a simple request to Google's OAuth endpoint
    console.log('Making request to Google OAuth endpoint...');
    const response = await axios.get('https://oauth2.googleapis.com/.well-known/openid_configuration', {
      httpsAgent: httpsAgent,
      timeout: 10000
    });

    console.log('✅ SUCCESS: Google OAuth endpoint reachable');
    console.log('Status:', response.status);
    console.log('Response keys:', Object.keys(response.data));

  } catch (error) {
    console.error('❌ FAILED: Google OAuth SSL connection failed');
    console.error('Error:', error.message);
    if (error.code) {
      console.error('Error code:', error.code);
    }
  }
}

testGoogleOAuth();