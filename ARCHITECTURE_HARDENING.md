# PUSHIN MVP Architecture Hardening - BMAD v6 Compliance

## Changes Made and Rationale

### A) Domain Models

**Workout.dart**
- **Added `earnedTimeSeconds` field**: Unlock duration now comes exclusively from domain model, eliminating magic numbers in controller.
- **Removed `caloriesPerRep` and `totalCalories`**: Not needed for MVP core logic, reduces complexity.

**UnlockSession.dart**
- **No changes**: Already time-agnostic with pure calculations.

**PushinState.dart**
- **Extracted to separate file**: Better organization and explicit state definition.

**AppBlockTarget.dart**
- **No changes**: Already compliant.

### B) Service Interfaces

**WorkoutTrackingService.dart**
- **All methods now require `DateTime now` parameter**: Removes implicit `DateTime.now()` usage, enables deterministic testing.
- **`getProgress(DateTime now)` and `isCompleted(DateTime now)`**: Time injection ensures testability.

**UnlockService.dart**
- **All time-dependent methods require `DateTime now` parameter**: Eliminates implicit time dependencies.
- **`getRemainingSeconds(DateTime now)` and `isActive(DateTime now)`**: Explicit time injection.

**AppBlockingService.dart**
- **No changes**: Already pure logic with no time dependencies.

### C) Mock Services

**MockWorkoutTrackingService.dart**
- **Implements time-injected interface**: Tracks workout state with explicit timestamps.
- **`recordRep(DateTime timestamp)`**: Records rep completion with explicit time.

**MockUnlockService.dart**
- **Implements time-injected interface**: Uses explicit time for all calculations.
- **Session tracking with `DateTime` parameters**: No implicit time usage.

**MockAppBlockingService.dart**
- **No changes**: Already pure state-based logic.

### D) PushinController

**PushinController.dart**
- **All methods requiring time now accept `DateTime now` parameter**: `startWorkout(workout, now)`, `completeWorkout(now)`, `tick(now)`, query methods.
- **Removed `_calculateEarnedTime()` method**: Unlock duration now comes directly from `Workout.earnedTimeSeconds` domain model.
- **Query methods require `DateTime now`**: `isContentBlocked(now)`, `getWorkoutProgress(now)`, `getUnlockTimeRemaining(now)`.
- **No magic numbers**: All time values come from domain models or constructor parameters.

### E) Unit Tests

**pushin_controller_test.dart**
- **Deterministic `DateTime` values**: All tests use explicit `baseTime` and calculated timestamps.
- **Proper workout simulation**: Tests call `recordRep()` multiple times to simulate real behavior, no manual state shortcuts.
- **Time injection throughout**: All controller methods called with explicit `DateTime` values.
- **No magic numbers**: All time calculations use domain model values (e.g., `workout.earnedTimeSeconds`).

## Architecture Principles Enforced

1. **Time Injection**: No implicit `DateTime.now()` anywhere in core logic.
2. **Domain-Driven**: Unlock duration comes from `Workout` model, not controller logic.
3. **Deterministic**: All operations are testable with explicit time values.
4. **Single Source of Truth**: Controller owns state, services are stateless calculators.
5. **Platform Agnostic**: No platform-specific code or assumptions.

## Ready for Prompt F

The architecture is now hardened and frozen, ready for UI state mapping without core logic changes.

