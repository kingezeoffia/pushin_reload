# UI State Mapping - PUSHIN MVP (iOS-First)

## Overview

UI State Mapping converts PUSHIN's domain state (`PushinState`, `blockedTargets`, `accessibleTargets`) into explicit UI states for iOS-first Flutter/SwiftUI interfaces.

**This is a mapping layer ONLY. No domain logic is added, modified, or queried beyond the blocking contract.**

## Core Principles

- **Derived, Not Queried**: UI states are computed from domain state, not added to controller
- **Target List-Driven**: All blocking decisions derive from `blockedTargets` and `accessibleTargets`
- **Blocking Contract-First**: Target lists are the ONLY source of truth for blocking decisions
- **Deterministic**: Same domain state → same UI state (no randomness)
- **Time-Injected**: All operations use provided `DateTime now` (never `DateTime.now()`)
- **Platform Agnostic**: Works with Apple Screen Time, Android Digital Wellbeing, or mock implementations

## Blocking Contract Compliance

**CRITICAL**: UI state mapping MUST comply with the blocking contract at all times.

### Contract Rules

1. **Target Lists are Authoritative**: 
   - `getBlockedTargets(now)` returns the definitive list of blocked content
   - `getAccessibleTargets(now)` returns the definitive list of accessible content
   - These are the ONLY APIs for determining blocking state

2. **No Boolean Shortcuts**:
   - Never create boolean helpers like `isBlocked()` or `isUnlocked()`
   - Always derive from target list emptiness: `blockedTargets.isNotEmpty`

3. **PushinState is NOT Sufficient**:
   - UI mapping MUST check both `PushinState` AND target lists
   - `PushinState.unlocked` alone does not guarantee `accessibleTargets.isNotEmpty`
   - Target lists are the final authority

4. **Time Injection is Mandatory**:
   - Never call `DateTime.now()` inside UI mapping logic
   - Time must be injected by external timer/scheduler
   - UI layer receives time, never generates it

### Why This Matters for Platform Integrations

When integrating with Apple Screen Time or Android Digital Wellbeing:
- `blockedTargets` will contain actual bundle IDs (iOS) or package names (Android)
- `accessibleTargets` will contain actual bundle IDs (iOS) or package names (Android)
- Platform APIs need these specific identifiers to enforce restrictions
- Boolean helpers cannot provide this granularity

## UI State Definitions

### LockedUI

**Domain Mapping**: `PushinState.locked` + `blockedTargets.isNotEmpty`

**Primary Screen Intent**: Prevent access, encourage workout initiation

**Allowed User Actions**:
- Start workout (transitions to EarningUI)
- View blocked content indicators
- Access settings

**UI Characteristics**:
- Blocked content indicators visible
- Workout initiation UI prominent
- Mini-recommendations hidden

**iOS-Specific**:
- Overlay with Screen Time-style restrictions
- "Start Workout" CTA button
- Visual indicators for blocked apps

### EarningUI

**Domain Mapping**: `PushinState.earning` + `blockedTargets.isNotEmpty`

**Primary Screen Intent**: Show workout progress, maintain engagement

**Allowed User Actions**:
- Record workout progress
- View workout instructions
- Cancel workout (transitions to LockedUI)
- View blocked content indicators

**UI Characteristics**:
- Workout progress indicators visible
- Blocked content indicators visible
- Mini-recommendations hidden
- Cancel option available

**iOS-Specific**:
- Workout progress ring animation
- Rep counter with haptic feedback
- "Cancel" button in navigation

### UnlockedUI

**Domain Mapping**: `PushinState.unlocked` + `accessibleTargets.isNotEmpty`

**Primary Screen Intent**: Allow content access, show time remaining

**Allowed User Actions**:
- Access all content
- View time remaining
- View mini-recommendations
- Manual lock (transitions to LockedUI)

**UI Characteristics**:
- All content accessible
- Time remaining countdown visible
- Mini-recommendations visible
- No blocked content indicators

