import 'package:test/test.dart';
import '../lib/controller/PushinController.dart';
import '../lib/domain/Workout.dart';
import '../lib/domain/AppBlockTarget.dart';
import '../lib/domain/PushinState.dart';
import '../lib/services/MockWorkoutTrackingService.dart';
import '../lib/services/MockUnlockService.dart';
import '../lib/services/MockAppBlockingService.dart';

void main() {
  group('PushinController', () {
    late MockWorkoutTrackingService workoutService;
    late MockUnlockService unlockService;
    late MockAppBlockingService blockingService;
    late List<AppBlockTarget> blockTargets;
    late PushinController controller;
    late DateTime baseTime;

    setUp(() {
      workoutService = MockWorkoutTrackingService();
      unlockService = MockUnlockService();
      blockingService = MockAppBlockingService();
      blockTargets = [
        AppBlockTarget(
          id: 'target-1',
          name: 'Social Media',
          type: 'app',
          platformAgnosticIdentifier: 'com.social.media',
        ),
      ];
      baseTime = DateTime(2024, 1, 1, 12, 0, 0);
      controller = PushinController(
        workoutService,
        unlockService,
        blockingService,
        blockTargets,
        gracePeriodSeconds: 5,
      );
    });

    test('Initial state is LOCKED', () {
      expect(controller.currentState, equals(PushinState.locked));
      expect(controller.getBlockedTargets(baseTime), isNotEmpty);
      expect(controller.getAccessibleTargets(baseTime), isEmpty);
    });

    test('LOCKED → EARNING when startWorkout()', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      controller.startWorkout(workout, baseTime);

      expect(controller.currentState, equals(PushinState.earning));
      expect(workoutService.getCurrentWorkout(), equals(workout));
    });

    test('EARNING → UNLOCKED when workout completed via recordRep', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      controller.startWorkout(workout, baseTime);

      // Simulate completing all reps
      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(baseTime.add(Duration(seconds: i)));
      }

      controller.completeWorkout(baseTime.add(const Duration(seconds: 10)));

      expect(controller.currentState, equals(PushinState.unlocked));
      expect(unlockService.getCurrentSession(), isNotNull);
      expect(unlockService.getCurrentSession()!.durationSeconds, equals(180));
      expect(
          controller
              .getBlockedTargets(baseTime.add(const Duration(seconds: 10))),
          isEmpty);
      expect(
          controller
              .getAccessibleTargets(baseTime.add(const Duration(seconds: 10))),
          isNotEmpty);
    });

    test('UnlockSession.durationSeconds equals Workout.earnedTimeSeconds', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      controller.startWorkout(workout, baseTime);

      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(baseTime.add(Duration(seconds: i)));
      }

      controller.completeWorkout(baseTime.add(const Duration(seconds: 10)));

      final session = unlockService.getCurrentSession();
      expect(session, isNotNull);
      expect(session!.durationSeconds, equals(workout.earnedTimeSeconds));
    });

    test('UNLOCKED → EXPIRED when unlock duration ends', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      final startTime = baseTime;
      controller.startWorkout(workout, startTime);

      // Complete workout
      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(startTime.add(Duration(seconds: i)));
      }
      controller.completeWorkout(startTime.add(const Duration(seconds: 10)));

      // Simulate time passing beyond unlock duration (180 seconds)
      final expiredTime = startTime
          .add(const Duration(seconds: 191)); // 10s workout + 181s elapsed
      controller.tick(expiredTime);

      expect(controller.currentState, equals(PushinState.expired));
      expect(controller.getBlockedTargets(expiredTime), isNotEmpty);
      expect(controller.getAccessibleTargets(expiredTime), isEmpty);
    });

    test('EXPIRED persists across multiple tick calls within grace period', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      final startTime = baseTime;
      controller.startWorkout(workout, startTime);

      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(startTime.add(Duration(seconds: i)));
      }
      controller.completeWorkout(startTime.add(const Duration(seconds: 10)));

      // Move to EXPIRED
      final expiredTime = startTime.add(const Duration(seconds: 191));
      controller.tick(expiredTime);
      expect(controller.currentState, equals(PushinState.expired));

      // Multiple ticks within grace period - state must persist
      final tick1 = expiredTime.add(const Duration(seconds: 1));
      controller.tick(tick1);
      expect(controller.currentState, equals(PushinState.expired));

      final tick2 = expiredTime.add(const Duration(seconds: 2));
      controller.tick(tick2);
      expect(controller.currentState, equals(PushinState.expired));

      final tick3 = expiredTime.add(const Duration(seconds: 4));
      controller.tick(tick3);
      expect(controller.currentState, equals(PushinState.expired));
    });

    test('EXPIRED → LOCKED only after gracePeriodSeconds fully elapsed', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      final startTime = baseTime;
      controller.startWorkout(workout, startTime);

      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(startTime.add(Duration(seconds: i)));
      }
      controller.completeWorkout(startTime.add(const Duration(seconds: 10)));

      // Move to EXPIRED
      final expiredTime = startTime.add(const Duration(seconds: 191));
      controller.tick(expiredTime);
      expect(controller.currentState, equals(PushinState.expired));

      // Tick exactly at grace period boundary (4 seconds - still EXPIRED)
      final atGraceBoundary = expiredTime.add(const Duration(seconds: 4));
      controller.tick(atGraceBoundary);
      expect(controller.currentState, equals(PushinState.expired));

      // Tick after grace period fully elapsed (5 seconds = gracePeriodSeconds)
      final afterGracePeriod = expiredTime.add(const Duration(seconds: 5));
      controller.tick(afterGracePeriod);

      expect(controller.currentState, equals(PushinState.locked));
      expect(unlockService.getCurrentSession(), isNull);
    });

    test('cancelWorkout() returns to LOCKED', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      controller.startWorkout(workout, baseTime);
      expect(controller.currentState, equals(PushinState.earning));

      controller.cancelWorkout();

      expect(controller.currentState, equals(PushinState.locked));
      expect(workoutService.getCurrentWorkout(), isNull);
    });

    test('lock() always forces LOCKED from any state', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      // Test from EARNING
      controller.startWorkout(workout, baseTime);
      controller.lock();
      expect(controller.currentState, equals(PushinState.locked));

      // Test from UNLOCKED
      controller.startWorkout(workout, baseTime);
      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(baseTime.add(Duration(seconds: i)));
      }
      controller.completeWorkout(baseTime.add(const Duration(seconds: 10)));
      controller.lock();
      expect(controller.currentState, equals(PushinState.locked));

      // Test from EXPIRED
      controller.startWorkout(workout, baseTime);
      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(baseTime.add(Duration(seconds: i)));
      }
      controller.completeWorkout(baseTime.add(const Duration(seconds: 10)));
      final expiredTime = baseTime.add(const Duration(seconds: 191));
      controller.tick(expiredTime);
      controller.lock();
      expect(controller.currentState, equals(PushinState.locked));
    });

    test('Blocked targets reflect controller state correctly', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      // LOCKED state
      expect(controller.currentState, equals(PushinState.locked));
      expect(controller.getBlockedTargets(baseTime), isNotEmpty);
      expect(controller.getAccessibleTargets(baseTime), isEmpty);

      // EARNING state
      controller.startWorkout(workout, baseTime);
      expect(controller.currentState, equals(PushinState.earning));
      expect(controller.getBlockedTargets(baseTime), isNotEmpty);
      expect(controller.getAccessibleTargets(baseTime), isEmpty);

      // UNLOCKED state
      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(baseTime.add(Duration(seconds: i)));
      }
      controller.completeWorkout(baseTime.add(const Duration(seconds: 10)));
      expect(controller.currentState, equals(PushinState.unlocked));
      expect(
          controller
              .getBlockedTargets(baseTime.add(const Duration(seconds: 10))),
          isEmpty);
      expect(
          controller
              .getAccessibleTargets(baseTime.add(const Duration(seconds: 10))),
          isNotEmpty);

      // EXPIRED state
      final expiredTime = baseTime.add(const Duration(seconds: 191));
      controller.tick(expiredTime);
      expect(controller.currentState, equals(PushinState.expired));
      expect(controller.getBlockedTargets(expiredTime), isNotEmpty);
      expect(controller.getAccessibleTargets(expiredTime), isEmpty);
    });

    test('UNLOCKED state returns empty blockedTargets list', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      controller.startWorkout(workout, baseTime);

      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(baseTime.add(Duration(seconds: i)));
      }
      controller.completeWorkout(baseTime.add(const Duration(seconds: 10)));

      expect(controller.currentState, equals(PushinState.unlocked));
      expect(
          controller
              .getBlockedTargets(baseTime.add(const Duration(seconds: 10))),
          isEmpty);
      expect(
          controller
              .getAccessibleTargets(baseTime.add(const Duration(seconds: 10))),
          isNotEmpty);
      expect(
          controller
              .getAccessibleTargets(baseTime.add(const Duration(seconds: 10)))
              .length,
          equals(blockTargets.length));
    });

    test('getGracePeriodRemaining() returns correct countdown in EXPIRED state',
        () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      // Complete workout and unlock
      controller.startWorkout(workout, baseTime);
      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(baseTime.add(Duration(seconds: i)));
      }
      controller.completeWorkout(baseTime.add(const Duration(seconds: 10)));

      // Grace period returns 0 before entering EXPIRED state
      expect(
          controller.getGracePeriodRemaining(
              baseTime.add(const Duration(seconds: 10))),
          equals(0));

      // Transition to EXPIRED (after 180 seconds unlock + 1 second)
      final expiredTime = baseTime.add(const Duration(seconds: 191));
      controller.tick(expiredTime);
      expect(controller.currentState, equals(PushinState.expired));

      // Grace period should be 5 seconds (full grace period)
      expect(controller.getGracePeriodRemaining(expiredTime), equals(5));

      // After 2 seconds into grace period
      final gracePeriodTime2 = expiredTime.add(const Duration(seconds: 2));
      expect(controller.getGracePeriodRemaining(gracePeriodTime2), equals(3));

      // After 4 seconds into grace period
      final gracePeriodTime4 = expiredTime.add(const Duration(seconds: 4));
      expect(controller.getGracePeriodRemaining(gracePeriodTime4), equals(1));

      // After 5 seconds (grace period fully elapsed)
      final gracePeriodTime5 = expiredTime.add(const Duration(seconds: 5));
      expect(controller.getGracePeriodRemaining(gracePeriodTime5), equals(0));

      // After grace period ends, should still return 0 (clamped)
      final gracePeriodTime6 = expiredTime.add(const Duration(seconds: 6));
      expect(controller.getGracePeriodRemaining(gracePeriodTime6), equals(0));

      // Transition to LOCKED should clear grace period
      controller.tick(gracePeriodTime5);
      expect(controller.currentState, equals(PushinState.locked));
      expect(controller.getGracePeriodRemaining(gracePeriodTime5), equals(0));
    });

    test('getGracePeriodRemaining() returns 0 when not in EXPIRED state', () {
      final workout = Workout(
        id: 'workout-1',
        type: 'jumping_jacks',
        targetReps: 10,
        earnedTimeSeconds: 180,
      );

      // LOCKED state
      expect(controller.getGracePeriodRemaining(baseTime), equals(0));

      // EARNING state
      controller.startWorkout(workout, baseTime);
      expect(
          controller.getGracePeriodRemaining(
              baseTime.add(const Duration(seconds: 5))),
          equals(0));

      // UNLOCKED state
      for (int i = 0; i < 10; i++) {
        workoutService.recordRep(baseTime.add(Duration(seconds: i)));
      }
      controller.completeWorkout(baseTime.add(const Duration(seconds: 10)));
      expect(
          controller.getGracePeriodRemaining(
              baseTime.add(const Duration(seconds: 50))),
          equals(0));
    });
  });
}
