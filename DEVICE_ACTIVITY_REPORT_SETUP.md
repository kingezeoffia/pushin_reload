# DeviceActivityReport Extension Setup Guide

This guide walks you through setting up the DeviceActivityReport extension in Xcode to collect **real screen time data** for the "Most Used Apps" and "Screen Time" widgets.

## 📋 Prerequisites

- Xcode 14.0 or later
- iOS 15.0+ deployment target
- Apple Developer account with Screen Time API entitlements

---

## 🚀 Step-by-Step Setup

### Step 1: Open Project in Xcode

```bash
open ios/Runner.xcworkspace
```

### Step 2: Add DeviceActivityReport Extension Target

1. In Xcode, go to **File → New → Target**
2. In the template chooser:
   - Search for "**Device Activity Report Extension**"
   - Select it and click **Next**

3. Configure the extension:
   - **Product Name**: `DeviceActivityReportExtension`
   - **Team**: Select your development team
   - **Language**: Swift
   - **Project**: Runner
   - **Embed in Application**: Runner
   - Click **Finish**

4. When prompted "**Activate 'DeviceActivityReportExtension' scheme?**"
   - Click **Activate**

### Step 3: Add Extension Files to Target

The extension files have already been created in your project. Now you need to add them to the Xcode target:

1. In Xcode's Project Navigator (left sidebar), locate:
   ```
   ios/DeviceActivityReportExtension/
   ├── DeviceActivityReportExtension.swift
   ├── TodayReportScene.swift
   ├── WeeklyReportScene.swift
   └── Info.plist
   ```

2. If these files aren't visible in Xcode:
   - Right-click on the `DeviceActivityReportExtension` folder
   - Select **Add Files to "Runner"...**
   - Navigate to `ios/DeviceActivityReportExtension/`
   - Select all `.swift` files
   - **IMPORTANT**: Check **only** the `DeviceActivityReportExtension` target (not Runner)
   - Click **Add**

### Step 4: Configure Extension Capabilities

1. **Select the DeviceActivityReportExtension target** in Xcode
2. Go to **Signing & Capabilities** tab
3. **Add App Groups capability**:
   - Click **+ Capability** button
   - Search for and add **App Groups**
   - Check the box for: `group.com.pushin.reload`

4. **Add Family Controls capability**:
   - Click **+ Capability** button again
   - Search for and add **Family Controls**

5. **Verify signing**:
   - Make sure **Automatically manage signing** is checked
   - Team is selected
   - A provisioning profile is assigned

### Step 5: Configure Extension Info.plist

The `Info.plist` file should already exist at `ios/DeviceActivityReportExtension/Info.plist`. Verify it contains:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.DeviceActivity.report-extension</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).DeviceActivityReportExtension</string>
    </dict>