**iOS-Specific**:
- Time remaining in status bar
- Mini-recommendations carousel
- "Lock Now" option in settings

### ExpiredUI

**Domain Mapping**: `PushinState.expired` + `blockedTargets.isNotEmpty`

**Primary Screen Intent**: Show grace period, encourage immediate workout

**Allowed User Actions**:
- View grace period countdown
- Start workout (transitions to EarningUI)
- View blocked content indicators

**UI Characteristics**:
- Grace period countdown prominent
- Blocked content indicators visible
- Mini-recommendations hidden
- Urgent workout initiation prompts

**iOS-Specific**:
- Grace period countdown timer
- "Time's Up" overlay with Screen Time styling
- Emergency workout CTA

## Mapping Table

| PushinState | blockedTargets | accessibleTargets | UI State | Blocking Contract Check |
|-------------|----------------|-------------------|----------|------------------------|
| `locked` | `.isNotEmpty` | `.isEmpty` | **LockedUI** | `blockedTargets.isNotEmpty` → content blocked |
| `earning` | `.isNotEmpty` | `.isEmpty` | **EarningUI** | `blockedTargets.isNotEmpty` → content blocked |
| `unlocked` | `.isEmpty` | `.isNotEmpty` | **UnlockedUI** | `accessibleTargets.isNotEmpty` → content accessible |
| `expired` | `.isNotEmpty` | `.isEmpty` | **ExpiredUI** | `blockedTargets.isNotEmpty` → content blocked |

### Mapping Algorithm (Contract-Compliant)

```
function mapToUIState(pushinState, now):
  // STEP 1: Query controller (time-injected)
  blockedTargets = controller.getBlockedTargets(now)
  accessibleTargets = controller.getAccessibleTargets(now)
  
  // STEP 2: Match on PushinState
  switch pushinState:
    case locked:
      // STEP 3: Validate with target lists (contract check)
      if blockedTargets.isNotEmpty:
        return LockedUI(blockedTargets)
      
    case earning:
      if blockedTargets.isNotEmpty:
        return EarningUI(blockedTargets, progress)
      
    case unlocked:
      if accessibleTargets.isNotEmpty:
        return UnlockedUI(accessibleTargets, timeRemaining)
      
    case expired:
      if blockedTargets.isNotEmpty:
        return ExpiredUI(blockedTargets, gracePeriodRemaining)
  
  // STEP 4: Fallback (should not occur)
  return LockedUI(blockedTargets)
```

**Critical Rules**:
- **Mapping is deterministic**: same domain state → same UI state
- **Target list check is mandatory**: never map from `PushinState` alone
- **`blockedTargets.isNotEmpty`** = blocked context (LockedUI/EarningUI/ExpiredUI)
- **`accessibleTargets.isNotEmpty`** = unlocked context (UnlockedUI)
- **Edge case**: empty lists should not occur in normal operation (fallback to LockedUI)

## UI-Layer Implementation Examples

### Flutter Implementation

#### ViewModel Approach

