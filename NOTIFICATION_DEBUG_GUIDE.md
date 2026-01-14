# Shield Notification Debugging Guide

## Issue Summary
Notifications are not appearing when users tap "Earn Screen Time" on the shield overlay.

## Root Cause Analysis

After reviewing all components, I identified several potential issues:

### 1. **Notification Permissions Not Verified**
The `NotificationService` requests permissions during initialization but never checks if they're granted before attempting to show notifications.

### 2. **Background Timer Limitation**
The `ShieldNotificationMonitor` uses `Timer.periodic` which **doesn't run when the app is in background**. When users tap "Earn Screen Time" on the shield, the main app is usually backgrounded, so the timer isn't checking for pending notifications.

### 3. **Limited Error Logging**
There wasn't enough diagnostic logging to determine where the flow was breaking.

## Fixes Implemented

### ✅ Enhanced Permission Checking
- **File**: `lib/services/NotificationService.dart:190-210`
- Added comprehensive permission checking with detailed logging
- Notifications won't attempt to show if permissions are denied
- Provides helpful message directing users to Settings

### ✅ Improved Notification Scheduling
- **File**: `lib/services/NotificationService.dart:89-153`
- Added permission verification before showing notifications
- Enhanced error handling with stack traces
- Changed interruption level to `timeSensitive` for better visibility
- Added explicit presentation flags: `presentAlert`, `presentBadge`, `presentSound`

### ✅ Better Monitoring Initialization
- **File**: `lib/services/ShieldNotificationMonitor.dart:22-38`
- Now checks permissions immediately on initialization
- Performs immediate check for pending notifications on startup
- Better logging of permission status

### ✅ Enhanced Debug Logging
- **File**: `lib/services/ShieldNotificationMonitor.dart:64-109`
- Timestamps on all checks
- Detailed breakdown of notification status
- Stack traces on errors
- Permission verification before showing notifications

### ✅ Debug Tools in Settings
- **File**: `lib/ui/screens/settings/SettingsScreen.dart`
- Added "Debug Tools" section (visible only in debug mode on iOS)
- Two test buttons:
  1. **Test Notification System** - Runs full system test
  2. **Check for Pending Notifications** - Manually triggers a check

## Testing Instructions

### Step 1: Grant Notification Permissions
1. Open the app
2. Go to Settings > Debug Tools (only visible in debug mode)
3. Tap "Test Notification System"
4. If prompted, grant notification permissions
5. Check console logs for permission status

### Step 2: Test Notification Display
1. After granting permissions, tap "Test Notification System" again
2. You should see a test notification appear immediately
3. Check console for: `✅ Workout reminder notification shown successfully`

### Step 3: Test Shield Integration
1. Block some apps using "Manage Blocked Apps"
2. Start a focus session
3. Try to open a blocked app - shield should appear
4. Tap "Earn Screen Time" button
5. Open the PUSHIN app immediately
6. The monitoring system should detect the pending notification
7. Check console for detailed logs

### Step 4: Manual Check
1. In Settings > Debug Tools
2. Tap "Check for Pending Notifications"
3. This manually triggers the notification check
4. Watch console for results

## Console Logs to Watch For

### Successful Flow:
```
🔔 Initializing NotificationService...
📱 iOS notification permissions: true
✅ Notification permissions granted
✅ Shield notification monitor initialized
👀 Started monitoring shield actions
🔍 [timestamp] Checking for pending workout notifications...
📊 Shield notification check result:
   - hasPending: true
   - expired: false
   - alreadyShown: false
   - notificationId: <uuid>
📱 Found valid pending notification: <uuid>
🔔 Attempting to show workout reminder...
✅ Workout reminder notification shown successfully
✅ Notification shown and marked as processed
```

### Permission Denied:
```
⚠️ Notifications are not enabled - user needs to grant permissions
❌ Cannot show notification - permissions not granted
💡 Ask user to enable: Settings > PUSHIN > Notifications
```

### No Pending Notification:
```
🔍 [timestamp] Checking for pending workout notifications...
📊 Shield notification check result:
   - hasPending: false
ℹ️ No valid pending notification to show
```

## Common Issues & Solutions

### Issue: Permissions Denied
**Symptom**: Console shows `❌ Cannot show notification - permissions not granted`

**Solution**:
1. Go to iOS Settings > PUSHIN > Notifications
2. Enable: Allow Notifications, Alerts, Sounds, Badges
3. Return to app and test again

### Issue: App Group Not Accessible
**Symptom**: Console shows `⚠️ App Group container is NULL`

**Solution**:
1. Delete app from device
2. Clean build: `flutter clean`
3. Rebuild and reinstall
4. This ensures app group provisioning is properly set up

### Issue: Monitoring Not Running
**Symptom**: No "🔍 Checking for pending workout notifications..." logs

**Solution**:
1. Ensure app is in foreground (Timer only runs when active)
2. Check if monitoring started: Look for `👀 Started monitoring shield actions`
3. Try manual check via Debug Tools

### Issue: Notification Expires Too Quickly
**Symptom**: Console shows `expired: true`

**Solution**:
- Notifications expire after 5 minutes (see `ShieldActionExtension.swift:76`)
- User must open the app within 5 minutes of tapping "Earn Screen Time"
- This is intentional to prevent stale notifications

## Architecture Overview

```
User Taps "Earn Screen Time"
         ↓
ShieldActionExtension.swift
  - Stores: pending_notification_id
  - Stores: notification_expires_at
  - Stores: shield_action_timestamp
         ↓
     App Group UserDefaults
         ↓
ShieldNotificationMonitor (Timer: every 2s)
         ↓
ScreenTimeModule.checkPendingWorkoutNotification()
  - Reads from App Group
  - Checks expiration
  - Checks deduplication
         ↓
NotificationService.showWorkoutReminder()
  - Checks permissions
  - Shows local notification
         ↓
User sees notification
User taps notification
         ↓
Navigate to workout screen
```

## Next Steps

1. **Run the app in debug mode**
2. **Use Debug Tools to test** (Settings > Debug Tools)
3. **Watch console logs** to see where the flow breaks
4. **Grant notification permissions** if not already granted
5. **Test the full flow**: Shield → Earn Screen Time → Notification → Workout

## Important Notes

- **Timer Limitation**: The monitoring timer only runs when the app is in foreground or background (not when killed)
- **App Must Be Running**: Users must open the app after tapping "Earn Screen Time" for the notification to be scheduled
- **5 Minute Expiry**: Pending notifications expire 5 minutes after shield action
- **Debug Mode Only**: Debug tools are only visible in debug mode (`kDebugMode = true`)

## Files Modified

1. `lib/services/ShieldNotificationMonitor.dart` - Enhanced logging and permission checks
2. `lib/services/NotificationService.dart` - Improved notification scheduling and permission handling
3. `lib/ui/screens/settings/SettingsScreen.dart` - Added debug tools section

## Alternative: Native Notification Manager

There's an unused `NotificationManager.swift` file that implements native iOS notifications with proper UNUserNotificationCenter integration. If the Flutter-based approach continues to have issues, consider using this native implementation instead. It would require:
1. Initializing NotificationManager in AppDelegate
2. Setting up lifecycle callbacks
3. Creating Flutter platform channel bindings

The native approach may be more reliable for background notification scheduling.
