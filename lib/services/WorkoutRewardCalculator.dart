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

  /// Workout difficulty multipliers.
  /// Future: Adjust rewards based on workout intensity.
  static const Map<String, double> _difficultyMultipliers = {
    'push-ups': 1.0,
    'squats': 1.0,
    'sit-ups': 1.0,
    'plank': 1.5, // Plank is harder - 60s hold = 90s reward
    'jumping-jacks': 0.8, // Easier - needs more reps for same reward
  };

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
    final earnedSeconds = (repsCompleted * _baseSecondsPerRep * multiplier).round();

    return earnedSeconds;
  }

  /// Calculate required reps to earn a target duration.
  ///
  /// Inverse calculation for UI hints: "Do 20 push-ups to unlock 10 minutes"
  int calculateRequiredReps({
    required String workoutType,
    required int targetSeconds,
  }) {
    if (targetSeconds <= 0) return 0;

    final multiplier = _difficultyMultipliers[workoutType.toLowerCase()] ?? 1.0;
    final requiredReps = (targetSeconds / (_baseSecondsPerRep * multiplier)).ceil();

    return requiredReps;
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




