```dart
class HomeViewModel extends ChangeNotifier {
  final PushinController _controller;
  late DateTime _currentTime; // Time must be injected, never generated

  HomeViewModel(this._controller, {required DateTime initialTime}) {
    _currentTime = initialTime; // Explicit time injection
  }

  void updateTime(DateTime now) {
    _currentTime = now;
    notifyListeners();
  }

  // Derived UI state mapping
  HomeUIState get uiState {
    final pushinState = _controller.currentState;
    final blockedTargets = _controller.getBlockedTargets(_currentTime);
    final accessibleTargets = _controller.getAccessibleTargets(_currentTime);

    // Deterministic mapping from domain to UI state
    switch (pushinState) {
      case PushinState.locked:
        if (blockedTargets.isNotEmpty) {
          return HomeUIState.locked(
            blockedTargets: blockedTargets,
            canStartWorkout: true,
          );
        }
        break;

      case PushinState.earning:
        if (blockedTargets.isNotEmpty) {
          return HomeUIState.earning(
            blockedTargets: blockedTargets,
            workoutProgress: _controller.getWorkoutProgress(_currentTime),
            canCancel: true,
          );
        }
        break;

      case PushinState.unlocked:
        if (accessibleTargets.isNotEmpty) {
          return HomeUIState.unlocked(
            accessibleTargets: accessibleTargets,
            timeRemaining: _controller.getUnlockTimeRemaining(_currentTime),
            canShowRecommendations: accessibleTargets.isNotEmpty, // Derived, not queried
            canLock: true,
          );
        }
        break;

      case PushinState.expired:
        if (blockedTargets.isNotEmpty) {
          return HomeUIState.expired(
            blockedTargets: blockedTargets,
            gracePeriodRemaining: _controller.getUnlockTimeRemaining(_currentTime), // Grace period
            canStartWorkout: true,
          );
        }
        break;
    }

    // Fallback (should not occur in normal operation)
    return HomeUIState.locked(
      blockedTargets: blockedTargets,
      canStartWorkout: true,
    );
  }
}

// UI State Definition
enum HomeUIStateType { locked, earning, unlocked, expired }

class HomeUIState {
  final HomeUIStateType type;
  final List<String> blockedTargets;
  final List<String> accessibleTargets;
  final double? workoutProgress;
  final int? timeRemaining;
  final bool canStartWorkout;
  final bool canCancel;
  final bool canLock;
  final bool canShowRecommendations;

  HomeUIState._({
    required this.type,
    required this.blockedTargets,
    required this.accessibleTargets,
    this.workoutProgress,
    this.timeRemaining,
    required this.canStartWorkout,
    required this.canCancel,
    required this.canLock,
    required this.canShowRecommendations,
  });

  factory HomeUIState.locked({
    required List<String> blockedTargets,
    required bool canStartWorkout,
  }) => HomeUIState._(
    type: HomeUIStateType.locked,
    blockedTargets: blockedTargets,
    accessibleTargets: [],
    canStartWorkout: canStartWorkout,
    canCancel: false,
    canLock: false,
    canShowRecommendations: false,
  );

  factory HomeUIState.earning({
    required List<String> blockedTargets,
    required double workoutProgress,
    required bool canCancel,
  }) => HomeUIState._(
    type: HomeUIStateType.earning,
    blockedTargets: blockedTargets,
    accessibleTargets: [],
    workoutProgress: workoutProgress,
    canStartWorkout: false,
    canCancel: canCancel,
    canLock: false,
    canShowRecommendations: false,
  );

  factory HomeUIState.unlocked({
    required List<String> accessibleTargets,
    required int timeRemaining,
    required bool canShowRecommendations,
    required bool canLock,
  }) => HomeUIState._(
    type: HomeUIStateType.unlocked,
    blockedTargets: [],
    accessibleTargets: accessibleTargets,
    timeRemaining: timeRemaining,
    canStartWorkout: false,
    canCancel: false,
    canLock: canLock,
    canShowRecommendations: canShowRecommendations,
  );

  factory HomeUIState.expired({
    required List<String> blockedTargets,
    required int gracePeriodRemaining,
    required bool canStartWorkout,
  }) => HomeUIState._(
    type: HomeUIStateType.expired,
    blockedTargets: blockedTargets,
    accessibleTargets: [],
    timeRemaining: gracePeriodRemaining,
    canStartWorkout: canStartWorkout,
    canCancel: false,
    canLock: false,
    canShowRecommendations: false,
  );
}
```

#### Widget Implementation

