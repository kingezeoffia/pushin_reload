import 'UnlockService.dart';
import '../domain/UnlockSession.dart';

/// Mock implementation of UnlockService for testing.
/// Tracks unlock sessions with explicit time injection.
class MockUnlockService implements UnlockService {
  UnlockSession? _currentSession;

  @override
  void recordUnlockStart(
      int durationSeconds, String reason, DateTime startTime) {
    _currentSession = UnlockSession(
      id: 'session-${startTime.millisecondsSinceEpoch}',
      startTime: startTime,
      durationSeconds: durationSeconds,
      reason: reason,
    );
  }

  @override
  int getRemainingSeconds(DateTime now) {
    if (_currentSession == null) return 0;
    return _currentSession!.getRemainingSeconds(now);
  }

  @override
  bool isActive(DateTime now) {
    if (_currentSession == null) return false;
    return !_currentSession!.isExpired(now);
  }

  @override
  void clearUnlockSession() {
    _currentSession = null;
  }

  @override
  UnlockSession? getCurrentSession() => _currentSession;

  @override
  void extendUnlockSession(int additionalSeconds, DateTime now) {
    if (_currentSession != null) {
      // Create a new session with extended duration from the current time
      final newDuration =
          _currentSession!.getRemainingSeconds(now) + additionalSeconds;
      _currentSession = UnlockSession(
        id: 'extended-${now.millisecondsSinceEpoch}',
        startTime: now,
        durationSeconds: newDuration,
        reason: 'workout_extended',
      );
    }
  }
}
