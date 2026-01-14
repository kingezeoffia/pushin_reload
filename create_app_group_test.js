// Test script to check App Group communication
const { execSync } = require('child_process');

// Test App Group UserDefaults
console.log('🔍 Testing App Group communication...\n');

// Check if we can access the App Group
try {
  const result = execSync('defaults read group.com.pushin.app should_show_workout 2>/dev/null || echo "Key not found"', { encoding: 'utf8' });
  console.log('📱 should_show_workout:', result.trim());
} catch (e) {
  console.log('❌ Error reading App Group:', e.message);
}

try {
  const result = execSync('defaults read group.com.pushin.app pending_notification_id 2>/dev/null || echo "Key not found"', { encoding: 'utf8' });
  console.log('📱 pending_notification_id:', result.trim());
} catch (e) {
  console.log('❌ Error reading App Group:', e.message);
}

try {
  const result = execSync('defaults read group.com.pushin.app notification_expires_at 2>/dev/null || echo "Key not found"', { encoding: 'utf8' });
  console.log('📱 notification_expires_at:', result.trim());
} catch (e) {
  console.log('❌ Error reading App Group:', e.message);
}

console.log('\n✅ App Group test complete');