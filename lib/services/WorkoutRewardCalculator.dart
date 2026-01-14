import '../domain/models/workout_mode.dart';

/// Service for calculating unlock time rewards based on workout performance.
///
/// Converts completed workout reps into earned screen time (seconds).
/// - Domain-driven: No magic numbers, all calculations based on workout definitions
/// - Stateless: Pure calculation service, no side effects
/// - Extensible: Easy to add difficulty multipliers, user fitness level scaling
class WorkoutRewardCalculator {
  /// Base time earned per rep in seconds.
  /// Default: 30 seconds per rep (20 reps = 10 minutes)
  static const int _baseSecondsPerRep = 30;

  /// Base rates: reps or seconds per minute of desired screen time for Normal mode
  /// Designed for human psychology - challenging but achievable, motivating for real users
  static const Map<String, double> _baseRatesPerMinute = {
    'push-ups':
        1.0, // 1 rep per minute - feels substantial but doable (10 reps for 10 min)
    'squats':
        1.2, // 1.2 reps per minute - slightly more than push-ups (easier movement)
    'plank':
        3.0, // 3 seconds per minute - time-based, 30 sec for 10 min unlock (manageable)
    'jumping-jacks':
        2.5, // 2.5 reps per minute - higher volume cardio (easier exercise justifies more reps)
    'burpees':
        0.6, // 0.6 reps per minute - very demanding (6 burpees for 10 min feels like real work)
  };

  /// Mode-specific scaling parameters per workout
  /// Standardized maxFactor tiers: Cozy (2.0-3.0x), Normal (3.0-4.0x), Tuff (3.5-5.0x)
  /// Each workout has unique personality while following consistent scaling structure
  static const Map<String, Map<String, dynamic>> _workoutModeProfiles = {
    'push-ups': {
      'cozy': {
        'multiplier': 0.7,
        'min': 3,
        'maxFactor': 2.5
      }, // Very accessible entry level
      'normal': {
        'multiplier': 1.0,
        'min': 5,
        'maxFactor': 3.5
      }, // Standard: 1.0 reps/min base
      'tuff': {
        'multiplier': 1.4,
        'min': 8,
        'maxFactor': 4.0
      }, // Athletic but achievable
    },
    'squats': {
      'cozy': {
        'multiplier': 0.75,
        'min': 4,
        'maxFactor': 2.5
      }, // Slightly easier than push-ups
      'normal': {
        'multiplier': 1.0,
        'min': 6,
        'maxFactor': 3.5
      }, // Standard: 1.2 reps/min base
      'tuff': {
        'multiplier': 1.3,
        'min': 10,
        'maxFactor': 4.0
      }, // Less demanding than push-ups
    },
    'plank': {
      'cozy': {
        'multiplier': 0.7,
        'min': 20,
        'max': 60
      }, // Time-based: seconds, never scary
      'normal': {
        'multiplier': 1.0,
        'min': 30,
        'max': 120
      }, // Balanced time commitment
      'tuff': {
        'multiplier': 1.5,
        'min': 45,
        'max': 180
      }, // Athletic challenge, realistic max
    },
    'jumping-jacks': {
      'cozy': {
        'multiplier': 0.8,
        'min': 10,
        'maxFactor': 3.0
      }, // Fun cardio, higher volume acceptable
      'normal': {
        'multiplier': 1.0,
        'min': 15,
        'maxFactor': 4.0
      }, // Standard: 2.5 reps/min base
      'tuff': {
        'multiplier': 1.2,
        'min': 25,
        'maxFactor': 4.5
      }, // Substantial cardio volume
    },
    'burpees': {
      'cozy': {
        'multiplier': 0.6,
        'min': 2,
        'maxFactor': 2.0
      }, // Very gentle introduction
      'normal': {
        'multiplier': 1.0,
        'min': 3,
        'maxFactor': 3.0
      }, // Standard: 0.6 reps/min base
      'tuff': {
        'multiplier': 1.5,
        'min': 5,
        'maxFactor': 3.5
      }, // Athletic but controlled volume
    },
  };

  /// Legacy workout difficulty multipliers for reward calculations.
  /// Kept for backward compatibility with existing reward system.
  static const Map<String, double> _difficultyMultipliers = {
    'push-ups': 1.0,
    'squats': 1.0,
    'sit-ups': 1.0,
    'plank': 1.5, // Plank is harder - time-based vs rep-based
    'jumping-jacks': 0.8, // Easier - needs more reps for same reward
    'burpees': 1.5, // Most challenging - full body compound movement
  };

