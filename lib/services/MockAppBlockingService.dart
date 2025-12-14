import 'AppBlockingService.dart';
import '../domain/PushinState.dart';
import '../domain/AppBlockTarget.dart';

/// Temporary platform-agnostic implementation of AppBlockingService.
/// Used for development, testing, and UI wiring.
/// Explicit state handling prepares for UI state mapping (Prompt F).
class MockAppBlockingService implements AppBlockingService {
  @override
  List<String> getBlockedTargets(PushinState currentState, List<AppBlockTarget> allTargets) {
    switch (currentState) {
      case PushinState.locked:
      case PushinState.earning:
      case PushinState.expired:
        return allTargets.map((target) => target.platformAgnosticIdentifier).toList();
      case PushinState.unlocked:
        return [];
    }
  }

  @override
  List<String> getAccessibleTargets(PushinState currentState, List<AppBlockTarget> allTargets) {
    switch (currentState) {
      case PushinState.unlocked:
        return allTargets.map((target) => target.platformAgnosticIdentifier).toList();
      case PushinState.locked:
      case PushinState.earning:
      case PushinState.expired:
        return [];
    }
  }
}

