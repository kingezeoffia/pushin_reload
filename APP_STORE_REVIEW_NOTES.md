# PUSHIN App Store Review Notes - Screen Time Features

## 📋 Critical Review Information

### **Purpose and Functionality**
PUSHIN is a **voluntary digital self-control and focus assistant** that helps users reduce time spent on distracting apps. The app provides tools for intentional digital usage and improved focus sessions.

**NOT a parental control, fitness tracking, or productivity enforcement app.**

### **Screen Time Integration Details**

#### **Family Controls Usage**
- **Purpose**: Enable voluntary app blocking during user-initiated focus sessions
- **User Control**: All blocking is optional, transparent, and instantly reversible
- **Authorization**: Requested only when user explicitly chooses to use focus features
- **Data Handling**: No usage data is transmitted to servers; all processing is local

#### **Key Compliance Points**
- ✅ **Voluntary Only**: Users must explicitly opt-in to Screen Time features
- ✅ **Always Reversible**: App blocking can be disabled instantly at any time
- ✅ **No Coercion**: No forced blocking, mandatory sessions, or enforcement mechanisms
- ✅ **No Surveillance**: No hidden monitoring, background tracking, or data collection
- ✅ **No System Restriction**: Does not block emergency calls, system settings, or core iOS functionality
- ✅ **Clear UX**: All permissions and blocking states are clearly communicated

#### **Technical Implementation**
- Uses Apple's official `FamilyActivityPicker` for app selection
- Employs `ManagedSettingsStore` for voluntary app shielding during focus sessions
- Implements `DeviceActivity` for session scheduling (no continuous monitoring)
- All app blocking is time-limited and user-initiated

#### **Privacy & Data**
- Screen Time data never leaves the device
- No analytics or usage reporting sent to backend
- Activity tokens are opaque and device-specific
- User selections are stored locally only

### **Testing Instructions for Review Team**
1. Launch PUSHIN and navigate to Settings
2. Tap "Enable Focus Sessions" (optional feature)
3. Grant Screen Time permission when prompted
4. Select apps to block using Apple's picker interface
5. Start a focus session (time-limited blocking)
6. Verify blocking can be disabled instantly via Settings
7. Confirm no forced blocking or hidden restrictions

### **Edge Cases Handled**
- App works fully without Screen Time features
- Graceful fallback when permissions denied
- Clear error messages for all failure states
- Token invalidation recovery (re-selection prompt)

### **App Store Guidelines Compliance**
- ✅ **3.1.1** - Purpose matches approved functionality
- ✅ **4.1** - No misleading app blocking claims
- ✅ **5.1.2** - Voluntary parental controls (individual use)
- ✅ **2.3.10** - No hidden features or functionality

---

**Review Team Note**: This app implements Screen Time features as a voluntary focus assistant, not for parental control or mandatory restrictions. All blocking is user-initiated, time-limited, and instantly reversible.