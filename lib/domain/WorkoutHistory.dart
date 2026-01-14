import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'WorkoutHistory.g.dart';

/// Domain model for tracking completed workout history.
/// Stores workout completion data for display in Recent Workouts sections.
@HiveType(typeId: 1)
class WorkoutHistory extends HiveObject {
  /// Unique identifier for this workout completion
  @HiveField(0)
  final String id;

  /// Workout type (push-ups, squats, plank, jumping-jacks, burpees)
  @HiveField(1)
  final String workoutType;

  /// Number of reps completed
  @HiveField(2)
  final int repsCompleted;

  /// Screen time earned in seconds
  @HiveField(3)
  final int earnedTimeSeconds;

  /// Workout mode used (cozy, normal, tuff)
  @HiveField(4)
  final String workoutMode;

  /// Timestamp when workout was completed
  @HiveField(5)
  final DateTime completedAt;

  WorkoutHistory({
    required this.id,
    required this.workoutType,
    required this.repsCompleted,
    required this.earnedTimeSeconds,
    required this.workoutMode,
    required this.completedAt,
  });

  /// Create a new workout history entry
  factory WorkoutHistory.create({
    required String workoutType,
    required int repsCompleted,
    required int earnedTimeSeconds,
    required String workoutMode,
  }) {
    return WorkoutHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workoutType: workoutType,
      repsCompleted: repsCompleted,
      earnedTimeSeconds: earnedTimeSeconds,
      workoutMode: workoutMode,
      completedAt: DateTime.now(),
    );
  }

  /// Get display name for workout type
  String get displayName {
    switch (workoutType.toLowerCase()) {
      case 'push-ups':
        return 'Push-Ups';
      case 'squats':
        return 'Squats';
      case 'plank':
        return 'Plank';
      case 'jumping-jacks':
        return 'Jumping Jacks';
      case 'burpees':
        return 'Burpees';
      default:
        return workoutType;
    }
  }

  /// Get icon for workout type
  IconData get icon {
    switch (workoutType.toLowerCase()) {
      case 'push-ups':
        return Icons.fitness_center;
      case 'squats':
        return Icons.airline_seat_legroom_normal;
      case 'plank':
        return Icons.self_improvement;
      case 'jumping-jacks':
        return Icons.directions_run;
      case 'burpees':
        return Icons.sports_gymnastics;
      default:
        return Icons.sports_gymnastics;
    }
  }

  /// Get earned time formatted as minutes
  String get earnedTimeDisplay {
    final minutes = (earnedTimeSeconds / 60).round();
    return '$minutes min';
  }

  /// Get workout mode display name
  String get workoutModeDisplay {
    switch (workoutMode.toLowerCase()) {
      case 'cozy':
        return 'Cozy';
      case 'normal':
        return 'Normal';
      case 'tuff':
        return 'Tuff';
      default:
        return workoutMode;
    }
  }

  /// Get relative time display (Today, Yesterday, X days ago)
  String get relativeTimeDisplay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDate =
        DateTime(completedAt.year, completedAt.month, completedAt.day);

    final difference = today.difference(workoutDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference <= 7) {
      return '$difference days ago';
    } else {
      return '${completedAt.month}/${completedAt.day}';
    }
  }

  @override
  String toString() {
    return 'WorkoutHistory(id: $id, type: $workoutType, reps: $repsCompleted, earned: ${earnedTimeDisplay}, mode: $workoutMode, date: $relativeTimeDisplay)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutHistory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
