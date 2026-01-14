# App Blocking - End-to-End Test Guide

## Overview
This guide tests the complete app blocking flow where:
1. Apps are blocked by default when user hasn't earned screen time
2. User tries to open a blocked app (e.g., Instagram)
3. Native overlay appears blocking the app
4. User clicks "Start Workout" to earn access
5. User completes workout and earns screen time
6. Apps are automatically unblocked for the earned duration

## Prerequisites

### Android Permissions Required
1. **Usage Stats Permission** - Required to detect foreground apps
2. **Overlay Permission** - Required to show blocking overlay over other apps

### Setup Steps
1. Build and install the app: `flutter run`
2. Grant required permissions:
   - Open Settings → Apps → PUSHIN → Permissions
   - Enable "Display over other apps" (Overlay permission)
   - Enable "Usage access" (Usage Stats permission)

## Test Flow

### Step 1: Configure Blocked Apps
1. Open PUSHIN app
2. Navigate to Settings → Manage Blocked Apps
3. Ensure common apps are blocked (Instagram, TikTok, etc.)
4. The app automatically starts the native blocking service on Android

### Step 2: Test Blocking (When Locked)
1. **Ensure you're in LOCKED state** (no earned screen time)
   - You can check this on the home screen
   - If unlocked, wait for time to expire or force lock via dev tools

2. **Launch a blocked app** (e.g., Instagram)
   - Press home button
   - Tap Instagram icon

3. **Expected Result:**
   - Instagram starts to open
   - Within 1 second, native overlay appears over Instagram
   - Overlay shows:
     - Lock icon
     - "Unblock Instagram" headline
     - "Complete a quick workout to access this app" message
     - "Start Workout" button (white/gradient)
     - "Emergency Unlock" button (red outline)

### Step 3: Start Workout from Overlay
1. **Tap "Start Workout" button** on the native overlay

2. **Expected Result:**
   - Native overlay immediately dismisses
   - PUSHIN app opens
   - Automatically navigates to Workout Selection screen
   - Shows workout options (Push-ups, Squats, etc.)

### Step 4: Complete Workout
1. Select a workout type (e.g., Push-ups)
2. Choose unlock duration (e.g., 15 minutes)
3. Complete the required reps
4. Tap "Finish Workout"

5. **Expected Result:**
   - Success overlay appears: "Great Work!"
   - Message: "You earned X minutes of screen time!"
   - Native service receives unlock command
   - Apps are unblocked for the earned duration

### Step 5: Verify Apps Are Unblocked
1. **Press home button** to exit PUSHIN
2. **Launch a previously blocked app** (e.g., Instagram)

3. **Expected Result:**
   - Instagram opens normally
   - NO overlay appears
   - You can use the app freely

4. **Check PUSHIN home screen**
   - Shows UNLOCKED state
   - Countdown timer displays remaining unlock time
   - Timer counts down from earned duration

### Step 6: Test Lock Expiry
1. **Wait for unlock time to expire** (or fast-forward via dev tools)
   - Grace period begins (30 seconds default)
   - Timer shows grace period countdown

2. **After grace period expires:**
   - State transitions to LOCKED
   - Native service receives lock command

3. **Try to launch blocked app again**

4. **Expected Result:**
   - Native blocking overlay appears again
   - Cycle repeats

## Emergency Unlock Test

### Test Emergency Unlock Feature
1. **From native overlay**, tap "Emergency Unlock" button

2. **Expected Result:**
   - Overlay dismisses immediately
   - Apps are unlocked for 5 minutes
   - Emergency unlock counter decrements
   - User can access blocked apps temporarily

3. **Verify limit enforcement:**
   - After 3 emergency unlocks in one day
   - Button becomes disabled
   - Resets at midnight

## Troubleshooting

### Overlay Doesn't Appear
**Check:**
- Overlay permission granted? (Settings → Apps → PUSHIN)
- Usage Stats permission granted?
- Blocked apps list not empty? (Settings → Manage Apps)
- Foreground service running? (notification should show)

**Debug:**
```bash
# Check service status
adb logcat | grep AppBlockingService

# Check if overlay permission granted
adb logcat | grep "Overlay permission"
```

### App Opens Without Overlay
**Possible causes:**
- App not in blocked list
- User is in UNLOCKED state (has earned time)
- Emergency unlock is active
- Polling hasn't detected app yet (takes ~1 second)

### "Start Workout" Button Does Nothing
**Check:**
- Intent channel registered? (Look for "Intent: Start workout" in logs)
- MainActivity handling intent correctly?
- IntentHandler initialized in PushinAppController?

**Debug:**
```bash
# Check intent handling
adb logcat | grep "MainActivity\|IntentHandler"
```

### Workout Completion Doesn't Unlock
**Check:**
- Workout completed successfully?
- `setUnlocked()` called? (Check logs for "Set unlocked")
- Native service received command?

**Debug:**
```bash
# Check unlock flow
adb logcat | grep "setUnlocked\|User unlocked"
```

## Expected Log Output

### When App is Launched
```
AppBlockingService: Foreground app changed: com.instagram.android
AppBlockingService: Blocked app detected: com.instagram.android
AppBlockingService: Overlay shown for: com.instagram.android
```

### When "Start Workout" Clicked
```
MainActivity: handleIntent: action=start_workout, blockedApp=com.instagram.android
IntentHandler: Received start workout intent for app: com.instagram.android
HomeScreen: Navigating to workout from intent
```

### When Workout Completed
```
AppBlockingServiceBridge: Set unlocked for 900 seconds
AppBlockingService: User unlocked for 900 seconds
AppBlockingService: Overlay hidden
```

### When Unlock Expires
```
AppBlockingService: User locked
```

## Success Criteria

✅ **Blocking Works:**
- Overlay appears within 1 second of launching blocked app
- Overlay is full-screen and blocks app interaction
- Message clearly indicates workout requirement

✅ **Workout Flow:**
- "Start Workout" button dismisses overlay
- App navigates to workout selection automatically
- No manual navigation required

✅ **Unlocking Works:**
- Completing workout immediately unlocks apps
- Countdown shows correct remaining time
- Apps remain accessible until time expires

✅ **Re-Locking Works:**
- When time expires, apps block again
- Grace period allows brief continued access
- After grace period, overlay returns

✅ **Edge Cases:**
- Emergency unlock works (max 3/day)
- Service persists across app restarts
- Service starts on device boot (via BootReceiver)

## Performance Notes

- **Polling Interval:** 1 second (balance of responsiveness vs battery)
- **Overlay Latency:** <1s from app launch to overlay shown
- **Memory:** Service runs in foreground, minimal impact
- **Battery:** Negligible (polling is lightweight)

## Known Limitations

1. **Detection Delay:** ~1 second between app launch and overlay (by design)
2. **Accessibility:** Relies on UsageStatsManager (Android 5.0+)
3. **System Apps:** Cannot block system apps or settings
4. **Overlay Dismiss:** User could force-close overlay via system settings (rare)

## Next Steps After Testing

If all tests pass:
1. Remove dev tools from production build
2. Add analytics tracking for blocking events
3. Consider reducing polling interval for Pro plan users
4. Add haptic feedback to overlay buttons
