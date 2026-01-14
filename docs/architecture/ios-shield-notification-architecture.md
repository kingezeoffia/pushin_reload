# iOS Screen Time Shield Notification Enhancement - Technical Architecture

**Platform**: iOS 15.0+
**Date**: 2025-01-05

## System Overview

The enhancement transforms the current shield behavior from a disruptive "close and navigate" pattern to a seamless "notify and guide" experience. The core architectural change is shifting from synchronous app switching to asynchronous notification-based user guidance.

## Component Architecture

### 1. Shield Action Extension (Modified)

**File**: `ios/ShieldAction/ShieldActionExtension.swift`

**Key Changes**:
- Change `completionHandler(.close)` to `completionHandler(.none)` for workout actions
- Maintain `completionHandler(.close)` for emergency unlocks
- Enhanced App Group signaling with deduplication tokens

**New App Group Keys**:
```swift
// Existing
"should_show_workout": Bool
"shield_action_timestamp": Double

// New
"pending_notification_id": String  // UUID for deduplication
"last_notification_time": Double   // Prevent spam
"notification_expires_at": Double  // 5-minute expiration
```

### 2. Notification Manager (New Component)

**File**: `ios/Runner/NotificationManager.swift`

**Responsibilities**:
- Request and manage notification permissions
- Monitor App Group for shield action signals
- Schedule local notifications with proper categorization
- Handle notification responses and deep linking
- Implement deduplication logic

**Core Methods**:
```swift
class NotificationManager {
    func requestPermissions() async -> Bool
    func startMonitoringShieldActions()
    func scheduleWorkoutNotification() -> String? // Returns notification ID
    func handleNotificationResponse(_ response: UNNotificationResponse)
    func cancelPendingNotifications()
}
```

### 3. App Delegate Integration

**File**: `ios/Runner/AppDelegate.swift`

**Enhancements**:
- Initialize notification manager on app launch
- Request notification permissions during onboarding
- Handle deep link URLs from notifications
- Coordinate between notification system and Flutter navigation

### 4. Deep Link Handler

**Integration Points**:
- Custom URL scheme: `pushin://workout`
- AppDelegate URL handling for cold starts
- SceneDelegate URL handling for warm starts
- Flutter navigation bridge for workout screen routing

## Notification Design

### Notification Specification

```swift
let content = UNMutableNotificationContent()
content.title = "Earn Screen Time"
content.body = "Complete a quick workout to unblock your apps"
content.sound = .default
content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
content.categoryIdentifier = "WORKOUT_REMINDER"
content.threadIdentifier = "workout-reminder"
content.userInfo = [
    "deepLink": "pushin://workout",
    "notificationId": generatedUUID,
    "expiresAt": expirationTimestamp
]
```

### Notification Category

```swift
let startAction = UNNotificationAction(
    identifier: "START_WORKOUT",
    title: "Start Workout",
    options: .foreground
)

let laterAction = UNNotificationAction(
    identifier: "LATER",
    title: "Later",
    options: .destructive
)

let category = UNNotificationCategory(
    identifier: "WORKOUT_REMINDER",
    actions: [startAction, laterAction],
    intentIdentifiers: [],
    options: .customDismissAction
)
```

### Expiration & Cleanup

- **Expiration**: 5 minutes from creation
- **Auto-dismissal**: System handles automatic removal
- **Cleanup**: Remove expired pending notifications on app launch

## App Group Communication Protocol

### Signal Flow: Shield Action → Main App

1. **Shield Extension** writes to App Group:
   ```swift
   store.set(true, forKey: "should_show_workout")
   store.set(Date().timeIntervalSince1970, forKey: "shield_action_timestamp")
   store.set(UUID().uuidString, forKey: "pending_notification_id")
   store.set(Date().timeIntervalSince1970 + 300, forKey: "notification_expires_at") // 5 min
   store.synchronize()
   ```

2. **Notification Manager** monitors and responds:
   ```swift
   // Check for new signals every 2 seconds when app is active
   // Immediate check on app launch/foreground
   if let notificationId = store.string(forKey: "pending_notification_id"),
      shouldScheduleNotification(notificationId) {
       scheduleWorkoutNotification(withId: notificationId)
   }
   ```

3. **Deduplication Logic**:
   ```swift
   func shouldScheduleNotification(_ newId: String) -> Bool {
       let lastId = store.string(forKey: "last_scheduled_notification_id")
       let lastTime = store.double(forKey: "last_notification_time")
       let now = Date().timeIntervalSince1970

       // Don't schedule if same ID already processed
       if newId == lastId { return false }

       // Throttle: max 1 notification per minute
       if now - lastTime < 60 { return false }

       return true
   }
   ```

