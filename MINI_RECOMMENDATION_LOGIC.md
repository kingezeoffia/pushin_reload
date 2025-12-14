# Mini-Recommendation Logic - Contract Compliance

## Overview

Mini-recommendations in PUSHIN MVP are **derived, not queried**. They must derive availability exclusively from target lists, following the finalized blocking contract.

## Core Principle

**Mini-recommendations are a UI concern. Logic lives in the UI/ViewModel/Feature layer, NOT in PushinController.**

## Why Mini-Recommendations are Derived

Mini-recommendations are contextual UI features that depend on blocking state. Rather than adding methods like `shouldShowRecommendations()` to the controller, UI derives this decision from existing target list APIs:

- `controller.getBlockedTargets(now)` 
- `controller.getAccessibleTargets(now)`

This keeps the controller pure (state orchestration only) and allows UI/ViewModel to reason about feature availability without polluting the core.

## Where the Logic Belongs

### ❌ INCORRECT: Adding boolean methods to PushinController

```dart
// ❌ DO NOT DO THIS
class PushinController {
  bool shouldShowRecommendations(DateTime now) {
    return getAccessibleTargets(now).isNotEmpty;
  }
}
```

**Why this is wrong:**
- Introduces boolean-based reasoning
- Violates blocking contract (target lists are the only API)
- Mixes UI concerns into state orchestration
- Creates implicit coupling between controller and UI features

### ✅ CORRECT: Deriving in UI/ViewModel/Feature Layer

```dart
// ✅ Correct: Derive in ViewModel
class HomeViewModel {
  final PushinController _controller;
  
  HomeViewModel(this._controller);
  
  bool get shouldShowRecommendations {
    final now = DateTime.now();
    final accessibleTargets = _controller.getAccessibleTargets(now);
    return accessibleTargets.isNotEmpty;
  }
}
```

```dart
// ✅ Correct: Derive in Widget
class HomeScreen extends StatelessWidget {
  final PushinController controller;
  
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final blockedTargets = controller.getBlockedTargets(now);
    final accessibleTargets = controller.getAccessibleTargets(now);
    
    return Column(
      children: [
        // Content blocking UI
        if (blockedTargets.isNotEmpty) BlockedContentView(),
        
        // Mini-recommendations (only when accessible)
        if (accessibleTargets.isNotEmpty) RecommendationsPanel(),
        
        // Other UI
      ],
    );
  }
}
```

```dart
// ✅ Correct: Derive in BLoC/State Management
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final PushinController _controller;
  
  Stream<HomeState> _mapUpdateUIToState(DateTime now) async* {
    final blockedTargets = _controller.getBlockedTargets(now);
    final accessibleTargets = _controller.getAccessibleTargets(now);
    
    yield HomeState(
      showRecommendations: accessibleTargets.isNotEmpty,
      blockedTargets: blockedTargets,
      accessibleTargets: accessibleTargets,
    );
  }
}
```

## Contract-Compliant Logic Rules

1. **Blocked Context**: When `blockedTargets.isNotEmpty` → Recommendations **never appear**
2. **Unlocked Context**: When `accessibleTargets.isNotEmpty` → Recommendations **always appear**
3. **Edge Case**: When both lists are empty → UI decides (should not occur in normal flow)
4. **Time Injection**: All logic uses provided `DateTime now` parameter
5. **No Booleans in Controller**: No boolean helpers or shortcuts in PushinController
6. **Derive, Don't Query**: UI derives visibility from target lists, doesn't query a boolean

## Implementation Patterns

### Pattern 1: Direct Widget Usage

```dart
class ContentScreen extends StatelessWidget {
  final PushinController controller;
  
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final accessibleTargets = controller.getAccessibleTargets(now);
    
    return Scaffold(
      body: Column(
        children: [
          // Main content
          ContentView(),
          
          // Mini-recommendations: only shown when accessible
          if (accessibleTargets.isNotEmpty)
            MiniRecommendationCard(
              title: 'Try this workout next',
              targets: accessibleTargets,
            ),
        ],
      ),
    );
  }
}
```

