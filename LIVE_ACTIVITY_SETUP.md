# Live Activity Setup (Uber Eats Style Timer)

This will create a **persistent widget** in notification center that shows your unlock time countdown - just like Uber Eats delivery tracking!

## 5-Minute Setup

### 1. Open Xcode
```bash
open ios/Runner.xcworkspace
```

### 2. Add Widget Extension

1. **File** > **New** > **Target**
2. Search for: **Widget Extension**
3. Click **Next**
4. Configure:
   - **Product Name**: `UnlockTimerWidget`
   - **Team**: (select your team)
   - **Include Live Activity**: ✅ **CHECK THIS**
   - **Include Configuration Intent**: ❌ leave unchecked
5. Click **Finish**
6. When asked "Activate scheme?": Click **Activate**

### 3. Add Widget Files

In Xcode Project Navigator:

**A. Delete Xcode's default files:**
1. Find `UnlockTimerWidget` folder
2. Delete the default `.swift` files Xcode created

**B. Add shared attributes (BOTH targets):**
1. Right-click `Runner` folder > **Add Files to "Runner"**
2. Navigate to `ios/Shared/UnlockTimerAttributes.swift`
3. **IMPORTANT**: Check BOTH boxes:
   - ✅ Runner
   - ✅ UnlockTimerWidget
4. Click **Add**

**C. Add widget UI (Widget target only):**
1. Right-click `UnlockTimerWidget` folder > **Add Files to "UnlockTimerWidget"**
2. Select these files from `ios/UnlockTimerWidget/`:
   - `UnlockTimerWidget.swift`
   - `UnlockTimerWidgetBundle.swift`
3. Check ONLY: ✅ UnlockTimerWidget
4. Click **Add**

### 4. Configure App Group

**For Runner target:**
1. Select **Runner** target
2. **Signing & Capabilities** tab
3. Find **App Groups** (should already exist)
4. Note the group name: `group.com.pushin.reload`

**For Widget target:**
1. Select **UnlockTimerWidget** target
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. ✅ Enable: `group.com.pushin.reload` (same as Runner)

### 5. Enable Push Notifications (Widget)

1. Select **UnlockTimerWidget** target
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Push Notifications**

### 6. Update Info.plist (Widget)

1. Select `UnlockTimerWidget/Info.plist`
2. Add these keys:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

### 7. Build & Run

Close Xcode, then:
```bash
flutter clean
flutter run
```

## What You'll Get

**When you complete a workout:**

- **Swipe down notification center** → See persistent timer widget
- **Format**: `4:59`, `4:58`, `4:57`... (updates every second)
- **No sounds** - Silent
- **No popups** - Won't interrupt you
- **Always visible** - Just swipe down to check
- **Dynamic Island** (iPhone 14 Pro+) - Shows compact timer

**Exactly like Uber Eats delivery tracking!**

## Troubleshooting

**Build error**: Make sure both Runner and Widget have the same App Group

**Widget doesn't show**: Check that `NSSupportsLiveActivities` is `true` in Widget's Info.plist

**No Dynamic Island**: Only iPhone 14 Pro/15 Pro have Dynamic Island. Regular iPhones will show in notification center only.
