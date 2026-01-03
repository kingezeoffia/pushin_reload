# PUSHIN' MVP - App Blocking & Screen Time Implementation

**Status**: ✅ Core Logic Implemented  
**Date**: December 15, 2025  
**Architect**: Barry (Quick Flow Solo Dev)

---

## 📋 Overview

This document describes the app blocking and screen time limit implementation for PUSHIN' MVP, with realistic platform constraints and UX-based blocking approach.

### Key Design Decisions

1. **UX-Based Blocking** (not system-level enforcement)
   - Shows full-screen `AppBlockOverlay` when blocked app launched
   - Motivates users to start workouts instead of relying on OS blocking
   - Works consistently across iOS and Android

2. **Platform Monitoring with Graceful Fallback**
   - iOS: Screen Time APIs when available, overlay otherwise
   - Android: UsageStats polling + overlay (Play Store compliant)

3. **Daily Time Limits with Local Persistence**
   - Hive-based storage (no backend required for MVP)
   - Midnight reset in local timezone
   - Plan-based caps (Free: 1hr, Standard: 3hr, Advanced: unlimited)

---

## 🏗️ Architecture

### Core Services Implemented

#### 1. WorkoutRewardCalculator
**Path**: `lib/services/WorkoutRewardCalculator.dart`

Converts workout reps → unlock time (seconds).

**Formula**: `reps × 30 seconds × difficulty_multiplier`

**Difficulty Multipliers**:
- Push-ups: 1.0
- Squats: 1.0
- Sit-ups: 1.0
- Plank: 1.5 (harder)
- Jumping Jacks: 0.8 (easier)

**Example**:
```dart
final calculator = WorkoutRewardCalculator();
final seconds = calculator.calculateEarnedTime(
  workoutType: 'push-ups',
  repsCompleted: 20,
); // Returns 600 (10 minutes)
```

**Tests**: `test/services/workout_reward_calculator_test.dart` (9 test cases)

---

#### 2. DailyUsageTracker
**Path**: `lib/services/DailyUsageTracker.dart`

Tracks daily unlock time with Hive persistence.

**Features**:
- Earned time (from workouts)
- Consumed time (actual usage)
- Daily cap enforcement (plan-based)
- Automatic midnight reset
- 30-day history cleanup

**Storage Schema**:
```dart
DailyUsage {
  date: "2025-12-15"
  earnedSeconds: 1800  // 30 minutes from 3 workouts
  consumedSeconds: 900  // 15 minutes used
  planTier: "free"
  lastUpdated: DateTime
}
```

**Daily Caps**:
- Free: 3600s (1 hour)
- Standard: 10800s (3 hours)
- Advanced: -1 (unlimited)

**Usage**:
```dart
final tracker = DailyUsageTracker();
await tracker.initialize();

// After workout
await tracker.addEarnedTime(600); // +10 minutes

// During session
await tracker.consumeTime(60); // -1 minute

// Check status
final usage = await tracker.getTodayUsage();
print(usage.remainingSeconds);
print(usage.hasReachedDailyCap);
```

---

#### 3. AppBlockOverlay Widget
**Path**: `lib/ui/widgets/AppBlockOverlay.dart`

Full-screen motivational overlay shown when:
- User launches blocked app
- Daily cap reached
- Unlock session expired (after grace)

**Design** (GO Club-inspired):
- Dark overlay (95% opacity)
- Animated pulsing lock icon
- Gradient circular background
- Single CTA: "Start Workout" button
- Cannot be dismissed (must take action)

**Block Reasons**:
```dart
enum BlockReason {
  appBlocked,        // Launched a blocked app
  dailyCapReached,   // Hit 1hr limit (Free plan)
  sessionExpired,    // Grace period ended
}
```

**Usage**:
```dart
AppBlockOverlay(
  reason: BlockReason.appBlocked,
  blockedAppName: 'Instagram',
  onStartWorkout: () {
    // Navigate to workout screen
  },
)
```

---

#### 4. ScreenTimeMonitor (iOS)
**Path**: `lib/services/platform/ScreenTimeMonitor.dart`

iOS Screen Time integration with capability detection.

**Capability Levels**:
```dart
enum ScreenTimeCapability {
  unknown,              // Not initialized
  blockingAvailable,    // Family Sharing enabled - full blocking
  monitoringOnly,       // Can track launches, no system block
  unavailable,          // iOS < 15 or permission denied
}
```

**Reality Check**:
- FamilyControls API requires Family Sharing OR MDM
- Most consumer users DON'T have this enabled
- Fall back to UX overlay when unavailable

**Platform Channel** (requires native iOS module):
```swift
// Native code communicates via method channel
channel.invokeMethod("initialize") -> { capability: "monitoring_only" }
channel.invokeMethod("setBlockedApps", bundleIds: [...])
channel.invokeMethod("startMonitoring")
```

