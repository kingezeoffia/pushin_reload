import 'package:hive_flutter/hive_flutter.dart';
import '../domain/WorkoutHistory.dart';

/// Service for managing workout history storage and retrieval.
/// Uses Hive for persistent local storage of completed workouts.
class WorkoutHistoryService {
  static const String _boxName = 'workout_history';

  late Box<WorkoutHistory> _historyBox;

  /// Initialize the service and open Hive box
  Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapter if not already registered
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(WorkoutHistoryAdapter());
    }

    _historyBox = await Hive.openBox<WorkoutHistory>(_boxName);
  }

  /// Record a completed workout
  Future<void> recordCompletedWorkout({
    required String workoutType,
    required int repsCompleted,
    required int earnedTimeSeconds,
    required String workoutMode,
  }) async {
    final history = WorkoutHistory.create(
      workoutType: workoutType,
      repsCompleted: repsCompleted,
      earnedTimeSeconds: earnedTimeSeconds,
      workoutMode: workoutMode,
    );

    await _historyBox.put(history.id, history);
  }

  /// Get recent workouts (most recent first)
  /// Returns up to [limit] most recent workouts
  Future<List<WorkoutHistory>> getRecentWorkouts({int limit = 10}) async {
    final allWorkouts = _historyBox.values.toList();

    // Sort by completion time (most recent first)
    allWorkouts.sort((a, b) => b.completedAt.compareTo(a.completedAt));

    return allWorkouts.take(limit).toList();
  }

  /// Get workouts from the last N days
  Future<List<WorkoutHistory>> getWorkoutsFromLastDays(int days) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final allWorkouts = _historyBox.values.toList();

    return allWorkouts
        .where((workout) => workout.completedAt.isAfter(cutoffDate))
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  /// Get today's workouts
  Future<List<WorkoutHistory>> getTodaysWorkouts() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final allWorkouts = _historyBox.values.toList();

    return allWorkouts
        .where((workout) =>
            workout.completedAt.isAfter(today) &&
            workout.completedAt.isBefore(tomorrow))
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  /// Get total workouts completed
  Future<int> getTotalWorkoutsCompleted() async {
    return _historyBox.length;
  }

  /// Get total time earned from all workouts (in seconds)
  Future<int> getTotalTimeEarned() async {
    final allWorkouts = _historyBox.values.toList();
    return allWorkouts.fold<int>(
        0, (sum, workout) => sum + workout.earnedTimeSeconds);
  }

  /// Get most popular workout type
  Future<String?> getMostPopularWorkoutType() async {
    final allWorkouts = _historyBox.values.toList();
    if (allWorkouts.isEmpty) return null;

    final typeCount = <String, int>{};
    for (final workout in allWorkouts) {
      typeCount[workout.workoutType] =
          (typeCount[workout.workoutType] ?? 0) + 1;
    }

    final mostPopular =
        typeCount.entries.reduce((a, b) => a.value > b.value ? a : b);

    return mostPopular.key;
  }

  /// Delete a specific workout from history
  Future<void> deleteWorkout(String workoutId) async {
    await _historyBox.delete(workoutId);
  }

  /// Clear all workout history
  Future<void> clearAllHistory() async {
    await _historyBox.clear();
  }

  /// Clean up old workouts (keep last 90 days only)
  Future<void> cleanupOldWorkouts() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    final keysToDelete = <String>[];

    for (final workout in _historyBox.values) {
      if (workout.completedAt.isBefore(cutoffDate)) {
        keysToDelete.add(workout.id);
      }
    }

    for (final key in keysToDelete) {
      await _historyBox.delete(key);
    }
  }

  /// Close the Hive box
  Future<void> dispose() async {
    await _historyBox.close();
  }
}
