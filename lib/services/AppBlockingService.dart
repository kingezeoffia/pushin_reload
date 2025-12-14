import '../domain/PushinState.dart';
import '../domain/AppBlockTarget.dart';

/// Service interface for determining content blocking state.
/// Pure logic based on application state - no time dependencies.
/// 
/// UI must derive blocking purely from target lists, not booleans.
/// This contract ensures platform-agnostic blocking decisions that work
/// with both Apple Screen Time and Android equivalents.
abstract class AppBlockingService {
  /// Get blocked targets for given state
  /// Returns list of platformAgnosticIdentifier strings for targets that should be blocked
  List<String> getBlockedTargets(PushinState currentState, List<AppBlockTarget> allTargets);
  
  /// Get accessible targets for given state
  /// Returns list of platformAgnosticIdentifier strings for targets that should be accessible
  List<String> getAccessibleTargets(PushinState currentState, List<AppBlockTarget> allTargets);
}

