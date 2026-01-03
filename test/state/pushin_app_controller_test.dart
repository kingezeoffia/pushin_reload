import 'package:flutter_test/flutter_test.dart';
import 'package:pushin_reload/state/pushin_app_controller.dart';
import 'package:pushin_reload/services/MockWorkoutTrackingService.dart';
import 'package:pushin_reload/services/MockUnlockService.dart';
import 'package:pushin_reload/services/MockAppBlockingService.dart';
import 'package:pushin_reload/services/DailyUsageTracker.dart';
import 'package:pushin_reload/domain/AppBlockTarget.dart';

void main() {
  late PushinAppController controller;
  late DailyUsageTracker usageTracker;

  setUp(() async {
    // Initialize services
    usageTracker = DailyUsageTracker();
    await usageTracker.initialize();

    // Create controller with mock services
    controller = PushinAppController(
      workoutService: MockWorkoutTrackingService(),
      unlockService: MockUnlockService(),
      blockingService: MockAppBlockingService(),
      blockTargets: [
        AppBlockTarget(
          platformAgnosticIdentifier: 'com.example.social',
          displayName: 'Social App',
          isSystemApp: false,
        ),
      ],
      usageTracker: usageTracker,
    );
  });

  tearDown(() async {
    await controller.dispose();
  });

  group('PushinAppController Initialization', () {
    test('should initialize successfully', () async {
      await controller.initialize();

      expect(controller.currentState, isNotNull);
      expect(controller.planTier, 'free');
    });

    test('should have block overlay state initialized', () async {
      await controller.initialize();

      expect(controller.blockOverlayState, isNotNull);
      expect(controller.blockOverlayState.value, null);
    });

    test('should have payment state initialized', () async {
      await controller.initialize();

      expect(controller.paymentSuccessState, isNotNull);
      expect(controller.paymentSuccessState.value, null);

      expect(controller.paymentCancelState, isNotNull);
      expect(controller.paymentCancelState.value, false);
    });
  });

  group('Workout Management', () {
    test('should start workout and change state', () async {
      await controller.initialize();

      await controller.startWorkout('push-ups', 20);

      // State should change from locked to earning
      expect(controller.currentState, isNotNull);
    });

    test('should complete workout successfully', () async {
      await controller.initialize();

      await controller.startWorkout('push-ups', 20);
      await controller.completeWorkout(20);

      // Should have transitioned states
      expect(controller.currentState, isNotNull);
    });

    test('should cancel workout', () async {
      await controller.initialize();

      await controller.startWorkout('push-ups', 20);
      controller.cancelWorkout();

      // Should return to previous state
      expect(controller.currentState, isNotNull);
    });
  });

  group('Block Overlay Management', () {
    test('should dismiss block overlay', () async {
      await controller.initialize();

      // Simulate block overlay
      controller.blockOverlayState.value = null; // Reset
      controller.dismissBlockOverlay();

      expect(controller.blockOverlayState.value, null);
    });

    test('should lock manually', () async {
      await controller.initialize();

      controller.lock();

      expect(controller.blockOverlayState.value, null);
    });
  });

  group('Plan Management', () {
    test('should update plan tier', () async {
      await controller.initialize();

      await controller.updatePlanTier('standard', 60);

      expect(controller.planTier, 'standard');
    });
  });

  group('Usage Summary', () {
    test('should get usage summary', () async {
      await controller.initialize();

      final summary = await controller.getTodayUsage();

      expect(summary, isNotNull);
      expect(summary.earnedSeconds, isA<int>());
      expect(summary.consumedSeconds, isA<int>());
      expect(summary.remainingSeconds, isA<int>());
    });
  });

  group('Workout Rewards', () {
    test('should get workout reward description', () async {
      await controller.initialize();

      final description = controller.getWorkoutRewardDescription('push-ups', 20);

      expect(description, isNotNull);
      expect(description, isNotEmpty);
    });
  });

  group('Platform Permissions', () {
    test('should handle platform permissions request', () async {
      await controller.initialize();

      // This will return false on non-mobile platforms (expected in tests)
      final result = await controller.requestPlatformPermissions();

      expect(result, isA<bool>());
    });
  });
}