## Deep Linking Architecture

### URL Scheme Registration

**Info.plist** additions:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>pushin</string>
    </array>
    <key>CFBundleURLName</key>
    <string>com.pushin.reload</string>
  </dict>
</array>
```

### Deep Link Processing

**AppDelegate** handling:
```swift
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    if url.scheme == "pushin" && url.host == "workout" {
        // Navigate to workout selection
        navigateToWorkoutSelection()
        return true
    }
    return false
}
```

### Flutter Navigation Bridge

**Platform Channel** communication:
```swift
// iOS → Flutter
channel.invokeMethod("navigateToWorkout", arguments: ["source": "notification"])

// Flutter → iOS (confirmation)
channel.setMethodCallHandler { (call, result) in
    if call.method == "workoutNavigationComplete" {
        // Handle successful navigation
    }
}
```

## State Management

### Shield State Persistence

The shield state must persist across app launches and backgrounding:

```swift
struct ShieldState {
    var isActive: Bool
    var blockedApplications: Set<ApplicationToken>
    var pendingWorkoutNotification: String?
    var emergencyUnlocksRemaining: Int
}
```

### Background Processing

**Key Challenge**: iOS may terminate background apps before notification scheduling.

**Solutions**:
1. **Immediate Scheduling**: Schedule notification synchronously when signal detected
2. **Persistent State**: Store notification intent in App Group for recovery
3. **Launch Processing**: Check for pending notifications on app launch
4. **Background Tasks**: Use BGProcessingTask for reliable delivery

## Error Handling & Fallbacks

### Permission Denied
```swift
// Graceful degradation when notifications not allowed
if authorizationStatus != .authorized {
    // Fallback: Show in-app notification or banner
    showInAppWorkoutPrompt()
}
```

### App Group Failure
```swift
// Fallback to standard UserDefaults
let fallbackStore = UserDefaults.standard
// Log error for debugging
print("⚠️ App Group unavailable, using fallback storage")
```

### Notification Delivery Failure
```swift
// Track delivery status
func notificationDelivered(_ notificationId: String) {
    store.set(notificationId, forKey: "last_delivered_notification")
}

func notificationFailed(_ notificationId: String, error: Error) {
    // Log failure, potentially retry or use alternative UX
    print("❌ Notification failed: \(error.localizedDescription)")
}
```

## Performance Considerations

### Memory Management
- Notification manager uses weak references to prevent retain cycles
- Clean up observers when app backgrounds
- Limit stored notification history to prevent unbounded growth

### Battery Impact
- Minimize background monitoring frequency (2-second intervals when active)
- Use efficient notification scheduling (immediate rather than delayed)
- Clean up expired notifications promptly

### Launch Performance
- Lazy initialization of notification manager
- Asynchronous permission requests
- Minimal App Group reads on launch (only check pending state)

## Testing Architecture

### Unit Testing
```swift
class NotificationManagerTests {
    func testNotificationScheduling()
    func testDeduplicationLogic()
    func testPermissionHandling()
    func testDeepLinkProcessing()
}
```

### Integration Testing
```swift
class ShieldNotificationIntegrationTests {
    func testShieldActionTriggersNotification()
    func testNotificationTapOpensWorkoutScreen()
    func testEmergencyUnlockSkipsNotification()
}
```

### Performance Testing
- App launch time with notification system active
- Memory usage during notification scheduling
- Battery drain over 24-hour period

## Migration Strategy

### Backward Compatibility
- Existing shield behavior remains default
- New behavior enabled via feature flag
- Gradual rollout with A/B testing

### Data Migration
- No user data migration required
- App Group schema is additive (new keys don't conflict)
- Clean up legacy keys during future updates

## Security Considerations

### App Group Isolation
- App Group only accessible to Pushin and its extensions
- Sensitive data not stored in notifications (only deep links)
- Emergency unlock logic remains secure

### Notification Privacy
- No user data in notification content
- Deep links are app-internal navigation only
- No tracking or analytics in notification payloads

## Deployment Checklist

### Pre-deployment
- [ ] Notification permissions requested in onboarding
- [ ] App Group provisioning verified
- [ ] Deep link URL scheme registered
- [ ] Emergency unlock functionality preserved
- [ ] Backward compatibility maintained

### Post-deployment Monitoring
- [ ] Notification delivery rates
- [ ] Deep link success rates
- [ ] User engagement with notifications
- [ ] Emergency unlock usage patterns
- [ ] App performance metrics