```dart
class HomeScreen extends StatelessWidget {
  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final uiState = viewModel.uiState;

        return Scaffold(
          appBar: AppBar(
            title: Text('PUSHIN'),
            actions: [
              if (uiState.canLock)
                IconButton(
                  icon: Icon(Icons.lock),
                  onPressed: () => viewModel.lock(),
                ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // State-specific content
                Expanded(
                  child: _buildContent(uiState),
                ),

                // Action buttons
                _buildActions(uiState),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(HomeUIState uiState) {
    switch (uiState.type) {
      case HomeUIStateType.locked:
        return LockedContentView(
          blockedTargets: uiState.blockedTargets,
        );

      case HomeUIStateType.earning:
        return EarningContentView(
          blockedTargets: uiState.blockedTargets,
          progress: uiState.workoutProgress!,
        );

      case HomeUIStateType.unlocked:
        return UnlockedContentView(
          accessibleTargets: uiState.accessibleTargets,
          timeRemaining: uiState.timeRemaining!,
          showRecommendations: uiState.canShowRecommendations,
        );

      case HomeUIStateType.expired:
        return ExpiredContentView(
          blockedTargets: uiState.blockedTargets,
          gracePeriodRemaining: uiState.timeRemaining!,
        );
    }
  }

  Widget _buildActions(HomeUIState uiState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (uiState.canStartWorkout)
          ElevatedButton(
            onPressed: () => viewModel.startWorkout(),
            child: Text('Start Workout'),
          ),

        if (uiState.canCancel)
          OutlinedButton(
            onPressed: () => viewModel.cancelWorkout(),
            child: Text('Cancel'),
          ),

        if (uiState.canLock)
          OutlinedButton(
            onPressed: () => viewModel.lock(),
            child: Text('Lock Now'),
          ),
      ],
    );
  }
}
```

### SwiftUI Implementation

#### ViewModel Approach

```swift
import Foundation
import Combine

class HomeViewModel: ObservableObject {
    private let controller: PushinController
    @Published private(set) var uiState: HomeUIState
    private var currentTime: Date // Time must be injected, never generated

    init(controller: PushinController, initialTime: Date) {
        self.controller = controller
        self.currentTime = initialTime // Explicit time injection
        self.uiState = Self.computeUIState(controller: controller, now: currentTime)
    }

    func updateTime(_ now: Date) {
        currentTime = now
        uiState = Self.computeUIState(controller: controller, now: now)
    }

    private static func computeUIState(controller: PushinController, now: Date) -> HomeUIState {
        let pushinState = controller.currentState
        let blockedTargets = controller.getBlockedTargets(now)
        let accessibleTargets = controller.getAccessibleTargets(now)

        switch pushinState {
        case .locked:
            if !blockedTargets.isEmpty {
                return .locked(
                    blockedTargets: blockedTargets,
                    canStartWorkout: true
                )
            }

        case .earning:
            if !blockedTargets.isEmpty {
                return .earning(
                    blockedTargets: blockedTargets,
                    workoutProgress: controller.getWorkoutProgress(now),
                    canCancel: true
                )
            }

        case .unlocked:
            if !accessibleTargets.isEmpty {
                return .unlocked(
                    accessibleTargets: accessibleTargets,
                    timeRemaining: controller.getUnlockTimeRemaining(now),
                    canShowRecommendations: !accessibleTargets.isEmpty, // Derived
                    canLock: true
                )
            }

        case .expired:
            if !blockedTargets.isEmpty {
                return .expired(
                    blockedTargets: blockedTargets,
                    gracePeriodRemaining: controller.getUnlockTimeRemaining(now),
                    canStartWorkout: true
                )
            }

        @unknown default:
            break
        }

        // Fallback
        return .locked(
            blockedTargets: blockedTargets,
            canStartWorkout: true
        )
    }
}

// UI State Definition
enum HomeUIState {
    case locked(blockedTargets: [String], canStartWorkout: Bool)
    case earning(blockedTargets: [String], workoutProgress: Double, canCancel: Bool)
    case unlocked(accessibleTargets: [String], timeRemaining: Int, canShowRecommendations: Bool, canLock: Bool)
    case expired(blockedTargets: [String], gracePeriodRemaining: Int, canStartWorkout: Bool)
}
```

