# iOS Build Error Fixes for Screen Time Shield Enhancement

## Most Common Issues & Solutions

### Issue 1: "Use of undeclared type 'UNUserNotificationCenter'"

**Symptoms:**
- Build fails with "Use of undeclared type 'UNUserNotificationCenter'"
- Error in NotificationManager.swift

**Solution:**
1. Open Xcode project
2. Select Runner target → General → Frameworks, Libraries, and Embedded Content
3. Click + button → Add "UserNotifications.framework"
4. Set to "Do Not Embed"
5. Clean and rebuild

### Issue 2: "Push Notifications capability missing"

**Symptoms:**
- Build succeeds but notifications don't work
- Or: "APS Environment entitlement required"

**Solution:**
1. Select Runner target → Signing & Capabilities
2. Click + button → Add "Push Notifications" capability
3. Ensure provisioning profile supports push notifications

### Issue 3: "App Group entitlement missing"

**Symptoms:**
- App Group communication fails
- UserDefaults(suiteName:) returns nil

**Solution:**
1. Select both Runner and ShieldAction targets
2. Go to Signing & Capabilities
3. Add "App Groups" capability to both targets
4. Add "group.com.pushin.reload" to both targets
5. Verify entitlements files match

### Issue 4: "Deployment target too low"

**Symptoms:**
- Build fails with availability errors
- "UNUserNotificationCenter requires iOS 10.0+"

**Solution:**
1. Select Runner target → General
2. Set "iOS Deployment Target" to 15.0 or higher
3. Do the same for ShieldAction and ShieldConfiguration targets

### Issue 5: "Swift version mismatch"

**Symptoms:**
- Build fails with Swift compatibility errors

**Solution:**
1. Select all targets → Build Settings
2. Search for "Swift Language Version"
3. Set to "Swift 5" for all targets

## Quick Diagnostic Steps

### Step 1: Clean Build
```
Xcode Menu → Product → Clean Build Folder (⌥⇧⌘K)
```

### Step 2: Check Frameworks
```
Runner Target → General → Frameworks, Libraries, and Embedded Content
✅ UserNotifications.framework (Do Not Embed)
```

### Step 3: Check Capabilities
```
Runner Target → Signing & Capabilities
✅ Push Notifications
✅ App Groups (with group.com.pushin.reload)
```

### Step 4: Check Deployment Target
```
All Targets → General → iOS Deployment Target
✅ 15.0 or higher
```

### Step 5: Check Swift Version
```
All Targets → Build Settings → Swift Language Version
✅ Swift 5
```

## Alternative: Flutter Build Check

If Xcode is problematic, try Flutter build:

```bash
flutter clean
flutter pub get
flutter build ios --no-codesign
```

## Emergency Fallback

If all else fails, temporarily disable notifications:

1. Comment out NotificationManager initialization in AppDelegate
2. Keep shield changes but remove notification features
3. Add notification system back after fixing Xcode issues

## Verification Steps

After fixes, verify:

1. ✅ Project builds successfully
2. ✅ Shield extension builds
3. ✅ No console errors on launch
4. ✅ Shield appears on blocked apps
5. ✅ Emergency unlock works
6. ✅ Workout navigation works (without notifications initially)

## Debug Logging

Add this to AppDelegate to verify App Group access:

```swift
if let store = UserDefaults(suiteName: "group.com.pushin.reload") {
    print("✅ App Group accessible")
} else {
    print("❌ App Group NOT accessible - check entitlements")
}
```