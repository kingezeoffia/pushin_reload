#!/bin/bash
# PUSHIN' MVP - App Blocking Setup Script
# Run this to install dependencies and generate Hive adapters

set -e

echo "🚀 Setting up PUSHIN' MVP App Blocking Implementation..."
echo ""

# Step 1: Install Flutter dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Step 2: Generate Hive adapters
echo "🔧 Generating Hive type adapters..."
flutter pub run build_runner build --delete-conflicting-outputs

# Step 3: Run tests
echo "✅ Running tests..."
flutter test test/services/workout_reward_calculator_test.dart

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Implement native iOS Screen Time module (ios/Runner/ScreenTimeModule.swift)"
echo "2. Implement native Android UsageStats module (android/app/src/main/kotlin/UsageStatsModule.kt)"
echo "3. Run spike test: flutter run -d 'iPhone 15'"
echo ""
echo "See APP_BLOCKING_IMPLEMENTATION.md for details."





