#### View Implementation

```swift
import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                contentView
                actionButtons
            }
            .navigationTitle("PUSHIN")
            .navigationBarItems(trailing: lockButton)
            .padding()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.uiState {
        case .locked(let blockedTargets, _):
            LockedContentView(blockedTargets: blockedTargets)

        case .earning(let blockedTargets, let progress, _):
            EarningContentView(
                blockedTargets: blockedTargets,
                progress: progress
            )

        case .unlocked(let accessibleTargets, let timeRemaining, let showRecommendations, _):
            UnlockedContentView(
                accessibleTargets: accessibleTargets,
                timeRemaining: timeRemaining,
                showRecommendations: showRecommendations
            )

        case .expired(let blockedTargets, let gracePeriod, _):
            ExpiredContentView(
                blockedTargets: blockedTargets,
                gracePeriodRemaining: gracePeriod
            )
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            switch viewModel.uiState {
            case .locked(_, let canStart):
                if canStart {
                    Button("Start Workout") {
                        viewModel.startWorkout()
                    }
                    .buttonStyle(.borderedProminent)
                }

            case .earning(_, _, let canCancel):
                if canCancel {
                    Button("Cancel", role: .destructive) {
                        viewModel.cancelWorkout()
                    }
                    .buttonStyle(.bordered)
                }

            case .expired(_, _, let canStart):
                if canStart {
                    Button("Emergency Workout") {
                        viewModel.startWorkout()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var lockButton: some View {
        switch viewModel.uiState {
        case .unlocked(_, _, _, let canLock):
            if canLock {
                Button(action: { viewModel.lock() }) {
                    Image(systemName: "lock.fill")
                }
            }

        default:
            EmptyView()
        }
    }
}
```

## Anti-Patterns

### ❌ Boolean Helpers in Controller

```dart
// WRONG: Violates blocking contract
class PushinController {
  bool isContentBlocked(DateTime now) {
    return getBlockedTargets(now).isNotEmpty;
  }
}
```

### ❌ UI State Inference from PushinState Alone

```dart
// ❌ WRONG: Ignores target lists (violates blocking contract)
HomeUIState mapToUI(PushinState state) {
  switch (state) {
    case .locked: return .locked;    // ❌ Missing blockedTargets.isNotEmpty check
    case .earning: return .earning;  // ❌ Missing blockedTargets.isNotEmpty check
    case .unlocked: return .unlocked;// ❌ Missing accessibleTargets.isNotEmpty check
    case .expired: return .expired;  // ❌ Missing blockedTargets.isNotEmpty check
  }
}
```

**Why this is wrong**:
- Violates blocking contract: target lists are the ONLY authority
- PushinState alone cannot determine which targets are blocked/accessible
- Platform integrations (Apple/Android) need actual target identifiers
- Loses granularity required for partial blocking in future

```dart
// ✅ CORRECT: Validates with target lists
HomeUIState mapToUI(PushinState state, DateTime now) {
  final blockedTargets = controller.getBlockedTargets(now);   // Contract-compliant
  final accessibleTargets = controller.getAccessibleTargets(now); // Contract-compliant
  
  switch (state) {
    case .locked:
      if (blockedTargets.isNotEmpty) { // ✅ Contract check
        return LockedUI(blockedTargets);
      }
    // ... rest of cases with target list validation
  }
}
```

### ❌ Time Leaks in UI Logic

```dart
// WRONG: Calls DateTime.now() in UI layer
class HomeViewModel {
  HomeUIState get uiState {
    let now = DateTime.now() // ❌ TIME LEAK! Never generate time in UI
    let blockedTargets = controller.getBlockedTargets(now)
    // ...
  }
}
```

```dart
// WRONG: Initializes with DateTime.now()
class HomeViewModel {
  DateTime _currentTime = DateTime.now(); // ❌ TIME LEAK!
  
  HomeViewModel(this._controller); // Should require initialTime
}
```

