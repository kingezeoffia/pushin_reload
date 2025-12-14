import 'package:flutter/foundation.dart';
import '../../controller/PushinController.dart';
import '../../domain/PushinState.dart';
import '../models/HomeUIState.dart';

/// HomeViewModel - UI State Mapping Layer
///
/// CRITICAL CONTRACT COMPLIANCE RULES:
/// 1. Target lists (getBlockedTargets, getAccessibleTargets) are AUTHORITATIVE
/// 2. PushinState alone is NEVER sufficient for UI decisions
/// 3. Time is INJECTED, never generated (no DateTime.now())
/// 4. No boolean helpers - derive from target lists inline
/// 5. UnlockedUI requires BOTH: blockedTargets.isEmpty AND accessibleTargets.isNotEmpty
/// 6. EXPIRED state uses getGracePeriodRemaining(), NOT getUnlockTimeRemaining()
class HomeViewModel extends ChangeNotifier {
  final PushinController _controller;
  late DateTime _currentTime; // Time must be injected, never generated

  HomeViewModel(this._controller, {required DateTime initialTime}) {
    _currentTime = initialTime; // Explicit time injection - CONTRACT RULE 3
  }

  /// Update time from external scheduler/timer
  /// CONTRACT: Time flows from outside-in, never generated internally
  void updateTime(DateTime now) {
    _currentTime = now;
    notifyListeners();
  }

  /// Derived UI state mapping - 100% contract-compliant
  /// 
  /// MAPPING ALGORITHM:
  /// STEP 1: Query controller with injected time (CONTRACT RULE 1)
  /// STEP 2: Match on PushinState (CONTRACT RULE 2)
  /// STEP 3: Validate with target lists (CONTRACT RULE 1)
  /// STEP 4: Return explicit UI state
  HomeUIState get uiState {
    // STEP 1: Query controller (time-injected) - CONTRACT RULE 1
    final pushinState = _controller.currentState;
    final blockedTargets = _controller.getBlockedTargets(_currentTime);
    final accessibleTargets = _controller.getAccessibleTargets(_currentTime);

    // STEP 2 & 3: Match on PushinState + Validate with target lists
    switch (pushinState) {
      case PushinState.locked:
        // CONTRACT CHECK: blockedTargets.isNotEmpty (inline, no boolean helper)
        if (blockedTargets.isNotEmpty) {
          return HomeUIState.locked(
            blockedTargets: blockedTargets,
            canStartWorkout: true,
          );
        }
        break;

      case PushinState.earning:
        // CONTRACT CHECK: blockedTargets.isNotEmpty (inline, no boolean helper)
        if (blockedTargets.isNotEmpty) {
          return HomeUIState.earning(
            blockedTargets: blockedTargets,
            workoutProgress: _controller.getWorkoutProgress(_currentTime),
            canCancel: true,
          );
        }
        break;

      case PushinState.unlocked:
        // CONTRACT RULE 5 (CRITICAL): UnlockedUI requires BOTH conditions
        // - blockedTargets.isEmpty (blocked content takes precedence)
        // - accessibleTargets.isNotEmpty (unlocked content available)
        // This handles the edge case where PushinState is unlocked but targets conflict
        if (blockedTargets.isEmpty && accessibleTargets.isNotEmpty) {
          return HomeUIState.unlocked(
            accessibleTargets: accessibleTargets,
            timeRemaining: _controller.getUnlockTimeRemaining(_currentTime),
            // Mini-recommendations: Derived from accessibleTargets (CONTRACT RULE 4)
            canShowRecommendations: accessibleTargets.isNotEmpty,
            canLock: true,
          );
        }
        break;

      case PushinState.expired:
        // CONTRACT CHECK: blockedTargets.isNotEmpty (inline, no boolean helper)
        if (blockedTargets.isNotEmpty) {
          return HomeUIState.expired(
            blockedTargets: blockedTargets,
            // CONTRACT RULE 6 (CRITICAL): Use getGracePeriodRemaining()
            // NOT getUnlockTimeRemaining() which returns 0 in EXPIRED state
            gracePeriodRemaining: _controller.getGracePeriodRemaining(_currentTime),
            canStartWorkout: true,
          );
        }
        break;
    }

    // STEP 4: Fallback (should not occur in normal operation)
    // Safety-first: default to locked UI with current target state
    return HomeUIState.locked(
      blockedTargets: blockedTargets,
      canStartWorkout: true,
    );
  }

  // Controller action delegates (no logic, pure pass-through)
  void startWorkout() {
    // In real implementation, this would show workout selection UI
    // then call _controller.startWorkout(selectedWorkout, DateTime.now())
  }

  void cancelWorkout() {
    _controller.cancelWorkout();
    notifyListeners();
  }

  void lock() {
    _controller.lock();
    notifyListeners();
  }

  void completeWorkout() {
    _controller.completeWorkout(_currentTime);
    notifyListeners();
  }
}

