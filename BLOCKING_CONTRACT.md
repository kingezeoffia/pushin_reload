# Blocking Contract - PUSHIN MVP

## Overview

The AppBlockingService contract defines how content blocking decisions are made in the PUSHIN MVP. This contract is designed to be platform-agnostic and support future integration with Apple Screen Time and Android equivalents.

## Core Principle

**UI must derive blocking purely from target lists, not booleans.**

## Why Booleans Were Removed

### Problem with Boolean-Based Blocking

Boolean methods like `shouldBlockContent()` create several issues:

1. **Loss of Granularity**: A boolean cannot express which specific targets are blocked
2. **Platform Coupling**: Boolean decisions assume a single blocking mechanism
3. **UI Limitations**: UI cannot differentiate between different blocking scenarios
4. **Future Integration**: Apple Screen Time and Android require target-specific blocking

### Solution: Target Lists

By exposing only target lists (`getBlockedTargets` and `getAccessibleTargets`), we:

1. **Preserve Granularity**: UI knows exactly which targets are blocked/accessible
2. **Enable Platform Mapping**: Each `platformAgnosticIdentifier` can map to platform-specific APIs
3. **Support Partial Blocking**: Future implementations can block subsets of targets
4. **Maintain Testability**: Lists are easy to assert and verify

## Contract Definition

### AppBlockingService Interface

```dart
abstract class AppBlockingService {
  /// Get blocked targets for given state
  List<String> getBlockedTargets(PushinState currentState, List<AppBlockTarget> allTargets);
  
  /// Get accessible targets for given state
  List<String> getAccessibleTargets(PushinState currentState, List<AppBlockTarget> allTargets);
}
```

### State-Based Blocking Rules

| State    | Blocked Targets | Accessible Targets |
|----------|----------------|-------------------|
| LOCKED   | All targets    | Empty             |
| EARNING  | All targets    | Empty             |
| EXPIRED  | All targets    | Empty             |
| UNLOCKED | Empty          | All targets       |

### Return Values

- **Blocked Targets**: List of `platformAgnosticIdentifier` strings for targets that should be blocked
- **Accessible Targets**: List of `platformAgnosticIdentifier` strings for targets that should be accessible
- **Mutual Exclusivity**: A target is either blocked OR accessible, never both
- **Completeness**: `blockedTargets.length + accessibleTargets.length == allTargets.length`

## How This Supports Future Implementations

### Apple Screen Time Integration

```dart
class AppleScreenTimeBlockingService implements AppBlockingService {
  @override
  List<String> getBlockedTargets(PushinState currentState, List<AppBlockTarget> allTargets) {
    // Map platformAgnosticIdentifier to bundle IDs
    // Call Screen Time API to block specific apps
    return allTargets
        .where((target) => shouldBlock(target, currentState))
        .map((target) => target.platformAgnosticIdentifier)
        .toList();
  }
  
  @override
  List<String> getAccessibleTargets(PushinState currentState, List<AppBlockTarget> allTargets) {
    // Return targets that should be unblocked
    return allTargets
        .where((target) => !shouldBlock(target, currentState))
        .map((target) => target.platformAgnosticIdentifier)
        .toList();
  }
}
```

### Android Equivalent Integration

```dart
class AndroidBlockingService implements AppBlockingService {
  @override
  List<String> getBlockedTargets(PushinState currentState, List<AppBlockTarget> allTargets) {
    // Map platformAgnosticIdentifier to package names
    // Use Android's Digital Wellbeing API
    return allTargets
        .where((target) => shouldBlock(target, currentState))
        .map((target) => target.platformAgnosticIdentifier)
        .toList();
  }
  
  @override
  List<String> getAccessibleTargets(PushinState currentState, List<AppBlockTarget> allTargets) {
    // Return targets that should be unblocked
    return allTargets
        .where((target) => !shouldBlock(target, currentState))
        .map((target) => target.platformAgnosticIdentifier)
        .toList();
  }
}
```

## UI Usage Pattern

### Correct Usage

```dart
// ✅ Correct: Derive blocking from target lists
final blockedTargets = controller.getBlockedTargets(now);
final accessibleTargets = controller.getAccessibleTargets(now);

if (blockedTargets.isNotEmpty) {
  // Show blocking UI
  // Block specific targets via platform APIs
}

if (accessibleTargets.isNotEmpty) {
  // Show accessible content
  // Unblock specific targets via platform APIs
}
```

### Incorrect Usage

```dart
// ❌ Incorrect: Using boolean helper (if it existed)
if (controller.isContentBlocked(now)) {
  // Which targets? How many? Unknown!
}
```

## Testing

Tests assert blocking behavior using target lists:

```dart
test('UNLOCKED state returns empty blockedTargets list', () {
  // ... setup ...
  expect(controller.getBlockedTargets(now), isEmpty);
  expect(controller.getAccessibleTargets(now), isNotEmpty);
});
```

## Benefits

1. **Platform Agnostic**: Works with any blocking mechanism
2. **Granular Control**: UI knows exactly which targets to block/unblock
3. **Future Proof**: Easy to extend for partial blocking, categories, etc.
4. **Testable**: Lists are easy to assert and verify
5. **Clear Contract**: No ambiguity about blocking state

## Summary

The blocking contract ensures that:
- **UI derives blocking from target lists, not booleans**
- **Platform implementations can map identifiers to native APIs**
- **Tests can verify exact blocking behavior**
- **Future enhancements (partial blocking, categories) are supported**

This contract is the foundation for platform-specific blocking implementations while maintaining a clean, testable, and extensible architecture.

