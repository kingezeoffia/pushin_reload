/**
 * Test script to verify backend authentication integration
 * Run with: node test_auth_integration.js
 */

const axios = require('axios');

const BASE_URL = 'https://pushin-production.up.railway.app/api';

async function testAuthEndpoints() {
  console.log('🧪 Testing Pushin Authentication Integration\n');

  try {
    // Test 1: Health check
    console.log('1️⃣ Testing health endpoint...');
    const healthResponse = await axios.get(`${BASE_URL}/health`);
    console.log('✅ Health check:', healthResponse.data);

    // Test 2: Register new user
    console.log('\n2️⃣ Testing user registration...');
    const registerResponse = await axios.post(`${BASE_URL}/auth/register`, {
      email: `test${Date.now()}@example.com`,
      password: 'test123456'
    });
    console.log('✅ Registration successful:', registerResponse.data);

    const { accessToken, refreshToken } = registerResponse.data.data;

    // Test 3: Get user profile
    console.log('\n3️⃣ Testing get user profile...');
    const profileResponse = await axios.get(`${BASE_URL}/auth/me`, {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });
    console.log('✅ Profile fetch successful:', profileResponse.data);

    // Test 4: Refresh token
    console.log('\n4️⃣ Testing token refresh...');
    const refreshResponse = await axios.post(`${BASE_URL}/auth/refresh`, {
      refreshToken: refreshToken
    });
    console.log('✅ Token refresh successful');

    // Test 5: Logout
    console.log('\n5️⃣ Testing logout...');
    const logoutResponse = await axios.post(`${BASE_URL}/auth/logout`, {}, {
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });
    console.log('✅ Logout successful:', logoutResponse.data);

    // Test 6: Test login with existing user
    console.log('\n6️⃣ Testing login with existing user...');
    const loginResponse = await axios.post(`${BASE_URL}/auth/login`, {
      email: 'test@example.com',
      password: 'test123'
    });
    console.log('✅ Login result:', loginResponse.data.success ? 'Success' : 'Failed');

  } catch (error) {
    console.error('❌ Test failed:', error.response?.data || error.message);
  }
}

testAuthEndpoints();











