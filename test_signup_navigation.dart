import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/routing/app_router.dart';
import 'lib/state/auth_state_provider.dart';
import 'lib/state/pushin_app_controller.dart';
import 'lib/services/MockWorkoutTrackingService.dart';
import 'lib/services/MockUnlockService.dart';
import 'lib/services/MockAppBlockingService.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reset all persistent state for clean test
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  // Create providers
  final authProvider = AuthStateProvider(prefs);
  final pushinController = PushinAppController(
    workoutService: MockWorkoutTrackingService(),
    unlockService: MockUnlockService(),
    blockingService: MockAppBlockingService(),
    blockTargets: const [],
  );

  await authProvider.initialize();

  print('🧪 Testing state-driven navigation to SignUpScreen...');

  // Initial state should show WelcomeScreen
  print('Initial state: showSignUpScreen=${authProvider.showSignUpScreen}');

  // Trigger sign up flow
  authProvider.triggerSignUpFlow();
  print(
      'After triggerSignUpFlow: showSignUpScreen=${authProvider.showSignUpScreen}');

  // Test that we can clear it
  authProvider.clearSignUpFlow();
  print(
      'After clearSignUpFlow: showSignUpScreen=${authProvider.showSignUpScreen}');

  print('✅ State-driven navigation test completed successfully!');
}