### Pattern 2: ViewModel with Computed Property

```dart
class DashboardViewModel extends ChangeNotifier {
  final PushinController _controller;
  DateTime _currentTime = DateTime.now();
  
  DashboardViewModel(this._controller);
  
  void updateTime(DateTime now) {
    _currentTime = now;
    notifyListeners();
  }
  
  // Derived property - no boolean API in controller
  bool get canShowRecommendations {
    final accessibleTargets = _controller.getAccessibleTargets(_currentTime);
    return accessibleTargets.isNotEmpty;
  }
  
  List<String> get accessibleTargets {
    return _controller.getAccessibleTargets(_currentTime);
  }
}

// Usage in Widget
class DashboardView extends StatelessWidget {
  final DashboardViewModel viewModel;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (viewModel.canShowRecommendations)
          RecommendationsWidget(targets: viewModel.accessibleTargets),
      ],
    );
  }
}
```

### Pattern 3: State Management (BLoC/Riverpod/Provider)

```dart
// BLoC approach
class RecommendationState {
  final bool showRecommendations;
  final List<String> availableTargets;
  
  RecommendationState({
    required this.showRecommendations,
    required this.availableTargets,
  });
}

class RecommendationBloc extends Bloc<RecommendationEvent, RecommendationState> {
  final PushinController _controller;
  
  Stream<RecommendationState> _mapTickToState(DateTime now) async* {
    final accessibleTargets = _controller.getAccessibleTargets(now);
    
    yield RecommendationState(
      showRecommendations: accessibleTargets.isNotEmpty,
      availableTargets: accessibleTargets,
    );
  }
}
```

## How This Supports Future Platform Integrations

### Apple Screen Time Integration

When integrated with Apple Screen Time:
- `getAccessibleTargets(now)` returns bundle IDs of apps currently unblocked
- UI checks `accessibleTargets.isNotEmpty` to show recommendations
- Recommendations can suggest workouts to unlock specific apps by bundle ID
- No boolean APIs needed - everything derives from target lists

```dart
class AppleRecommendationWidget extends StatelessWidget {
  final PushinController controller;
  
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final accessibleTargets = controller.getAccessibleTargets(now);
    
    if (accessibleTargets.isEmpty) {
      return SizedBox.shrink(); // No recommendations when blocked
    }
    
    // Show recommendations with specific bundle IDs
    return RecommendationCard(
      message: 'You have access to ${accessibleTargets.length} apps',
      apps: accessibleTargets, // e.g., ['com.apple.safari', 'com.twitter.twitter-iphone']
    );
  }
}
```

### Android Digital Wellbeing Integration

When integrated with Android:
- `getAccessibleTargets(now)` returns package names of apps currently unblocked
- UI checks `accessibleTargets.isNotEmpty` to show recommendations
- Recommendations can suggest workouts to unlock specific apps by package name
- Same pattern, different platform - no code changes needed

```dart
class AndroidRecommendationWidget extends StatelessWidget {
  final PushinController controller;
  
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final accessibleTargets = controller.getAccessibleTargets(now);
    
    if (accessibleTargets.isEmpty) {
      return SizedBox.shrink(); // No recommendations when blocked
    }
    
    // Show recommendations with specific package names
    return RecommendationCard(
      message: 'You can access ${accessibleTargets.length} apps',
      apps: accessibleTargets, // e.g., ['com.android.chrome', 'com.twitter.android']
    );
  }
}
```

### Platform-Agnostic Benefit

Because recommendations derive from `accessibleTargets.isNotEmpty`:
1. **No platform-specific code in UI logic**: Same derivation pattern works everywhere
2. **Granular control**: UI knows exactly which apps/targets are accessible
3. **Future-proof**: If partial blocking is added, UI automatically adapts
4. **Testable**: Mock target lists to test recommendation visibility

## Anti-Patterns (DO NOT USE)

### ❌ Boolean Helpers in Controller

