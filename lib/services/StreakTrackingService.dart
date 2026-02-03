import 'package:hive_flutter/hive_flutter.dart';

/// Service for tracking workout completion streaks.
/// Tracks consecutive days of workout completion and maintains best streak records.
class StreakTrackingService {
  static const String _streakBoxName = 'streak_tracking_int';
  static const String _dateBoxName = 'streak_tracking_date';
  static const String _currentStreakKey = 'current_streak';
  static const String _bestStreakKey = 'best_streak';
  static const String _totalWorkoutsKey = 'total_workouts';
  static const String _lastWorkoutDateKey = 'last_workout_date';

  Box<int>? _streakBox;
  Box<String>? _dateBox;

  /// Initialize Hive storage.
  /// Must be called before any other methods.
  Future<void> initialize() async {
    _streakBox = await Hive.openBox<int>(_streakBoxName);
    _dateBox = await Hive.openBox<String>(_dateBoxName);
  }

  /// Record a workout completion for today.
  /// This should be called when a workout is successfully completed.
  Future<void> recordWorkoutCompletion() async {
    if (_streakBox == null || _dateBox == null) {
      print('⚠️ StreakTrackingService.recordWorkoutCompletion() - Boxes not initialized');
      return;
    }

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final lastWorkoutDateStr = _dateBox!.get(_lastWorkoutDateKey);
    final lastWorkoutDate = lastWorkoutDateStr != null ? DateTime.parse(lastWorkoutDateStr) : null;

    int currentStreak = _streakBox!.get(_currentStreakKey) ?? 0;
    int bestStreak = _streakBox!.get(_bestStreakKey) ?? 0;
    int totalWorkouts = _streakBox!.get(_totalWorkoutsKey) ?? 0;

    print('🔥 StreakTrackingService.recordWorkoutCompletion() - BEFORE:');
    print('   todayKey: $todayKey');
    print('   lastWorkoutDateStr: $lastWorkoutDateStr');
    print('   lastWorkoutDate: $lastWorkoutDate');
    print('   currentStreak: $currentStreak');
    print('   bestStreak: $bestStreak');
    print('   totalWorkouts: $totalWorkouts');

    // Check if this is a new workout today (for streak logic)
    bool isNewWorkoutToday = true;
    if (lastWorkoutDateStr == todayKey) {
      isNewWorkoutToday = false;
    }

    if (lastWorkoutDate == null) {
      // First workout ever
      currentStreak = 1;
    } else {
      final daysDifference = today.difference(lastWorkoutDate).inDays;

      if (daysDifference == 1) {
        // Consecutive day - increment streak
        currentStreak += 1;
      } else if (daysDifference > 1) {
        // Streak broken - reset to 1
        currentStreak = 1;
      }
      // If daysDifference == 0, they already worked out today - don't change streak
    }

    // Update best streak if current is higher
    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    // Increment total workouts for every workout completed
    totalWorkouts += 1;

    // Save updated values
    await _streakBox!.put(_currentStreakKey, currentStreak);
    await _streakBox!.put(_bestStreakKey, bestStreak);
    await _streakBox!.put(_totalWorkoutsKey, totalWorkouts);
    await _dateBox!.put(_lastWorkoutDateKey, todayKey);

    print('🔥 StreakTrackingService.recordWorkoutCompletion() - AFTER:');
    print('   currentStreak: $currentStreak');
    print('   bestStreak: $bestStreak');
    print('   totalWorkouts: $totalWorkouts');
    print('   lastWorkoutDate: $todayKey');
  }

  /// Get the current streak (consecutive days).
  int getCurrentStreak() {
    if (_streakBox == null) {
      print('⚠️ StreakTrackingService.getCurrentStreak() - Box not initialized, returning 0');
      return 0;
    }
    final value = _streakBox!.get(_currentStreakKey) ?? 0;
    print('🔥 StreakTrackingService.getCurrentStreak() -> $value');
    return value;
  }

  /// Get the best streak ever achieved.
  int getBestStreak() {
    if (_streakBox == null) {
      print('⚠️ StreakTrackingService.getBestStreak() - Box not initialized, returning 0');
      return 0;
    }
    final value = _streakBox!.get(_bestStreakKey) ?? 0;
    print('🔥 StreakTrackingService.getBestStreak() -> $value');
    return value;
  }

  /// Get the total number of workouts completed.
  int getTotalWorkouts() {
    if (_streakBox == null) {
      print('⚠️ StreakTrackingService.getTotalWorkouts() - Box not initialized, returning 0');
      return 0;
    }
    final value = _streakBox!.get(_totalWorkoutsKey) ?? 0;
    print('🔥 StreakTrackingService.getTotalWorkouts() -> $value');
    return value;
  }

  /// Check if today's workout is completed.
  bool isTodayCompleted() {
    if (_dateBox == null) {
      print('⚠️ StreakTrackingService.isTodayCompleted() - Box not initialized, returning false');
      return false;
    }
    final lastWorkoutDateStr = _dateBox!.get(_lastWorkoutDateKey);
    if (lastWorkoutDateStr == null) return false;

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return lastWorkoutDateStr == todayKey;
  }

  /// Reset streaks (for testing or user request).
  Future<void> resetStreaks() async {
    if (_streakBox == null || _dateBox == null) {
      print('⚠️ StreakTrackingService.resetStreaks() - Boxes not initialized');
      return;
    }
    await _streakBox!.clear();
    await _dateBox!.clear();
  }
}
