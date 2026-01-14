import '../domain/PushinState.dart';
import '../domain/Workout.dart';
import '../services/WorkoutTrackingService.dart';
import '../services/UnlockService.dart';
import '../services/AppBlockingService.dart';
import '../domain/AppBlockTarget.dart';

/// Central controller managing PUSHIN MVP state machine.
/// All time-dependent operations require explicit DateTime injection.
/// Single source of truth for application state.
class PushinController {
  PushinState _currentState = PushinState.locked;

  final WorkoutTrackingService _workoutService;
  final UnlockService _unlockService;
  final AppBlockingService _blockingService;
  final List<AppBlockTarget> _blockTargets;

  final int _gracePeriodSeconds;
  DateTime? _expiredAt;

  PushinController(
    this._workoutService,
    this._unlockService,
    this._blockingService,
    this._blockTargets, {
    int gracePeriodSeconds = 0, // Instant blocking - no grace period
  }) : _gracePeriodSeconds = gracePeriodSeconds;

  PushinState get currentState => _currentState;

  /// LOCKED → EARNING or UNLOCKED → EARNING (allow stacking workouts)
  void startWorkout(Workout workout, DateTime now) {
    if (_currentState == PushinState.locked ||
        _currentState == PushinState.unlocked) {
      _workoutService.recordWorkoutStart(workout, now);
      _currentState = PushinState.earning;
    }
  }

  /// EARNING → UNLOCKED (when workout completed)
  /// Also handles extending unlock time when already unlocked
  void completeWorkout(DateTime now) {
    if (_currentState == PushinState.earning &&
        _workoutService.isCompleted(now)) {
      final workout = _workoutService.getCurrentWorkout();
      if (workout != null) {
        _unlockService.recordUnlockStart(
            workout.earnedTimeSeconds, 'workout_completed', now);
        _workoutService.clearWorkout();
        _currentState = PushinState.unlocked;
      }
    } else if (_currentState == PushinState.unlocked) {
      // Extend existing unlock session with additional earned time
      final workout = _workoutService.getCurrentWorkout();
      if (workout != null) {
        _unlockService.extendUnlockSession(workout.earnedTimeSeconds, now);
        _workoutService.clearWorkout();
        // Stay in unlocked state
      }
    }
  }

  /// EARNING → LOCKED (cancel workout)
  void cancelWorkout() {
    if (_currentState == PushinState.earning) {
      _workoutService.clearWorkout();
      _currentState = PushinState.locked;
    }
  }

  /// Time-based transitions (called by external timer)
  /// Idempotent: repeated calls with same time produce same result
  void tick(DateTime now) {
    switch (_currentState) {
      case PushinState.unlocked:
        if (!_unlockService.isActive(now)) {
          // Set expiredAt exactly once when transitioning to EXPIRED
          if (_expiredAt == null) {
            _expiredAt = now;
          }
          _currentState = PushinState.expired;
        }
        break;

      case PushinState.expired:
        // EXPIRED persists until grace period fully elapsed
        if (_expiredAt != null &&
            now.difference(_expiredAt!).inSeconds >= _gracePeriodSeconds) {
          _unlockService.clearUnlockSession();
          _expiredAt = null;
          _currentState = PushinState.locked;
        }
        // If grace period not elapsed, remain in EXPIRED (idempotent)
        break;

      default:
        break;
    }
  }

  /// Any state → LOCKED (manual lock)
  void lock() {
    _workoutService.clearWorkout();
    _unlockService.clearUnlockSession();
    _expiredAt = null;
    _currentState = PushinState.locked;
  }

  // Query methods - derived from controller state
  // Blocking semantics are derived from target lists, not booleans.

  /// Get blocked targets for current state
  List<String> getBlockedTargets(DateTime now) =>
      _blockingService.getBlockedTargets(_currentState, _blockTargets);

  /// Get accessible targets for current state
  List<String> getAccessibleTargets(DateTime now) =>
      _blockingService.getAccessibleTargets(_currentState, _blockTargets);

  double getWorkoutProgress(DateTime now) => _workoutService.getProgress(now);

  int getUnlockTimeRemaining(DateTime now) =>
      _unlockService.getRemainingSeconds(now);

  /// Get total unlock duration in seconds (0 if no active session)
  int getTotalUnlockDuration() {
    final session = _unlockService.getCurrentSession();
    return session?.durationSeconds ?? 0;
  }

  /// Expose workout service for manual rep recording
  WorkoutTrackingService get workoutService => _workoutService;

  /// Get remaining grace period time in seconds
  /// Returns 0 if not in EXPIRED state or grace period has elapsed
  /// Derived from internal _expiredAt and _gracePeriodSeconds tracking
  int getGracePeriodRemaining(DateTime now) {
    if (_expiredAt == null) return 0;

    final elapsedSeconds = now.difference(_expiredAt!).inSeconds;
    final remaining = _gracePeriodSeconds - elapsedSeconds;

    return remaining > 0 ? remaining : 0;
  }
}