  /// Calculate workout target (reps or seconds) based on desired screen time and mode.
  ///
  /// This is the inverse of reward calculation - determines how much work is needed
  /// to earn a specific amount of screen time in a given difficulty mode.
  ///
  /// Returns reps for rep-based workouts, seconds for time-based workouts (plank).
  int calculateWorkoutTarget({
    required String workoutType,
    required WorkoutMode mode,
    required int desiredScreenTimeMinutes,
  }) {
    if (desiredScreenTimeMinutes <= 0) return 0;

    return _calculateWorkoutTargetInternal(
      workoutType.toLowerCase(),
      mode,
      desiredScreenTimeMinutes,
    );
  }

  /// Internal calculation logic with proper error handling
  int _calculateWorkoutTargetInternal(
      String workoutType, WorkoutMode mode, int desiredMinutes) {
    final profile = _workoutModeProfiles[workoutType];
    if (profile == null) {
      // Fallback to simple calculation for unknown workouts
      return (desiredMinutes * (_baseRatesPerMinute[workoutType] ?? 1.0))
          .round();
    }

    final modeSettings = profile[mode.name];
    if (modeSettings == null) {
      // Fallback to normal mode if specific mode not found
      final normalSettings = profile['normal'] ?? {'multiplier': 1.0, 'min': 1};
      return _calculateTargetValue(workoutType, desiredMinutes, normalSettings);
    }

    return _calculateTargetValue(workoutType, desiredMinutes, modeSettings);
  }

  /// Calculate the actual target value using base rate, multiplier, and clamps
  int _calculateTargetValue(String workoutType, int desiredMinutes,
      Map<String, dynamic> modeSettings) {
    final baseRate = _baseRatesPerMinute[workoutType] ?? 1.0;
    final multiplier = modeSettings['multiplier'] as double;
    final minValue = modeSettings['min'] as int;

    // Calculate base target
    final baseTarget = baseRate * desiredMinutes * multiplier;

    // Apply clamps
    if (workoutType == 'plank') {
      // Time-based: use fixed max
      final maxValue = modeSettings['max'] as int;
      return baseTarget.round().clamp(minValue, maxValue);
    } else {
      // Rep-based: use factor-based max relative to desired minutes
      final maxFactor = modeSettings['maxFactor'] as double;
      final maxValue = (desiredMinutes * maxFactor).round();
      return baseTarget.round().clamp(minValue, maxValue);
    }
  }

  /// Calculate earned unlock time in seconds based on reps completed.
  ///
  /// Formula: reps × baseSecondsPerRep × difficultyMultiplier
  ///
  /// Example:
  /// ```dart
  /// final calculator = WorkoutRewardCalculator();
  /// final seconds = calculator.calculateEarnedTime(
  ///   workoutType: 'push-ups',
  ///   repsCompleted: 20,
  /// ); // Returns 600 (10 minutes)
  /// ```
  int calculateEarnedTime({
    required String workoutType,
    required int repsCompleted,
  }) {
    if (repsCompleted <= 0) return 0;

    final multiplier = _difficultyMultipliers[workoutType.toLowerCase()] ?? 1.0;
    final earnedSeconds =
        (repsCompleted * _baseSecondsPerRep * multiplier).round();

    return earnedSeconds;
  }

  /// Calculate required reps to earn a target duration.
  ///
  /// Inverse calculation for UI hints: "Do 20 push-ups to unlock 10 minutes"
  /// Mode parameter is optional for backward compatibility (defaults to normal).
  int calculateRequiredReps({
    required String workoutType,
    required int targetSeconds,
    WorkoutMode mode = WorkoutMode.normal,
  }) {
    if (targetSeconds <= 0) return 0;

    // Convert target seconds to minutes for consistency with new system
    final targetMinutes = (targetSeconds / 60).round();

    // Use new mode-aware target calculation
    final targetValue = calculateWorkoutTarget(
      workoutType: workoutType,
      mode: mode,
      desiredScreenTimeMinutes: targetMinutes,
    );

    return targetValue;
  }

  /// Get human-readable reward description for UI display.
  ///
  /// Example: "20 reps = 10 min unlock"
  String getRewardDescription({
    required String workoutType,
    required int reps,
  }) {
    final seconds = calculateEarnedTime(
      workoutType: workoutType,
      repsCompleted: reps,
    );
    final minutes = (seconds / 60).round();

    return '$reps reps = $minutes min unlock';
  }

  /// Get available workout types with their multipliers.
  /// Useful for displaying workout difficulty indicators in UI.
  Map<String, double> getWorkoutMultipliers() {
    return Map.unmodifiable(_difficultyMultipliers);
  }
}
