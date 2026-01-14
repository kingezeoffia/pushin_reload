import '../domain/UnlockSession.dart';

/// Service interface for managing unlock sessions.
/// All time-dependent operations require explicit DateTime injection.
abstract class UnlockService {
  /// Record that an unlock session started
  void recordUnlockStart(
      int durationSeconds, String reason, DateTime startTime);

  /// Get remaining unlock time in seconds at the given time
  int getRemainingSeconds(DateTime now);

  /// Check if unlock session is still active at the given time
  bool isActive(DateTime now);

  /// Clear current unlock session
  void clearUnlockSession();

  /// Get current unlock session (null if none active)
  UnlockSession? getCurrentSession();

  /// Extend current unlock session by additional seconds
  void extendUnlockSession(int additionalSeconds, DateTime now);
}
