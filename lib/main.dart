import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controller/PushinAppController.dart';
import 'domain/AppBlockTarget.dart';
import 'services/MockWorkoutTrackingService.dart';
import 'services/MockUnlockService.dart';
import 'services/MockAppBlockingService.dart';
import 'services/DailyUsageTracker.dart';
import 'services/WorkoutRewardCalculator.dart';
import 'ui/screens/HomeScreen.dart';
import 'ui/screens/onboarding/OnboardingWelcomeScreen.dart';
import 'ui/screens/workout/WorkoutSelectionScreen.dart';
import 'ui/screens/settings/SettingsScreen.dart';
import 'ui/screens/settings/ManageAppsScreen.dart';
import 'ui/screens/paywall/PaywallScreen.dart';
import 'ui/theme/pushin_theme.dart';

/// PUSHIN MVP - Main Entry Point
///
/// Features:
/// - Platform-realistic app blocking with UX overlay
/// - Daily usage tracking with plan-based caps
/// - Workout reward calculation
/// - GO Club-inspired dark theme
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  final usageTracker = DailyUsageTracker();
  await usageTracker.initialize();

  runApp(PushinApp(usageTracker: usageTracker));
}

class PushinApp extends StatelessWidget {
  final DailyUsageTracker? usageTracker;

  const PushinApp({
    Key? key,
    required this.usageTracker,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize services (mock implementations for MVP)
    final workoutService = MockWorkoutTrackingService();
    final unlockService = MockUnlockService();
    final blockingService = MockAppBlockingService();
    final rewardCalculator = WorkoutRewardCalculator();

    // Define block targets
    final blockTargets = [
      AppBlockTarget(
        id: 'target-1',
        name: 'Instagram',
        type: 'app',
        platformAgnosticIdentifier: 'com.instagram.android',
      ),
      AppBlockTarget(
        id: 'target-2',
        name: 'TikTok',
        type: 'app',
        platformAgnosticIdentifier: 'com.tiktok.app',
      ),
    ];

    // Create PushinAppController
    final appController = PushinAppController(
      workoutService: workoutService,
      unlockService: unlockService,
      blockingService: blockingService,
      blockTargets: blockTargets,
      usageTracker: usageTracker,
      rewardCalculator: rewardCalculator,
      gracePeriodSeconds: 30, // Free plan: 30 seconds
    );

    // Initialize controller
    appController.initialize();

    return ChangeNotifierProvider.value(
      value: appController,
      child: MaterialApp(
        title: 'PUSHIN\'',
        debugShowCheckedModeBanner: false,
        theme: PushinTheme.darkTheme,
        initialRoute: '/onboarding',
        routes: {
          '/onboarding': (context) => OnboardingWelcomeScreen(),
          '/home': (context) => HomeScreen(),
          '/workout-selection': (context) => WorkoutSelectionScreen(),
          '/settings': (context) => SettingsScreen(),
          '/paywall': (context) => PaywallScreen(),
        },
      ),
    );
  }
}
