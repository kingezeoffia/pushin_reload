import 'package:flutter_test/flutter_test.dart';
import 'package:pushin_reload/services/WorkoutRewardCalculator.dart';

void main() {
  group('WorkoutRewardCalculator', () {
    late WorkoutRewardCalculator calculator;

    setUp(() {
      calculator = WorkoutRewardCalculator();
    });

    group('calculateEarnedTime', () {
      test('20 push-ups earns 600 seconds (10 minutes)', () {
        final seconds = calculator.calculateEarnedTime(
          workoutType: 'push-ups',
          repsCompleted: 20,
        );

        expect(seconds, 600); // 20 reps × 30 sec/rep
      });

      test('10 squats earns 300 seconds (5 minutes)', () {
        final seconds = calculator.calculateEarnedTime(
          workoutType: 'squats',
          repsCompleted: 10,
        );

        expect(seconds, 300);
      });

      test('plank has 1.5x difficulty multiplier', () {
        final seconds = calculator.calculateEarnedTime(
          workoutType: 'plank',
          repsCompleted: 10,
        );

        expect(seconds, 450); // 10 × 30 × 1.5
      });

      test('jumping-jacks has 0.8x multiplier (easier)', () {
        final seconds = calculator.calculateEarnedTime(
          workoutType: 'jumping-jacks',
          repsCompleted: 20,
        );

        expect(seconds, 480); // 20 × 30 × 0.8
      });

      test('zero reps returns zero seconds', () {
        final seconds = calculator.calculateEarnedTime(
          workoutType: 'push-ups',
          repsCompleted: 0,
        );

        expect(seconds, 0);
      });

      test('negative reps returns zero seconds', () {
        final seconds = calculator.calculateEarnedTime(
          workoutType: 'push-ups',
          repsCompleted: -5,
        );

        expect(seconds, 0);
      });

      test('unknown workout type uses 1.0 multiplier', () {
        final seconds = calculator.calculateEarnedTime(
          workoutType: 'unknown-workout',
          repsCompleted: 10,
        );

        expect(seconds, 300); // 10 × 30 × 1.0
      });

      test('case-insensitive workout type matching', () {
        final lowercase = calculator.calculateEarnedTime(
          workoutType: 'push-ups',
          repsCompleted: 20,
        );
        
        final uppercase = calculator.calculateEarnedTime(
          workoutType: 'PUSH-UPS',
          repsCompleted: 20,
        );

        expect(lowercase, uppercase);
      });
    });

    group('calculateRequiredReps', () {
      test('600 seconds (10 min) requires 20 push-ups', () {
        final reps = calculator.calculateRequiredReps(
          workoutType: 'push-ups',
          targetSeconds: 600,
        );

        expect(reps, 20);
      });

      test('300 seconds (5 min) requires 10 squats', () {
        final reps = calculator.calculateRequiredReps(
          workoutType: 'squats',
          targetSeconds: 300,
        );

        expect(reps, 10);
      });

      test('rounds up for partial reps needed', () {
        final reps = calculator.calculateRequiredReps(
          workoutType: 'push-ups',
          targetSeconds: 650, // Would need 21.67 reps
        );

        expect(reps, 22); // Rounds up
      });

      test('zero target returns zero reps', () {
        final reps = calculator.calculateRequiredReps(
          workoutType: 'push-ups',
          targetSeconds: 0,
        );

        expect(reps, 0);
      });
    });

    group('getRewardDescription', () {
      test('formats description correctly', () {
        final desc = calculator.getRewardDescription(
          workoutType: 'push-ups',
          reps: 20,
        );

        expect(desc, '20 reps = 10 min unlock');
      });

      test('handles single minute', () {
        final desc = calculator.getRewardDescription(
          workoutType: 'push-ups',
          reps: 2, // 60 seconds = 1 minute
        );

        expect(desc, '2 reps = 1 min unlock');
      });
    });

    group('getWorkoutMultipliers', () {
      test('returns all workout multipliers', () {
        final multipliers = calculator.getWorkoutMultipliers();

        expect(multipliers, isNotEmpty);
        expect(multipliers['push-ups'], 1.0);
        expect(multipliers['plank'], 1.5);
        expect(multipliers['jumping-jacks'], 0.8);
      });

      test('returned map is unmodifiable', () {
        final multipliers = calculator.getWorkoutMultipliers();

        expect(
          () => multipliers['new-workout'] = 2.0,
          throwsUnsupportedError,
        );
      });
    });
  });
}



































