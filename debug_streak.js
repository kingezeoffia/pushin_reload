const fs = require('fs');
const path = require('path');

console.log('=== STREAK DEBUG SCRIPT ===\n');

// Check SharedPreferences (StreakTracker)
console.log('1. Checking SharedPreferences (StreakTracker):');
try {
  // On iOS, SharedPreferences are stored in a specific location
  // For debugging, let's check if we can find any prefs files
  console.log('   - SharedPreferences data location varies by platform');
  console.log('   - This needs to be checked in the Flutter app');
} catch (e) {
  console.log('   - Error:', e.message);
}

// Check Hive data
console.log('\n2. Checking Hive database files:');
const possibleHivePaths = [
  './streak_tracking_int.hive',
  './streak_tracking_date.hive',
  './ios/Runner/Documents/streak_tracking_int.hive',
  './ios/Runner/Documents/streak_tracking_date.hive',
  './android/app/src/main/assets/streak_tracking_int.hive',
  './android/app/src/main/assets/streak_tracking_date.hive'
];

possibleHivePaths.forEach(path => {
  try {
    if (fs.existsSync(path)) {
      const stats = fs.statSync(path);
      console.log(`   ✓ Found: ${path} (${stats.size} bytes)`);
    } else {
      console.log(`   ✗ Not found: ${path}`);
    }
  } catch (e) {
    console.log(`   ✗ Error checking ${path}: ${e.message}`);
  }
});

// Check for any other potential data files
console.log('\n3. Looking for other data files:');
try {
  const files = fs.readdirSync('.').filter(f =>
    f.includes('streak') || f.includes('workout') || f.endsWith('.hive')
  );
  if (files.length > 0) {
    files.forEach(f => console.log(`   - ${f}`));
  } else {
    console.log('   - No streak/workout data files found');
  }
} catch (e) {
  console.log('   - Error:', e.message);
}

console.log('\n=== RECOMMENDATIONS ===');
console.log('1. Run the app and check the actual displayed values');
console.log('2. Use Flutter dev tools to inspect the controller state');
console.log('3. Check if workouts are actually being recorded');
console.log('4. Verify the streak calculation logic is working correctly');