import '../domain/Workout.dart';

/// Service interface for tracking workout progress.
/// All time-dependent operations require explicit DateTime injection.
abstract class WorkoutTrackingService {
  /// Record that a workout session started
  void recordWorkoutStart(Workout workout, DateTime startTime);
  
  /// Record a rep completion at the given timestamp
  void recordRep(DateTime timestamp);
  
  /// Get current workout progress (0.0 to 1.0) at the given time
  double getProgress(DateTime now);
  
  /// Check if current workout is completed at the given time
  bool isCompleted(DateTime now);
  
  /// Clear current workout data
  void clearWorkout();
  
  /// Get current workout (null if none active)
  Workout? getCurrentWorkout();
}