**Event Stream**:
```dart
screenTimeMonitor.appLaunchEvents.listen((event) {
  // User opened Instagram
  showBlockOverlay(event.appName);
});
```

---

#### 5. UsageStatsMonitor (Android)
**Path**: `lib/services/platform/UsageStatsMonitor.dart`

Android usage tracking with 1-second polling.

**Permissions Required**:
- `PACKAGE_USAGE_STATS` (system permission, opens Settings)

**How It Works**:
1. Poll `UsageStatsManager` every 1 second
2. Detect foreground app changes
3. If blocked app → emit launch event
4. UI shows `AppBlockOverlay`

**Why Polling?**:
- No push-based API for foreground app changes
- 1-second interval balances responsiveness vs battery
- UsageStatsManager is efficient (cached by system)

**Play Store Compliance**:
- ✅ No Accessibility Service abuse
- ✅ No SYSTEM_ALERT_WINDOW hacks
- ✅ Clear privacy policy for usage data

---

#### 6. PushinAppController
**Path**: `lib/controller/PushinAppController.dart`

Enhanced controller integrating all services.

**Responsibilities**:
- Wrap core `PushinController` state machine
- Integrate `DailyUsageTracker` for caps
- Integrate `WorkoutRewardCalculator` for rewards
- Manage platform monitors (iOS/Android)
- Expose UI-friendly APIs

**Key Methods**:
```dart
// Start workout with reward calculation
await controller.startWorkout('push-ups', 20);

// Complete workout, track earned time
await controller.completeWorkout(20);

// Get today's usage summary
final summary = await controller.getTodayUsage();
print('Earned: ${summary.earnedMinutes} min');
print('Used: ${summary.consumedMinutes} min');
print('Remaining: ${summary.remainingMinutes} min');

// Check if can unlock more
final hasHitCap = summary.hasReachedCap;

// Listen for block overlay triggers
controller.blockOverlayState.addListener(() {
  if (controller.blockOverlayState.value != null) {
    // Show overlay
  }
});
```

---

## 🎨 UI Integration

### HomeScreen Example
**Path**: `lib/ui/screens/HomeScreen.dart`

Demonstrates state-based rendering:

**LOCKED State**:
- Status card with lock icon
- Workout selection cards
- Push-ups active (full color, gradient)
- Squats grayed out (locked, shows paywall on tap)

**EARNING State**:
- Circular progress ring
- Rep counter (12 / 20)
- Cancel button (with confirmation)

**UNLOCKED State**:
- Green checkmark icon
- Countdown timer (MM:SS)
- "Earn More Time" button

**EXPIRED State**:
- Grace period countdown
- "Start New Workout" CTA

**Block Overlay**:
- Shown over any state when:
  - Blocked app launched
  - Daily cap hit
  - Session expired

---

## 🎨 Theme System
**Path**: `lib/ui/theme/pushin_theme.dart`

GO Club-inspired design system:

**Colors**:
- Primary Blue: `#4F46E5`
- Secondary Blue: `#3B82F6`
- Success Green: `#10B981`
- Error Red: `#EF4444`
- Background Dark: `#0F172A`
- Surface Dark: `#1E293B`

**Gradients**:
```dart
LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [#4F46E5, #3B82F6],
)
```

**Typography** (SF Pro Display / Roboto):
- Headline 1: 40pt, Bold
- Headline 2: 32pt, Bold
- Body 1: 18pt, Regular
- Button: 18pt, Semibold

**Components**:
- Pill buttons (100px border radius)
- Cards (16px border radius, subtle shadow)
- Progress rings (200px diameter, 12px stroke)

---

## 🚀 Running the Implementation

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Hive Adapters
```bash
flutter pub run build_runner build
```

### 3. Run on Device
```bash
# iOS Simulator
flutter run -d "iPhone 15"

# Android Emulator
flutter run -d emulator-5554
```

### 4. Test Core Logic
```bash
flutter test test/services/workout_reward_calculator_test.dart
```

---

## ⚠️ Known Limitations (MVP)

### iOS Screen Time
- **Limitation**: Requires Family Sharing or MDM for system-level blocking
- **Mitigation**: Falls back to UX overlay (90% of users)
- **Action Required**: Build native iOS module (platform channel implementation)
- **Spike Test**: Needed to prove capability detection works

### Android UsageStats
- **Limitation**: 1-second polling may miss very quick app switches
- **Mitigation**: Acceptable for MVP (most sessions >5 seconds)
- **Battery Impact**: Minimal (polling is cheap, no camera/sensors)
- **Action Required**: Build native Android module (platform channel)

### No Backend
- **Limitation**: All data stored locally (Hive)
- **Risks**:
  - User loses phone → loses workout history
  - No server-side receipt validation (fraud risk)
  - Can't sync across devices
