#!/usr/bin/env node

/**
 * Development utility to reset onboarding state
 *
 * Run with: node reset-onboarding.js
 */

const path = require('path');

// This is a simple script to help reset onboarding state
// Since we need access to SharedPreferences which is Flutter-specific,
// this script provides instructions for manual reset

console.log('🔄 PUSHIN Onboarding Reset Utility');
console.log('=====================================');
console.log('');
console.log('To reset onboarding state and start from the welcome screen:');
console.log('');
console.log('1. Tap the red "RESET" button in the top-right corner of the app (only visible in debug mode)');
console.log('');
console.log('OR manually clear the SharedPreferences:');
console.log('');
console.log('Option A - From Android Studio/VS Code:');
console.log('   - Run the app once, then stop it');
console.log('   - Go to Device File Explorer > data > data > [your.app.package] > shared_prefs');
console.log('   - Delete the XML files containing onboarding data');
console.log('');
console.log('Option B - From terminal (Android):');
console.log('   adb shell pm clear [your.app.package.id]');
console.log('');
console.log('Option C - iOS Simulator:');
console.log('   - Reset the simulator: Simulator > Device > Erase All Content and Settings');
console.log('');
console.log('The red RESET button in debug mode is the easiest option!');
console.log('It will immediately reset the state and restart the app flow from the beginning.');