```dart
// ❌ WRONG: Adds boolean API
class PushinController {
  bool shouldShowRecommendations(DateTime now) {
    return getAccessibleTargets(now).isNotEmpty;
  }
}
```

### ❌ Boolean Helpers Outside Controller

```dart
// ❌ WRONG: Creates unnecessary abstraction
class RecommendationHelper {
  static bool shouldShow(PushinController controller, DateTime now) {
    return controller.getAccessibleTargets(now).isNotEmpty;
  }
}
```

### ❌ Time Leaks

```dart
// ❌ WRONG: Calls DateTime.now() inside helper
class PushinController {
  bool get canShowRecommendations {
    return getAccessibleTargets(DateTime.now()).isNotEmpty; // Time leak!
  }
}
```

### ❌ Implicit Boolean Reasoning

```dart
// ❌ WRONG: Creates boolean abstraction
bool isUnlocked(PushinController controller, DateTime now) {
  return controller.getAccessibleTargets(now).isNotEmpty;
}
```

## Why This Aligns with Blocking Contract

1. **Target Lists as Source of Truth**: Availability derived from `getBlockedTargets()` and `getAccessibleTargets()`
2. **No Boolean Reasoning**: Logic checks list emptiness in UI, not in controller
3. **Deterministic**: Same target lists produce same recommendation visibility
4. **Testable**: Can assert list states to verify recommendation behavior
5. **Platform Agnostic**: Works with any blocking implementation (mock, Apple, Android)
6. **Separation of Concerns**: Controller manages state, UI manages features

## Testing Recommendations

### Unit Test (ViewModel/BLoC)

```dart
test('shouldShowRecommendations returns true when accessibleTargets not empty', () {
  final mockController = MockPushinController();
  final viewModel = HomeViewModel(mockController);
  final now = DateTime(2024, 1, 1);
  
  when(mockController.getAccessibleTargets(now))
    .thenReturn(['com.social.media']);
  
  expect(viewModel.shouldShowRecommendations, isTrue);
});

test('shouldShowRecommendations returns false when accessibleTargets empty', () {
  final mockController = MockPushinController();
  final viewModel = HomeViewModel(mockController);
  final now = DateTime(2024, 1, 1);
  
  when(mockController.getAccessibleTargets(now))
    .thenReturn([]);
  
  expect(viewModel.shouldShowRecommendations, isFalse);
});
```

### Widget Test

```dart
testWidgets('Recommendations appear when accessibleTargets not empty', (tester) async {
  final mockController = MockPushinController();
  
  when(mockController.getAccessibleTargets(any))
    .thenReturn(['com.social.media']);
  
  await tester.pumpWidget(HomeScreen(controller: mockController));
  
  expect(find.byType(RecommendationsPanel), findsOneWidget);
});

testWidgets('Recommendations hidden when accessibleTargets empty', (tester) async {
  final mockController = MockPushinController();
  
  when(mockController.getAccessibleTargets(any))
    .thenReturn([]);
  
  await tester.pumpWidget(HomeScreen(controller: mockController));
  
  expect(find.byType(RecommendationsPanel), findsNothing);
});
```

## Validation Checklist

✅ **Zero boolean APIs added to PushinController**: Controller exposes only target list methods  
✅ **Zero controller logic added**: All recommendation logic lives in UI/ViewModel layer  
✅ **Zero time injection violations**: All examples use injected `DateTime now` parameter  
✅ **Target lists are the only source of truth**: All decisions derive from `getBlockedTargets()` and `getAccessibleTargets()`  

## Summary

Mini-recommendations are **derived, not queried**:
- **Controller**: Pure state orchestrator, exposes only `getBlockedTargets()` and `getAccessibleTargets()`
- **UI/ViewModel**: Derives recommendation visibility from target list presence
- **Pattern**: `accessibleTargets.isNotEmpty` → show recommendations
- **Platform Support**: Works seamlessly with Apple Screen Time, Android Digital Wellbeing, and mock implementations
- **Contract Compliant**: No boolean APIs, no time leaks, no architectural violations

