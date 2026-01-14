# Quick Xcode Setup - DeviceActivityReport Extension

## 1️⃣ Create Extension Target (2 minutes)

```bash
# Open Xcode
open ios/Runner.xcworkspace
```

**In Xcode:**
1. **File → New → Target**
2. Search **"Device Activity Report Extension"**
3. Product Name: `DeviceActivityReportExtension`
4. Click **Finish** → **Activate**

## 2️⃣ Add Files to Target (1 minute)

**In Project Navigator:**
1. Find `ios/DeviceActivityReportExtension/` folder
2. Right-click → **Add Files to "Runner"**
3. Select all `.swift` files
4. ✅ Check **ONLY** `DeviceActivityReportExtension` target
5. Click **Add**

## 3️⃣ Configure Capabilities (2 minutes)

**Select DeviceActivityReportExtension target:**
1. **Signing & Capabilities** tab
2. Click **+ Capability**
3. Add **App Groups** → Check `group.com.pushin.reload`
4. Click **+ Capability**
5. Add **Family Controls**

## 4️⃣ Build & Run (1 minute)

1. Select **Runner** scheme (top toolbar)
2. Select your **physical iOS device** (not simulator)
3. Press ⌘B to build
4. Press ⌘R to run

## ✅ Verify It Works

**In app:**
- Grant Screen Time permission when prompted
- Check console: `✅ Started screen time monitoring`
- Wait 15-30 minutes
- Home tab widgets should show real data

## 🐛 Quick Troubleshooting

| Issue | Fix |
|-------|-----|
| Build errors | Clean build folder (⌘⇧K) |
| No data after hours | Delete app, clean, reinstall |
| Extension not running | Check App Group name matches exactly |
| "Simulator not supported" | Must use physical device |

---

**Total time: ~5 minutes** ⏱️

For detailed instructions, see: `DEVICE_ACTIVITY_REPORT_SETUP.md`
