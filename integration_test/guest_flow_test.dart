import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushin_reload/main.dart';
import 'package:pushin_reload/state/auth_state_provider.dart';
import 'package:pushin_reload/state/pushin_app_controller.dart';
import 'package:pushin_reload/services/MockAppBlockingService.dart';
import 'package:pushin_reload/services/MockUnlockService.dart';
import 'package:pushin_reload/services/MockWorkoutTrackingService.dart';
import 'package:pushin_reload/services/DailyUsageTracker.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Startup and Navigation Flows', () {
    testWidgets('Basic app startup test', (WidgetTester tester) async {
      // Reset all persistent state for clean test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Create providers (mimicking main() but skipping deep link initialization)
      final authProvider = AuthStateProvider(prefs);
      await authProvider.initialize();

      final usageTracker = DailyUsageTracker();
      await usageTracker.initialize();

      final pushinController = PushinAppController(
        workoutService: MockWorkoutTrackingService(),
        unlockService: MockUnlockService(),
        blockingService: MockAppBlockingService(),
        blockTargets: const [],
        usageTracker: usageTracker,
        authProvider: authProvider,
        // Skip deep link handler initialization for test
      );

      // Launch the app using tester.pumpWidget() - this is the direct widget test approach
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthStateProvider>.value(
                value: authProvider),
            ChangeNotifierProvider<PushinAppController>.value(
                value: pushinController),
          ],
          child: const PushinApp(),
        ),
      );

      // Wait for all animations and frames to settle
      // Note: await calls must be in Dart code, not in terminal
      await tester.pumpAndSettle();

      // Verify exactly one MaterialApp exists
      expect(find.byType(MaterialApp), findsOneWidget,
          reason: 'Must have exactly one MaterialApp in entire app');

      // In test environment, uni_links plugin is not available, but the app should handle this gracefully
      // The DeepLinkHandler has built-in error handling for MissingPluginException

      // Verify the app shows the expected initial screen
      expect(find.byKey(const ValueKey('welcome_screen')), findsOneWidget,
          reason:
              'First launch should show welcome screen for unauthenticated users');
    });
  });
}
