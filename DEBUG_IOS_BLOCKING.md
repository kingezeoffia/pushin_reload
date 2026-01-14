# Debug iOS Screen Time Blocking

## The Problem:
- ✅ App UI says apps are blocked
- ❌ Apps still open normally
- ❌ No iOS shield overlay appears

## Debugging Steps:

### 1. Check Screen Time Authorization Status

Run the app from Xcode (not just Flutter run), and check the **console output**:

**In Xcode:**
1. Click the **▶** button to run
2. Open the app on your device
3. Watch the **console at the bottom** of Xcode

**Look for these log messages:**

```
[ScreenTime] Authorization status: approved  ← Should say "approved"
```

**If you see:**
- ❌ `Authorization status: denied` → Permission not granted
- ❌ `Authorization status: notDetermined` → Permission never requested
- ✅ `Authorization status: approved` → Permission granted (good!)

### 2. Check if Apps Are Being Blocked

When you complete a workout and apps should be blocked, look for:

```
[ScreenTime] Starting focus session
[ScreenTime] Blocking X apps
[ScreenTime] Shield enabled for applications
```

**If you DON'T see these logs:**
- The blocking code isn't being called
- Check state management

### 3. Check if Tokens Are Saved

When you select apps in Family Activity Picker, you should see:

```
[ScreenTime] Family Activity selection changed
[ScreenTime] Selected X applications, Y categories
[ScreenTime] Tokens saved to App Group
```

**If tokens aren't saved:**
- App Group not configured properly
- Check entitlements

---

## Quick Test: Verify Permission

Add this test code temporarily to check authorization:

**In Xcode**, open `ios/Runner/AppDelegate.swift` and add this to `application(_:didFinishLaunchingWithOptions:)`:

```swift
// TEMPORARY DEBUG CODE
if #available(iOS 16.0, *) {
    print("=== SCREEN TIME DEBUG ===")
    let authStatus = AuthorizationCenter.shared.authorizationStatus
    print("Authorization Status: \(authStatus)")
    print("=========================")
}
```

Then run and check the very first log output.

---

## Common Issues:

### Issue 1: Authorization Never Requested

**Symptom:** No iOS permission dialog appeared

**Fix:**
1. In PUSHIN app → Settings → Manage Apps
2. Tap "Select Apps to Block"
3. iOS should show a permission dialog
4. If no dialog appears, the request isn't being triggered

**Check the code flow:**
- `ManageAppsScreen.dart` → should call `presentAppPicker()`
- `FocusModeService.dart` → should call `requestScreenTimePermission()` first
- `ScreenTimeModule.swift` → should trigger authorization request

### Issue 2: Permission Denied

**Symptom:** Console shows `Authorization status: denied`

**Fix:**
1. Delete the app from your iPhone
2. iPhone Settings → General → Reset → Reset Location & Privacy
3. Reinstall and try again
4. Grant permission when prompted

### Issue 3: Tokens Not Saving

**Symptom:** Selected apps but they don't get saved

**Check:**
```swift
// In ScreenTimeModule.swift line 27
private let appGroupSuiteName = "group.com.pushin.reload"
```

Must match exactly what's in:
- Xcode → Signing & Capabilities → App Groups
- Apple Developer Portal → App ID → App Groups

### Issue 4: Blocking Code Not Called

**Symptom:** Authorization works, tokens saved, but no blocking

**This happens when:**
- State is UNLOCKED (user has earned time)
- iOS blocking session never started
- Wrong state management

**Check:**
1. Is user in LOCKED state? (Home screen should show locked)
2. Are apps supposed to be blocked right now?
3. Was `startFocusSession()` called after selecting apps?

---

## Manual Test - Force Blocking

To test if blocking works at all, try this manually in Xcode:

1. Open `ScreenTimeModule.swift`
2. Find the `presentFamilyActivityPicker()` function
3. After apps are selected, add a direct blocking call:

```swift
// TEMPORARY: Force block immediately after selection
if !storedApplications.isEmpty {
    print("[DEBUG] Forcing shield on \(storedApplications.count) apps")
    managedSettingsStore.shield.applications = storedApplications
}
```

Then:
1. Run the app
2. Select apps
3. Exit app
4. Try to open a selected app

**If shield appears now:** State management issue (blocking isn't triggered at right time)
**If still no shield:** Authorization or App Group issue

---

## Expected Flow:

### When LOCKED (apps should be blocked):

```
User opens PUSHIN app
↓
State: LOCKED
↓
iOS: Apps have shields enabled
↓
User tries to open Instagram
↓
iOS shows shield: "App Limit - You've reached your limit"
```

### When UNLOCKED (apps should be accessible):

```
User completes workout
↓
State: UNLOCKED (15 min timer)
↓
iOS: Shields disabled
↓
User tries to open Instagram
↓
Instagram opens normally
```

---

## Next Steps:

1. **Run from Xcode** (not Flutter CLI)
2. **Check console logs** for authorization status
3. **Tell me what you see:**
   - Authorization status?
   - Any error messages?
   - Do logs show blocking being triggered?
4. **Test sequence:**
   - Open app → Settings → Manage Apps
   - Tap "Select Apps"
   - Does iOS permission dialog appear?
   - Can you select apps?
   - After selection, check logs

Send me the console output and I'll tell you exactly what's wrong! 🔍
