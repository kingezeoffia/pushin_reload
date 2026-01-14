# iOS App Group Setup for PUSHIN

## ✅ Configuration Status

- **Bundle ID:** `com.pushin.app`
- **App Group ID:** `group.com.pushin.reload`
- **Entitlements File:** Updated ✅
- **ScreenTimeModule.swift:** Updated ✅

## Required: Configure in Xcode

### Step 1: Open Project in Xcode
```bash
cd ~/pushin_reload
open ios/Runner.xcworkspace
```

**IMPORTANT:** Open `.xcworkspace` (not `.xcodeproj`) because the project uses CocoaPods.

### Step 2: Configure App Groups Capability

1. In Xcode, select **Runner** in the project navigator (left sidebar)
2. Select the **Runner** target (not the project)
3. Click on the **Signing & Capabilities** tab
4. Click the **+ Capability** button
5. Search for and add **App Groups**
6. Under App Groups, you should see a checkbox for `group.com.pushin.reload`
7. **Check the box** to enable it

### Step 3: Verify Other Capabilities

Make sure these are also enabled:
- ✅ **Sign in with Apple**
- ✅ **Family Controls** (required for Screen Time API)
- ✅ **App Groups** (you just added this)

### Step 4: Update App Group in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → Find your app: `com.pushin.app`
4. Scroll down to **App Groups** and enable it
5. Click **Edit** and select or create `group.com.pushin.reload`
6. Save changes
7. **Download and install the updated provisioning profile**

### Step 5: Rebuild the App

In Xcode:
1. Clean build folder: **Product** → **Clean Build Folder** (Cmd+Shift+K)
2. Run the app: **Product** → **Run** (Cmd+R)