</dict>
</plist>
```

### Step 6: Build and Run

1. **Select the Runner scheme** (not the extension scheme)
2. **Build the project**: ⌘B
3. **Run on a physical iOS device**: ⌘R
   - ⚠️ **IMPORTANT**: Screen Time APIs only work on physical devices, NOT simulators

---

## 🧪 Testing the Extension

### 1. Grant Screen Time Permission

When you first run the app:
1. The app will request Screen Time authorization
2. Tap **Continue** in the system prompt
3. **Important**: This authorization is required for the extension to work

### 2. Verify Monitoring Started

Check the Xcode console for:
```
✅ Started DeviceActivity monitoring for screen time reports
✅ Started screen time monitoring
```

### 3. Wait for Data Collection

The extension collects data in the background:
- **First data**: May take 15-30 minutes to appear
- **Updates**: Every few hours throughout the day
- **Reset**: Data resets at midnight

### 4. Check Widget Data

1. Navigate to the Home tab in the app
2. Look at the "Most Used Apps" and "Screen Time" widgets
3. Initially, you'll see mock data with a note: `isMockData: true`
4. After the extension runs, real data will appear with: `isMockData: false`

---

## 🔍 Debugging

### Check Extension is Running

1. Open **Settings → Screen Time** on your device
2. You should see your app listed under "Apps with Screen Time API access"

### View Extension Logs

1. In Xcode, go to **Window → Devices and Simulators**
2. Select your device
3. Click **View Device Logs**
4. Filter for "DeviceActivityReport"

### Common Issues

#### ❌ "No data available" after hours
**Solution**:
- Verify App Group is configured correctly on BOTH targets (Runner + Extension)
- Check that App Group name matches exactly: `group.com.pushin.reload`
- Delete app from device, clean build, reinstall

#### ❌ Extension not being triggered
**Solution**:
- Ensure Screen Time authorization is granted
- Check device has Screen Time enabled in Settings
- Monitoring must be started: `startScreenTimeMonitoring()`

#### ❌ Build errors about missing modules
**Solution**:
- Make sure deployment target is iOS 15.0+ for the extension
- Verify Family Controls capability is added
- Clean build folder: ⌘⇧K

---

## 📊 How It Works

### Architecture

```
┌─────────────────────────────────────┐
│  Flutter App (Runner)               │
│  - Displays widgets                 │
│  - Reads from App Group             │
│  - Starts DeviceActivity monitoring │
└────────────┬────────────────────────┘
             │
             │ Scheduled monitoring
             ↓
┌─────────────────────────────────────┐
│  DeviceActivityReport Extension     │
│  - Collects usage data              │
│  - Aggregates by app                │
│  - Writes to App Group storage      │
└─────────────────────────────────────┘
             │
             │ Shared storage
             ↓
┌─────────────────────────────────────┐
│  App Group Container                │
│  group.com.pushin.reload            │
│  - screen_time_total_minutes_today  │
│  - most_used_apps_today             │
└─────────────────────────────────────┘
```

### Data Flow

1. **App starts** → Calls `startScreenTimeMonitoring()`
2. **iOS schedules** → DeviceActivityReport extension to run periodically
3. **Extension runs** → Collects data, processes it, writes to App Group
4. **App reads** → Fetches data from App Group via `getTodayScreenTime()` and `getMostUsedApps()`
5. **Widgets display** → Real screen time and app usage data

---

## 🎯 Expected Behavior

### Mock Data (Before Extension Runs)
```
Screen Time: 3h 30min
Most Used Apps:
  1. Instagram - 2.5h
  2. YouTube - 1.8h
  3. TikTok - 1.2h

Status: isMockData: true
```

### Real Data (After Extension Runs)
```
Screen Time: [actual usage]
Most Used Apps:
  1. [actual app] - [actual time]
  2. [actual app] - [actual time]
  3. [actual app] - [actual time]

Status: isMockData: false
```

---

## 📝 Notes

- **Privacy**: All data stays on device in the App Group. Nothing is sent to external servers.
- **Accuracy**: Data is collected by iOS system and is as accurate as native Screen Time.
- **Updates**: Extension runs automatically on a schedule managed by iOS.
- **Battery**: Minimal impact as data collection is handled efficiently by iOS.

---

## ✅ Verification Checklist

Before considering setup complete, verify:

- [ ] DeviceActivityReportExtension target created in Xcode
- [ ] Extension has App Groups capability with `group.com.pushin.reload`
- [ ] Extension has Family Controls capability
- [ ] Extension files are added to correct target (not Runner)
- [ ] Project builds without errors
- [ ] App runs on physical device (not simulator)
- [ ] Screen Time authorization granted in app
- [ ] Console shows "Started screen time monitoring"
- [ ] After 15-30 minutes, widgets show real data

---

## 🆘 Need Help?

If you're stuck, check:
1. Xcode console logs for errors
2. Device logs in Window → Devices and Simulators
3. App Group accessibility in ScreenTimeModule verification logs
4. That you're testing on a **physical device**, not simulator

---

**That's it!** Once set up, the extension will automatically collect real screen time data, and your widgets will display actual usage instead of mock data. 🎉