- **Mitigation Plan**: Phase 1.1 adds Firebase backend (2 weeks post-launch)

### Camera Pose Detection Deferred
- **Status**: Manual rep counter in MVP
- **Reason**: Pose detection is 3+ week research project
- **Roadmap**: Add ML Kit integration in v1.1

---

## 📱 Platform-Specific Requirements

### iOS
**Min Version**: iOS 15.0 (for Screen Time APIs)

**Frameworks Needed**:
- `FamilyControls` (app selection)
- `ManagedSettings` (blocking enforcement)
- `DeviceActivity` (usage monitoring)

**Permissions**:
- Screen Time access (system prompt)
- Camera (for pose detection - v1.1)
- HealthKit (optional, for step tracking)

**Native Module TODO**:
```swift
// ios/Runner/ScreenTimeModule.swift
class ScreenTimeModule {
  func initialize() -> [String: Any] {
    // Check FamilyControls authorization status
    // Return capability level
  }
  
  func setBlockedApps(bundleIds: [String]) {
    // Use ManagedSettings.Shield
  }
  
  func startMonitoring() {
    // DeviceActivity.monitor
  }
}
```

### Android
**Min Version**: Android 10 (API 29) for Usage Stats

**Permissions Needed**:
```xml
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" 
    tools:ignore="ProtectedPermissions" />
```

**Native Module TODO**:
```kotlin
// android/app/src/main/kotlin/UsageStatsModule.kt
class UsageStatsModule(context: Context) {
  fun hasUsageStatsPermission(): Boolean {
    // Check PACKAGE_USAGE_STATS permission
  }
  
  fun getForegroundApp(): Map<String, String> {
    // Query UsageStatsManager
    // Return packageName + appName
  }
  
  fun getInstalledApps(): List<Map<String, String>> {
    // PackageManager.getInstalledApplications
  }
}
```

---

## ✅ Acceptance Criteria

### Core Services (8/8 Complete)
- [x] WorkoutRewardCalculator (reps → unlock time)
- [x] DailyUsageTracker (Hive persistence, midnight reset)
- [x] AppBlockOverlay widget (GO Club design)
- [x] ScreenTimeMonitor (iOS capability detection)
- [x] UsageStatsMonitor (Android polling)
- [x] PushinAppController (integration layer)
- [x] PushinTheme (GO Club colors/gradients)
- [x] HomeScreen (state-based UI example)

### Testing
- [x] WorkoutRewardCalculator unit tests (9 cases)
- [ ] DailyUsageTracker integration tests (TODO)
- [ ] State machine integration tests (TODO)

### Native Modules
- [ ] iOS ScreenTime platform channel (TODO)
- [ ] Android UsageStats platform channel (TODO)

### Deployment Readiness
- [ ] iOS: Screen Time capability spike test
- [ ] Android: Play Store policy compliance review
- [ ] Privacy policy (usage data disclosure)
- [ ] App Store / Play Store screenshots

---

## 🔄 Next Steps

### Immediate (Week 1)
1. **iOS Screen Time Spike** (2 days)
   - Build native module proof-of-concept
   - Test on non-supervised iPhone
   - Confirm capability detection works
   
2. **Android UsageStats Module** (2 days)
   - Implement native Kotlin module
   - Test polling performance
   - Verify Play Store compliance

3. **Generate Hive Adapters** (30 minutes)
   - Run build_runner for `DailyUsage.g.dart`
   - Test persistence across app restarts

### Short-term (Week 2-3)
4. **Integration Testing**
   - DailyUsageTracker with real Hive storage
   - State transitions with daily cap enforcement
   - Platform monitor event handling

5. **UI Polish**
   - Add loading states
   - Error handling (permission denied, etc.)
   - Dark mode validation

6. **Native Module Completion**
   - Finish iOS Screen Time integration
   - Finish Android UsageStats integration
   - Handle edge cases (app uninstall, permission revoked)

### Future (Post-MVP)
7. **Camera Pose Detection** (v1.1)
8. **Firebase Backend** (v1.1)
9. **Analytics Dashboard** (v1.2)

---

## 📚 References

- **PRD**: `PRD-PUSHIN-MVP.md` (Product Requirements)
- **Architecture**: `ARCHITECTURE_HARDENING.md` (Core state machine)
- **Blocking Contract**: `BLOCKING_CONTRACT.md` (Target-based blocking)
- **iOS Screen Time API**: [Apple Developer Docs](https://developer.apple.com/documentation/familycontrols)
- **Android UsageStats**: [Android Developer Docs](https://developer.android.com/reference/android/app/usage/UsageStatsManager)

---

**Status**: 🟡 Core logic complete, native modules pending  
**Next Blocker**: iOS Screen Time spike test (Winston + Barry, 2 days)

---

**Built by Barry (Quick Flow Solo Dev) 🚀**



