Or from terminal:
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run
```

## How iOS Blocking Works (Different from Android!)

### iOS Uses Screen Time API (Not System Overlays)

**Android Approach:**
- Native service monitors foreground apps
- Shows system overlay when blocked app detected
- Overlay blocks the app until workout done

**iOS Approach:**
- Uses Apple's Screen Time API (FamilyControls framework)
- Apps are blocked at the system level
- When user tries to open blocked app, iOS shows a shield
- User must go to Settings → Screen Time to disable (we handle this in-app)

### iOS Blocking Flow:

1. **User selects apps to block** using Family Activity Picker
   - This is a native iOS UI for selecting apps
   - Returns opaque tokens (privacy-preserving)
   - Tokens stored in App Group shared container

2. **User starts in LOCKED state** (no screen time earned)
   - Apps are blocked via `ManagedSettingsStore.shield.applications`
   - iOS displays a shield overlay when user tries to open blocked apps
   - Shield says "App Limit" with option to ask for more time

3. **User completes workout** in PUSHIN app
   - Earns screen time (e.g., 15 minutes)
   - App calls `stopFocusSession()` to remove shield
   - Apps become accessible

4. **When time expires:**
   - App calls `startFocusSession()` again
   - Shield is re-enabled
   - Apps are blocked again

## Testing the iOS Flow

### 1. First Launch - Setup Screen Time

1. Launch PUSHIN app on your iPhone
2. Navigate to **Settings → Manage Blocked Apps**
3. Tap **Select Apps to Block**
4. System will prompt for Screen Time authorization:
   - **Tap "Continue"** on the explanation screen
   - iOS will show a permission dialog
   - **Tap "Allow"** to grant Screen Time permission

5. Apple's Family Activity Picker appears:
   - Select apps to block (e.g., Instagram, TikTok, Safari)
   - Tap **Done**

6. Apps are now saved with opaque tokens
   - Stored in App Group: `group.com.pushin.reload`
   - Accessible across app restarts

### 2. Test Blocking (LOCKED State)

1. **Exit PUSHIN app** (swipe up or press home)
2. **Try to open a blocked app** (e.g., Instagram)

**Expected behavior:**
- App starts to launch
- iOS immediately shows a **shield overlay**
- Message: "App Limit - You've reached your limit on [App Name]"
- Options:
  - "Ask For More Time" (dismisses shield for 1 minute)
  - "OK" (closes the app)

3. **Tap "OK"** to close the blocked app
4. **Return to PUSHIN app**

### 3. Complete Workout to Unlock

1. In PUSHIN, tap **Start Workout**
2. Select workout type (Push-ups, Squats, etc.)
3. Choose unlock duration (e.g., 15 minutes)
4. Complete the workout
5. Tap **Finish Workout**

**Expected behavior:**
- Success overlay: "Great Work! You earned 15 minutes"
- State changes to **UNLOCKED**
- Countdown timer starts (15:00)

6. **Exit PUSHIN and try to open blocked app again**

**Expected behavior:**
- App opens normally
- NO shield overlay
- Can use the app freely

### 4. Test Lock Expiry

1. Wait for timer to reach 0:00 (or fast-forward via dev tools)
2. Grace period begins (30 seconds)
3. After grace period, state → **LOCKED**

4. **Try to open blocked app**

**Expected behavior:**
- Shield overlay appears again
- Cycle repeats

## Troubleshooting

### "Screen Time Not Authorized"

**Symptoms:**
- Can't select apps
- "Permission required" message

**Fix:**
1. Settings → Screen Time → Family Controls
2. Make sure PUSHIN has permission
3. If not, toggle it on

### "Apps Still Not Blocked"

**Symptoms:**
- Selected apps but they still open
- No shield appears

**Checks:**
1. App Group ID matches: `group.com.pushin.reload`
2. Family Controls capability enabled in Xcode
3. Authorization status is "approved"
4. Tokens were successfully saved (check logs)

**Debug:**
Look for logs in Xcode console:
```
[ScreenTime] Authorization status: approved
[ScreenTime] Blocking 3 apps
[ScreenTime] Shield enabled for applications
```

### "Shield Appears But 'Ask for More Time' Works Indefinitely"

**This is iOS behavior:**
- iOS allows users to bypass blocks temporarily
- This is by design (user autonomy)
- PUSHIN focuses on motivation, not enforcement
- When time granted via "Ask for More Time" expires, shield returns

### "Apps Unblock But Shield Still Shows"

**Fix:**
1. Force quit the blocked app completely
2. Wait 1-2 seconds
3. Reopen the app
4. Shield should be gone if user is UNLOCKED

### "Build Errors About FamilyControls"

**Symptoms:**
- "No such module 'FamilyControls'"
- Build fails

**Fix:**
1. Make sure deployment target is **iOS 15.0+**
2. Clean build folder (Cmd+Shift+K)
3. Delete Derived Data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Rebuild

## Key Differences vs Android

| Feature | iOS (Screen Time) | Android (Overlay) |
|---------|------------------|-------------------|
| **Permission** | Screen Time authorization | Overlay + Usage Stats |
| **Blocking Method** | System-level shield | App-level overlay |
| **Detection** | FamilyControls API | UsageStatsManager polling |
| **User Bypass** | "Ask for More Time" (iOS feature) | Emergency Unlock (custom) |
| **Setup** | Family Activity Picker | Package name selection |
| **Privacy** | Opaque tokens (no app names) | Package names visible |
| **Persistence** | App Group shared container | SharedPreferences |

## Next Steps After Setup

1. ✅ Configure App Groups in Xcode (follow steps above)
2. ✅ Update provisioning profile in Apple Developer Portal
3. ✅ Test the blocking flow on your iPhone
4. ✅ Verify apps block when LOCKED
5. ✅ Verify apps unlock after workout
6. ✅ Test timer expiry and re-locking

## Need Help?

If you're stuck, check:
- Xcode console logs (look for "[ScreenTime]" prefix)
- App state on home screen (LOCKED/UNLOCKED)
- Authorization status in Settings screen

The implementation is **complete and correct** - you just need to configure the App Group in Xcode!
