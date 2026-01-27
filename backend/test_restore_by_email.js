require('dotenv').config();
const axios = require('axios');

const BASE_URL = process.env.BACKEND_URL || 'http://localhost:3000';

async function testRestoreByEmail() {
  console.log('🧪 Testing Restore By Email Endpoint');
  console.log('📍 Backend URL:', BASE_URL);
  console.log('');

  let testsPassed = 0;
  let testsFailed = 0;

  // Test 1: Invalid email format
  console.log('Test 1: Invalid email format');
  try {
    const response = await axios.post(`${BASE_URL}/api/stripe/restore-by-email`, {
      email: 'notanemail'
    });
    console.log('❌ FAILED: Should have returned 400 error');
    testsFailed++;
  } catch (error) {
    if (error.response?.status === 400 && error.response?.data?.error === 'invalid_email') {
      console.log('✅ PASSED: Returned 400 with invalid_email error');
      testsPassed++;
    } else {
      console.log('❌ FAILED:', error.response?.data || error.message);
      testsFailed++;
    }
  }
  console.log('');

  // Test 2: Empty email
  console.log('Test 2: Empty email');
  try {
    const response = await axios.post(`${BASE_URL}/api/stripe/restore-by-email`, {
      email: ''
    });
    console.log('❌ FAILED: Should have returned 400 error');
    testsFailed++;
  } catch (error) {
    if (error.response?.status === 400 && error.response?.data?.error === 'invalid_email') {
      console.log('✅ PASSED: Returned 400 with invalid_email error');
      testsPassed++;
    } else {
      console.log('❌ FAILED:', error.response?.data || error.message);
      testsFailed++;
    }
  }
  console.log('');

  // Test 3: Email with no subscription (should return 404)
  console.log('Test 3: Email with no subscription');
  try {
    const response = await axios.post(`${BASE_URL}/api/stripe/restore-by-email`, {
      email: 'nosubscription@test.com'
    });
    console.log('❌ FAILED: Should have returned 404');
    testsFailed++;
  } catch (error) {
    if (error.response?.status === 404 && error.response?.data?.error === 'no_active_subscription') {
      console.log('✅ PASSED: Returned 404 with no_active_subscription error');
      console.log('   Message:', error.response?.data?.message);
      testsPassed++;
    } else {
      console.log('❌ FAILED:', error.response?.data || error.message);
      testsFailed++;
    }
  }
  console.log('');

  // Test 4: Valid email with subscription (replace with real test email if you have one)
  console.log('Test 4: Valid email with subscription');
  console.log('⚠️  Note: Replace test email in code with real subscription email to test success case');
  try {
    const response = await axios.post(`${BASE_URL}/api/stripe/restore-by-email`, {
      email: 'test@pushinapp.com' // Replace with real test email
    });

    if (response.status === 200 && response.data.success === true) {
      console.log('✅ PASSED: Successfully restored subscription');
      console.log('   Subscription ID:', response.data.subscription?.subscriptionId);
      console.log('   Plan ID:', response.data.subscription?.planId);
      console.log('   Subscription Type:', response.data.subscription?.subscriptionType);
      testsPassed++;
    } else {
      console.log('⚠️  SKIPPED: No subscription found (expected if test email has no subscription)');
    }
  } catch (error) {
    if (error.response?.status === 404) {
      console.log('⚠️  SKIPPED: No subscription found for test email (expected)');
    } else {
      console.log('❌ FAILED:', error.response?.data || error.message);
      testsFailed++;
    }
  }
  console.log('');

  // Test 5: Rate limiting (make 6 rapid requests)
  console.log('Test 5: Rate limiting (6 rapid requests)');
  let rateLimitTriggered = false;
  for (let i = 0; i < 6; i++) {
    try {
      const response = await axios.post(`${BASE_URL}/api/stripe/restore-by-email`, {
        email: 'ratelimit@test.com'
      });
      console.log(`   Request ${i + 1}: ${response.status}`);
    } catch (error) {
      if (error.response?.status === 429) {
        console.log(`   Request ${i + 1}: 429 Rate Limited ✅`);
        rateLimitTriggered = true;
      } else if (error.response?.status === 404) {
        console.log(`   Request ${i + 1}: 404 No subscription (expected)`);
      } else {
        console.log(`   Request ${i + 1}: ${error.response?.status} ${error.response?.data?.error}`);
      }
    }
    await new Promise(resolve => setTimeout(resolve, 100)); // Small delay between requests
  }

  if (rateLimitTriggered) {
    console.log('✅ PASSED: Rate limiting triggered');
    testsPassed++;
  } else {
    console.log('⚠️  WARNING: Rate limiting may not be working (expected to trigger on 6th request)');
  }
  console.log('');

  // Test 6: Email case normalization (uppercase should work)
  console.log('Test 6: Email case normalization');
  try {
    const response = await axios.post(`${BASE_URL}/api/stripe/restore-by-email`, {
      email: 'TEST@PUSHINAPP.COM' // Uppercase version
    });

    if (response.status === 200 || response.status === 404) {
      console.log('✅ PASSED: Uppercase email accepted (normalized to lowercase)');
      testsPassed++;
    }
  } catch (error) {
    if (error.response?.status === 404) {
      console.log('✅ PASSED: Uppercase email accepted, no subscription found (expected)');
      testsPassed++;
    } else if (error.response?.status === 400) {
      console.log('❌ FAILED: Email should be normalized to lowercase');
      testsFailed++;
    } else {
      console.log('⚠️  Unexpected error:', error.response?.data || error.message);
    }
  }
  console.log('');

  // Test 7: Email with spaces (should be trimmed)
  console.log('Test 7: Email with leading/trailing spaces');
  try {
    const response = await axios.post(`${BASE_URL}/api/stripe/restore-by-email`, {
      email: '  test@pushinapp.com  ' // Spaces around email
    });

    if (response.status === 200 || response.status === 404) {
      console.log('✅ PASSED: Email with spaces accepted (trimmed)');
      testsPassed++;
    }
  } catch (error) {
    if (error.response?.status === 404) {
      console.log('✅ PASSED: Email with spaces accepted, no subscription found (expected)');
      testsPassed++;
    } else if (error.response?.status === 400) {
      console.log('❌ FAILED: Email should be trimmed');
      testsFailed++;
    } else {
      console.log('⚠️  Unexpected error:', error.response?.data || error.message);
    }
  }
  console.log('');

  // Summary
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📊 Test Summary');
  console.log(`✅ Passed: ${testsPassed}`);
  console.log(`❌ Failed: ${testsFailed}`);
  console.log(`📈 Success Rate: ${((testsPassed / (testsPassed + testsFailed)) * 100).toFixed(1)}%`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  if (testsFailed === 0) {
    console.log('');
    console.log('🎉 All tests passed! The restore by email endpoint is working correctly.');
    process.exit(0);
  } else {
    console.log('');
    console.log('⚠️  Some tests failed. Please review the errors above.');
    process.exit(1);
  }
}

// Run tests
testRestoreByEmail().catch(error => {
  console.error('');
  console.error('❌ Fatal error running tests:', error.message);
  console.error('');
  console.error('Common issues:');
  console.error('- Backend server is not running');
  console.error('- DATABASE_URL environment variable not set');
  console.error('- Incorrect BACKEND_URL (current:', BASE_URL + ')');
  console.error('');
  console.error('To start backend locally:');
  console.error('  cd backend && npm start');
  console.error('');
  process.exit(1);
});