```dart
// ✅ CORRECT: Time is injected
class HomeViewModel {
  late DateTime _currentTime; // No default value
  
  HomeViewModel(this._controller, {required DateTime initialTime}) {
    _currentTime = initialTime; // ✅ Explicitly injected
  }
}
```

### ❌ Mixing Domain and UI Concerns

```dart
// WRONG: UI logic in controller
class PushinController {
  HomeUIState get uiState {
    // UI concerns mixed with domain logic
    return HomeUIState.locked(canStartWorkout: currentState == .locked);
  }
}
```

### ❌ Boolean Abstractions

```dart
// WRONG: Creates boolean API
bool isUnlocked(PushinController controller, DateTime now) {
  return controller.getAccessibleTargets(now).isNotEmpty;
}
```

## Platform-Specific Integration Examples

### Apple Screen Time Integration

```dart
class AppleHomeViewModel extends HomeViewModel {
  // Apple-specific: Map platformAgnosticIdentifier to bundle IDs
  List<String> get blockedBundleIds {
    let blockedTargets = controller.getBlockedTargets(currentTime)
    return blockedTargets.map { mapToBundleId($0) }
  }

  // Apple-specific: Screen Time restrictions
  func applyScreenTimeRestrictions() {
    let bundleIds = blockedBundleIds
    // Call Screen Time API to block apps
    screenTimeManager.restrictApplications(bundleIds)
  }
}
```

### Android Digital Wellbeing Integration

```dart
class AndroidHomeViewModel extends HomeViewModel {
  // Android-specific: Map platformAgnosticIdentifier to package names
  List<String> get blockedPackageNames {
    val blockedTargets = controller.getBlockedTargets(currentTime)
    return blockedTargets.map { mapToPackageName(it) }
  }

  // Android-specific: Digital Wellbeing restrictions
  fun applyDigitalWellbeingRestrictions() {
    val packageNames = blockedPackageNames
    // Call Digital Wellbeing API to block apps
    digitalWellbeingManager.restrictApplications(packageNames)
  }
}
```

## Testing UI State Mapping

### Unit Tests

```dart
test('LockedUI maps from locked state with blocked targets', () {
  final controller = MockPushinController();
  when(controller.currentState).thenReturn(PushinState.locked);
  when(controller.getBlockedTargets(any)).thenReturn(['com.social.media']);
  when(controller.getAccessibleTargets(any)).thenReturn([]);

  final viewModel = HomeViewModel(controller);
  final uiState = viewModel.uiState;

  expect(uiState.type, equals(HomeUIStateType.locked));
  expect(uiState.blockedTargets, equals(['com.social.media']));
  expect(uiState.canStartWorkout, isTrue);
  expect(uiState.canShowRecommendations, isFalse);
});

test('UnlockedUI maps from unlocked state with accessible targets', () {
  final controller = MockPushinController();
  when(controller.currentState).thenReturn(PushinState.unlocked);
  when(controller.getBlockedTargets(any)).thenReturn([]);
  when(controller.getAccessibleTargets(any)).thenReturn(['com.social.media']);
  when(controller.getUnlockTimeRemaining(any)).thenReturn(180);

  final viewModel = HomeViewModel(controller);
  final uiState = viewModel.uiState;

  expect(uiState.type, equals(HomeUIStateType.unlocked));
  expect(uiState.accessibleTargets, equals(['com.social.media']));
  expect(uiState.timeRemaining, equals(180));
  expect(uiState.canShowRecommendations, isTrue);
});
```

### Widget Tests (Flutter)

