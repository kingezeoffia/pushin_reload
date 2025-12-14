# Grace Period API Fix (Prompt F.5)

## Problem Statement

The UI State Mapping implementation had a critical bug in the EXPIRED state:

```dart
// ❌ INCORRECT (previous implementation)
gracePeriodRemaining: controller.getUnlockTimeRemaining(now)
```

**Why this was wrong:**
- `getUnlockTimeRemaining()` returns the remaining unlock session time
- When the unlock session expires, the controller clears the session or it becomes 0
- The grace period is tracked separately via `_expiredAt` and `_gracePeriodSeconds`
- Using `getUnlockTimeRemaining()` always showed 0 in EXPIRED state

## Solution

### 1. Added `getGracePeriodRemaining(DateTime now)` to `PushinController`

```dart
/// Get remaining grace period time in seconds
/// Returns 0 if not in EXPIRED state or grace period has elapsed
/// Derived from internal _expiredAt and _gracePeriodSeconds tracking
int getGracePeriodRemaining(DateTime now) {
  if (_expiredAt == null) return 0;

  final elapsedSeconds = now.difference(_expiredAt!).inSeconds;
  final remaining = _gracePeriodSeconds - elapsedSeconds;

  return remaining > 0 ? remaining : 0;
}
```

**Contract Compliance:**
- ✅ Time injected via `DateTime now` parameter (no time leaks)
- ✅ No side effects or state mutations
- ✅ Returns 0 if not in EXPIRED state
- ✅ Pure read-only query
- ✅ No boolean helpers introduced
- ✅ Blocking contract unchanged

### 2. Updated UI State Mapping Documentation

Fixed both Flutter and SwiftUI ViewModel examples in `UI_STATE_MAPPING.md`:

```dart
// ✅ CORRECT (Flutter example)
case PushinState.expired:
  if (blockedTargets.isNotEmpty) {
    return HomeUIState.expired(
      blockedTargets: blockedTargets,
      gracePeriodRemaining: controller.getGracePeriodRemaining(now), // Correct API
      canStartWorkout: true,
    );
  }
```

```swift
// ✅ CORRECT (SwiftUI example)
case .expired:
  if !blockedTargets.isEmpty {
    return .expired(
      blockedTargets: blockedTargets,
      gracePeriodRemaining: controller.getGracePeriodRemaining(now), // Correct API
      canStartWorkout: true
    )
  }
```

### 3. Added Grace Period API Documentation Section

Added comprehensive documentation explaining:
- Why `getGracePeriodRemaining()` exists
- Why `getUnlockTimeRemaining()` is incorrect for grace period
- Contract compliance guarantees
- Proper usage examples

### 4. Added Validation Tests

Two new test cases in `test/pushin_controller_test.dart`:

**Test 1: Grace period countdown correctness**
- Verifies grace period starts at 5 seconds when entering EXPIRED
- Validates countdown decreases correctly (5 → 3 → 1 → 0)
- Confirms clamping to 0 when elapsed
- Ensures transition to LOCKED clears grace period

**Test 2: Grace period returns 0 outside EXPIRED state**
- Confirms 0 returned in LOCKED, EARNING, UNLOCKED states
- Validates state-specific behavior

## Test Results

All 13 tests pass:

```
00:00 +13: All tests passed!
```

Specific grace period tests:
- ✅ `getGracePeriodRemaining() returns correct countdown in EXPIRED state`
- ✅ `getGracePeriodRemaining() returns 0 when not in EXPIRED state`

## Validation Checklist

✅ **EXPIRED grace period countdown decreases correctly**  
✅ **Countdown remains > 0 during grace period**  
✅ **Countdown reaches 0 exactly when transition to LOCKED occurs**  
✅ **No new boolean helpers introduced**  
✅ **No DateTime.now() usage added**  
✅ **Blocking contract unchanged**  
✅ **Target lists remain the only blocking authority**  

## Impact Analysis

### What Changed
- **Controller**: Added 1 read-only method (`getGracePeriodRemaining`)
- **UI State Mapping**: Fixed EXPIRED state examples (Flutter + SwiftUI)
- **Documentation**: Added grace period API explanation
- **Tests**: Added 2 comprehensive validation tests

### What Did NOT Change
- ✅ State machine logic unchanged
- ✅ Domain models unchanged
- ✅ Services unchanged
- ✅ Blocking contract unchanged
- ✅ No boolean helpers added
- ✅ No time leaks introduced

## Architecture Status

**The PUSHIN MVP core is now fully sealed and ready for Prompt G (UI Composition).**

### Pre-Prompt G Checklist

✅ Controller remains pure (state orchestration + read-only queries only)  
✅ Blocking contract intact (target lists are sole authority)  
✅ Time injection respected (no `DateTime.now()` anywhere)  
✅ Deterministic mapping (same domain state → same UI state)  
✅ Grace period API correctly exposes EXPIRED state countdown  
✅ All tests pass (13/13)  
✅ Platform-agnostic (works with mock, Apple Screen Time, Android)  
✅ Ready for UI Composition  

## Summary

This fix ensures the EXPIRED state grace period countdown displays correctly in UI implementations. The solution is minimal, contract-compliant, and maintains the architecture's integrity while fixing a critical UX bug.

**Status**: ✅ **GRACE PERIOD API FIX COMPLETE - ARCHITECTURE SEALED FOR PROMPT G**

