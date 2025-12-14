import 'WorkoutTrackingService.dart';
import '../domain/Workout.dart';

/// Mock implementation of WorkoutTrackingService for testing.
/// Tracks workout state with explicit time injection.
class MockWorkoutTrackingService implements WorkoutTrackingService {
  Workout? _currentWorkout;
  int _completedReps = 0;

  @override
  void recordWorkoutStart(Workout workout, DateTime startTime) {
    _currentWorkout = workout;
    _completedReps = 0;
  }

  @override
  void recordRep(DateTime timestamp) {
    if (_currentWorkout != null) {
      _completedReps++;
    }
  }

  @override
  double getProgress(DateTime now) {
    if (_currentWorkout == null) return 0.0;
    return (_completedReps / _currentWorkout!.targetReps).clamp(0.0, 1.0);
  }

  @override
  bool isCompleted(DateTime now) {
    return _currentWorkout != null &&
        _completedReps >= _currentWorkout!.targetReps;
  }

  @override
  void clearWorkout() {
    _currentWorkout = null;
    _completedReps = 0;
  }

  @override
  Workout? getCurrentWorkout() => _currentWorkout;
}