```dart
testWidgets('LockedUI shows start workout button', (tester) async {
  final controller = MockPushinController();
  when(controller.currentState).thenReturn(PushinState.locked);
  when(controller.getBlockedTargets(any)).thenReturn(['com.social.media']);

  final viewModel = HomeViewModel(controller);
  await tester.pumpWidget(MaterialApp(home: HomeScreen(viewModel: viewModel)));

  expect(find.text('Start Workout'), findsOneWidget);
  expect(find.byType(RecommendationsPanel), findsNothing);
});

testWidgets('UnlockedUI shows recommendations', (tester) async {
  final controller = MockPushinController();
  when(controller.currentState).thenReturn(PushinState.unlocked);
  when(controller.getAccessibleTargets(any)).thenReturn(['com.social.media']);

  final viewModel = HomeViewModel(controller);
  await tester.pumpWidget(MaterialApp(home: HomeScreen(viewModel: viewModel)));

  expect(find.byType(RecommendationsPanel), findsOneWidget);
});
```

## Blocking Contract Pre-Flight Checklist

Before moving to Prompt G (UI Composition), verify:

### Domain Layer (Must NOT Change)
- [ ] `PushinController` unchanged
- [ ] Domain models unchanged (`Workout`, `UnlockSession`, `AppBlockTarget`, `PushinState`)
- [ ] Services unchanged (`WorkoutTrackingService`, `UnlockService`, `AppBlockingService`)
- [ ] No boolean helpers added to controller
- [ ] No time leaks introduced in controller

### UI State Mapping (This Layer)
- [ ] All UI states derive from `PushinState` + target lists
- [ ] No UI state mapping uses `PushinState` alone
- [ ] Every mapping validates with `blockedTargets.isNotEmpty` or `accessibleTargets.isNotEmpty`
- [ ] Time is injected via constructor/method parameters, never `DateTime.now()`
- [ ] No boolean helpers created in ViewModel
- [ ] Target lists are passed to UI states for platform integration

### Blocking Contract Compliance
- [ ] `getBlockedTargets(now)` is the ONLY way to determine blocked content
- [ ] `getAccessibleTargets(now)` is the ONLY way to determine accessible content
- [ ] No boolean abstractions wrap these methods
- [ ] Platform integrations can extract actual identifiers from target lists
- [ ] Mini-recommendations derive from `accessibleTargets.isNotEmpty`

### Platform Integration Readiness
- [ ] `blockedTargets` contain `platformAgnosticIdentifier` strings
- [ ] `accessibleTargets` contain `platformAgnosticIdentifier` strings
- [ ] Apple Screen Time can map these to bundle IDs
- [ ] Android Digital Wellbeing can map these to package names
- [ ] Mock implementation works without platform APIs

## Validation Checklist

✅ **Controller remains pure**: No UI state logic added to PushinController  
✅ **Blocking contract intact**: All decisions derive from target lists  
✅ **Time injection respected**: No `DateTime.now()` calls anywhere (fixed ViewModel initialization)  
✅ **Deterministic mapping**: Same domain state → same UI state  
✅ **No boolean APIs**: No boolean helpers or shortcuts introduced  
✅ **PushinState + target lists**: Never infer UI state from `PushinState` alone  
✅ **Platform agnostic**: Works with Apple Screen Time, Android, or mock  
✅ **Ready for Prompt G**: UI composition layer can consume these states  

## Summary

UI State Mapping provides:
- **Deterministic conversion**: Domain state → UI state via blocking contract
- **Target list driven**: ALL blocking decisions from `getBlockedTargets()`/`getAccessibleTargets()`
- **Blocking contract-first**: Target lists are authoritative, never use shortcuts
- **Platform ready**: Compatible with Apple Screen Time and Android Digital Wellbeing
- **Testable**: Pure functions with explicit time injection
- **iOS-first**: Designed for Flutter/SwiftUI with native platform integration patterns

### Critical Reminder for Prompt G

When implementing UI composition:
1. **Never call controller methods directly from widgets**
2. **Always go through ViewModel/state management**
3. **Always inject time from external timer/scheduler**
4. **Always validate UI state with target lists**
5. **Never create boolean shortcuts**

**Status**: ✅ **UI STATE MAPPING SEALED - READY FOR PROMPT G (UI COMPOSITION)**
