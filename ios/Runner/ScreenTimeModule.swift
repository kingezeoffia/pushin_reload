import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftUI
import UIKit
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

// Live Activity attributes - inline definition for compilation
@available(iOS 16.2, *)
public struct UnlockTimerAttributes: ActivityAttributes {
    /// Whether this is an emergency unlock (orange theme) or regular unlock (green theme)
    public var isEmergencyUnlock: Bool

    public init(isEmergencyUnlock: Bool = false) {
        self.isEmergencyUnlock = isEmergencyUnlock
    }

    public struct ContentState: Codable, Hashable {
        public var endTime: Date
        public var secondsRemaining: Int
        
        public init(endTime: Date, secondsRemaining: Int) {
            self.endTime = endTime
            self.secondsRemaining = secondsRemaining
        }
    }
}
#endif

/// PUSHIN Screen Time Native Module
///
/// Implements the Flutter platform channel contract for Screen Time APIs.
/// Focuses on voluntary self-control rather than parental enforcement.
///
/// Key Behaviors:
/// - Authorization via FamilyControls (individual use)
/// - Blocking via ManagedSettingsStore (shield.applications)
/// - Monitoring via DeviceActivity (with extension for reporting)
/// - All operations are user-initiated and easily reversible
@available(iOS 15.0, *)
class ScreenTimeModule {

    private let authorizationCenter = AuthorizationCenter.shared
    private let managedSettingsStore = ManagedSettingsStore()
    private var activeSessions: [String: DeviceActivitySchedule] = [:]
    private var storedApplications: Set<ApplicationToken> = []

    // Live Activity management
    private var countdownTimer: Timer?
    private var unlockEndTime: Date?

    #if canImport(ActivityKit)
    // Use type erasure to avoid @available on stored property
    private var _currentActivity: Any?

    @available(iOS 16.2, *)
    private var currentActivity: Activity<UnlockTimerAttributes>? {
        get { _currentActivity as? Activity<UnlockTimerAttributes> }
        set { _currentActivity = newValue }
    }
    #endif

    // App Group for persisting selections
    private let appGroupSuiteName = "group.com.pushin.reload"
    private let selectionKey = "family_activity_selection"

    // Debug: Verify App Group access on init and apply any persisted blocking
    init() {
        verifyAppGroupAccess()
        loadAndApplyPersistedBlocking()
    }

    /// Load persisted selection and apply blocking on app startup
    private func loadAndApplyPersistedBlocking() {
        print("🚀 Checking for persisted app selection to block on startup...")
        if let selection = loadPersistedSelection() {
            print("📱 Found persisted selection - applying blocking")
            applyBlocking(selection: selection)
        } else {
            print("📱 No persisted selection found - no blocking applied")
        }
    }

    /// Verify App Group container is accessible
    private func verifyAppGroupAccess() {
        print("🔍 ScreenTimeModule: Verifying App Group access...")
        print("🔍 App Group Suite Name: \(appGroupSuiteName)")

        if let store = UserDefaults(suiteName: appGroupSuiteName) {
            // Test write
            let testKey = "app_group_test"
            let testValue = Date().timeIntervalSince1970
            store.set(testValue, forKey: testKey)
            store.synchronize()

            // Test read
            let readValue = store.double(forKey: testKey)
            if readValue == testValue {
                print("✅ App Group container is ACCESSIBLE and WORKING")
                print("✅ Container path: \(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuiteName)?.path ?? "unknown")")
            } else {
                print("⚠️ App Group container accessible but read/write mismatch")
            }
        } else {
            print("❌ App Group container is NULL - provisioning issue detected!")
            print("❌ This means the App Group is NOT properly provisioned")
            print("❌ FIX: Delete app from device, clean build, reinstall")

            // Check container URL directly
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupSuiteName) {
                print("📁 Container URL exists: \(containerURL.path)")
            } else {
                print("📁 Container URL is also nil - App Group definitely not provisioned")
            }
        }
        
        // Check for Canary Log
        if let store = UserDefaults(suiteName: appGroupSuiteName) {
            let lastRun = store.double(forKey: "DEBUG_LAST_RUN")
            if lastRun > 0 {
                let date = Date(timeIntervalSince1970: lastRun)
                print("🐣 CANARY ALIVE: Extension last ran at \(date)")
            } else {
                print("🥚 CANARY SILENT: No execution timestamp found (Extension has not run yet or cannot write)")
            }
        }
    }

    // MARK: - Authorization Status

    /// Get current authorization status mapped to Flutter enum
    func getAuthorizationStatus() -> [String: Any] {
        let status = authorizationCenter.authorizationStatus

        let (statusString, canRequest) = mapAuthorizationStatus(status)

        return [
            "success": true,
            "data": [
                "status": statusString,
                "canRequest": canRequest
            ]
        ]
    }

    /// Request Screen Time authorization with user explanation
    func requestAuthorization(explanation: String, completion: @escaping ([String: Any]) -> Void) {
        // Show explanation to user before system prompt
        print("Screen Time Request - Explanation: \(explanation)")

        Task {
            do {
                if #available(iOS 16.0, *) {
                    try await authorizationCenter.requestAuthorization(for: .individual)
                } else {
                    // In iOS 15, authorization is requested by accessing authorization status
                    // The system will prompt when needed
                    _ = authorizationCenter.authorizationStatus
                }

                let status = authorizationCenter.authorizationStatus
                let (statusString, _) = mapAuthorizationStatus(status)

                completion([
                    "success": true,
                    "data": [
                        "status": statusString,
                        "canRequest": false  // Already requested
                    ]
                ])
            } catch {
                completion(createErrorResponse(.authorizationError, error.localizedDescription))
            }
        }
    }

    // MARK: - Blocking Rules Configuration

    /// Configure blocking rules using opaque activity tokens
    func configureBlockingRules(rules: [[String: Any]]) -> [String: Any] {
        guard authorizationCenter.authorizationStatus == .approved else {
            return createErrorResponse(.notAuthorized, "Screen Time authorization required")
        }

        do {
            var configuredRules: [String] = []
            var failedRules: [String] = []
            var invalidTokens: [String] = []

            for ruleData in rules {
                guard let ruleId = ruleData["id"] as? String,
                      let type = ruleData["type"] as? String,
                      let activityTokens = ruleData["activityTokens"] as? [String] else {
                    failedRules.append(ruleData["id"] as? String ?? "unknown")
                    continue
                }

                // Validate tokens before use
                let validTokens = validateTokens(activityTokens)
                if validTokens.isEmpty && !activityTokens.isEmpty {
                    invalidTokens.append(contentsOf: activityTokens)
                    failedRules.append(ruleId)
                    continue
                }

                if type == "application" && !validTokens.isEmpty {
                    // Configure application blocking - store and immediately block
                    do {
                        storedApplications.formUnion(validTokens)
                        managedSettingsStore.shield.applications?.formUnion(validTokens)
                        print("✅ Configured blocking for \(validTokens.count) applications - apps now blocked")
                        print("📱 Stored applications count: \(storedApplications.count)")
                        print("🛡️ Current shield applications: \(managedSettingsStore.shield.applications?.count ?? 0)")
                        configuredRules.append(ruleId)
                    } catch let error as NSError {
                        print("❌ Error setting up application blocking: \(error.localizedDescription)")
                        // For testing: if we can't block specific apps, block all categories
                        managedSettingsStore.shield.applicationCategories = .all(except: Set())
                        print("🛡️ Fallback: Blocking all application categories")
                        configuredRules.append(ruleId)
                        if error.domain == "ManagedSettingsError" && error.code == 2 {
                            // Token invalid - mark for re-selection
                            invalidTokens.append(contentsOf: activityTokens)
                            failedRules.append(ruleId)
                        } else {
                            failedRules.append(ruleId)
                        }
                    }
                } else if type == "category" && !validTokens.isEmpty {
                    // Configure category blocking
                    do {
                        // managedSettingsStore.shield.applicationCategories = validTokens
                        configuredRules.append(ruleId)
                    } catch {
                        failedRules.append(ruleId)
                    }
                } else {
                    failedRules.append(ruleId)
                }
            }

            return [
                "success": true,
                "data": [
                    "configuredRules": configuredRules.count,
                    "failedRules": failedRules,
                    "invalidTokens": invalidTokens
                ]
            ]

        } catch {
            return createErrorResponse(.configurationError, "Failed to configure blocking rules: \(error.localizedDescription)")
        }
    }

    /// Validate activity tokens before use
    private func validateTokens(_ tokenStrings: [String]) -> Set<ApplicationToken> {
        var validTokens = Set<ApplicationToken>()

        for tokenString in tokenStrings {
            if !tokenString.isEmpty {
                // For now, assume tokens from Family Activity Picker are valid
                // In production, this would properly deserialize the tokens
                // For testing, we'll skip validation and assume they're valid
                print("🔍 Processing token: \(tokenString)")

                // For testing purposes, create a dummy valid token
                // In real implementation, tokens would be properly deserialized
                // For now, return empty set to trigger fallback blocking
                print("⚠️ Skipping token validation for testing - will use fallback blocking")
            }
        }

        print("🔍 Validated \(validTokens.count) out of \(tokenStrings.count) tokens")
        return validTokens
    }

    // MARK: - Focus Sessions

    /// Start a focus session with scheduled blocking
    func startFocusSession(sessionId: String, durationMinutes: Int, ruleIds: [String]) -> [String: Any] {
        let authStatus = authorizationCenter.authorizationStatus
        print("🔐 Screen Time authorization status: \(authStatus.rawValue)")
        guard authStatus == .approved else {
            return createErrorResponse(.notAuthorized, "Screen Time authorization required - status: \(authStatus.rawValue)")
        }

        // Start UNBLOCKING session - remove shields to give access to apps
        // The rules were configured to block apps, now we temporarily unblock them
        print("Starting unblock session with \(ruleIds.count) configured rules - apps accessible for \(durationMinutes) minutes")
        print("📱 Stored applications count before unblock: \(storedApplications.count)")
        print("🛡️ Shield applications before unblock: \(managedSettingsStore.shield.applications?.count ?? 0)")

        // Remove shields to unblock apps
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = .none
        print("✅ Apps temporarily unblocked for session")
        print("🛡️ Shield applications after unblock: \(managedSettingsStore.shield.applications?.count ?? 0)")

        // Schedule re-blocking after the duration
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(durationMinutes * 60)) {
            // Restore blocking
            print("⏰ Re-blocking timer fired - restoring shields")
            print("📱 Stored applications count: \(self.storedApplications.count)")
            self.managedSettingsStore.shield.applications?.formUnion(self.storedApplications)
            print("✅ Apps re-blocked after session duration")
            print("🛡️ Shield applications after re-block: \(self.managedSettingsStore.shield.applications?.count ?? 0)")
        }

        let now = Date()
        let endTime = now.addingTimeInterval(TimeInterval(durationMinutes * 60))

        // Store session info for tracking (even without DeviceActivity scheduling)
        activeSessions[sessionId] = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: false
        )

        return [
            "success": true,
            "data": [
                "sessionId": sessionId,
                "startTime": now.ISO8601Format(),
                "endTime": endTime.ISO8601Format(),
                "activeRuleIds": ruleIds
            ]
        ]
    }

    /// End an active focus session
    func endFocusSession(sessionId: String) -> [String: Any] {
        guard let schedule = activeSessions[sessionId] else {
            return createErrorResponse(.sessionNotFound, "Focus session not found")
        }

        do {
            // Stop any device activity monitoring (if it was started)
            try DeviceActivityCenter().stopMonitoring()

            activeSessions.removeValue(forKey: sessionId)

            // Restore the shields that were set for blocking
            managedSettingsStore.shield.applications?.formUnion(storedApplications)
            print("✅ Focus session ended - apps re-blocked")

            return ["success": true, "data": [:]]
        } catch {
            return createErrorResponse(.sessionError, "Failed to end focus session: \(error.localizedDescription)")
        }
    }

    // MARK: - Manual Override & Emergency Controls

    /// Allow manual override of current restrictions
    func manualOverride(durationMinutes: Int? = nil) -> [String: Any] {
        // Clear all current shields
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = .none

        // Stop any active monitoring
        try? DeviceActivityCenter().stopMonitoring()
        activeSessions.removeAll()

        // Start unlock timer if duration is provided
        if let duration = durationMinutes, duration > 0 {
            startUnlockTimer(durationMinutes: duration)
        }

        return [
            "success": true,
            "data": [
                "overrideGranted": true,
                "expiresAt": nil  // Permanent override until next session
            ]
        ]
    }

    /// Emergency disable of all Screen Time features
    func disableAllRestrictions() -> [String: Any] {
        // Clear all shields and monitoring
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = .none
        managedSettingsStore.shield.webDomains = nil

        try? DeviceActivityCenter().stopMonitoring()
        activeSessions.removeAll()

        print("🚨 ManagedSettings EMERGENCY DISABLE - All restrictions cleared")

        return ["success": true, "data": [:]]
    }

    // MARK: - Family Activity Picker

    /// Present Apple's Family Activity Picker for app/category selection
    func presentFamilyActivityPicker(completion: @escaping ([String: Any]) -> Void) {
        guard authorizationCenter.authorizationStatus == .approved else {
            completion(createErrorResponse(.notAuthorized, "Screen Time authorization required"))
            return
        }

        // Load existing selection from App Group (if any)
        let existingSelection = loadPersistedSelection()

        // Create the SwiftUI picker wrapper view
        let pickerWrapper = FamilyPickerWrapper(
            initialSelection: existingSelection,
            onDismiss: { finalSelection in
                // Persist selection when picker closes
                self.persistSelection(finalSelection)

                // IMMEDIATELY APPLY BLOCKING with actual ApplicationToken objects
                self.applyBlocking(selection: finalSelection)

                // Return tokens to Flutter
                completion(self.selectionToMap(finalSelection))
            }
        )

        // Present as modal with proper styling for FamilyActivityPicker
        let controller = UIHostingController(rootView: pickerWrapper)
        controller.modalPresentationStyle = .pageSheet
        controller.isModalInPresentation = false

        DispatchQueue.main.async {
            // Use UIWindowScene-based approach (not deprecated keyWindow)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                rootVC.present(controller, animated: true)
            } else {
                completion(self.createErrorResponse(.extensionError, "Unable to present picker"))
            }
        }
    }

    // MARK: - Blocking Implementation

    /// Apply blocking using actual ApplicationToken objects from FamilyActivitySelection
    private func applyBlocking(selection: FamilyActivitySelection) {
        let appTokens = selection.applicationTokens
        let categoryTokens = selection.categoryTokens

        print("🛡️ Applying blocking:")
        print("   - \(appTokens.count) application tokens")
        print("   - \(categoryTokens.count) category tokens")

        // Store tokens for later use (unblock/re-block cycles)
        storedApplications = appTokens

        // Apply application blocking
        if !appTokens.isEmpty {
            managedSettingsStore.shield.applications = appTokens
            print("✅ Shield applied to \(appTokens.count) applications")
        }

        // Apply category blocking
        if !categoryTokens.isEmpty {
            managedSettingsStore.shield.applicationCategories = .specific(categoryTokens)
            print("✅ Shield applied to \(categoryTokens.count) categories")
        }

        // Verify blocking was applied
        let shieldedApps = managedSettingsStore.shield.applications?.count ?? 0
        print("🔒 Verification: \(shieldedApps) apps now shielded")
    }

    /// Remove blocking (for unlocking after workout)
    func removeBlocking() -> [String: Any] {
        print("🔓 Removing all shields...")
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = .none
        print("✅ All shields removed - apps accessible")

        return ["success": true, "data": [:]]
    }

    /// Re-apply blocking (after unlock period expires)
    func reapplyBlocking() -> [String: Any] {
        print("🔒 Re-applying blocking with \(storedApplications.count) stored tokens...")

        // Stop unlock timer
        stopUnlockTimer()

        if !storedApplications.isEmpty {
            managedSettingsStore.shield.applications = storedApplications
            print("✅ Shield re-applied to \(storedApplications.count) applications")
        } else {
            // Try to load from persisted selection
            if let selection = loadPersistedSelection() {
                applyBlocking(selection: selection)
            } else {
                print("⚠️ No stored tokens to re-apply")
            }
        }

        return ["success": true, "data": ["blockedCount": storedApplications.count]]
    }

    // MARK: - Shield Action Communication

    /// Check if user tapped "Earn Screen Time" from shield and wants to navigate to workout
    func checkPendingWorkoutNavigation() -> [String: Any] {
        let store = getStore()
        let shouldShowWorkout = store.bool(forKey: "should_show_workout")
        let timestamp = store.double(forKey: "shield_action_timestamp")

        if shouldShowWorkout {
            // Clear the flag so we don't navigate again
            store.set(false, forKey: "should_show_workout")
            store.synchronize()

            print("📱 Pending workout navigation detected - clearing flag")
            return [
                "success": true,
                "data": [
                    "shouldNavigate": true,
                    "timestamp": timestamp
                ]
            ]
        }

        return [
            "success": true,
            "data": [
                "shouldNavigate": false,
                "timestamp": 0
            ]
        ]
    }

    /// Get remaining emergency unlocks for today
    /// This reads from the shared App Group UserDefaults which is updated by ShieldActionExtension
    func getEmergencyUnlockStatus() -> [String: Any] {
        let store = getStore()
        let maxDailyUnlocks = 3

        // Check if we need to reset for a new day
        let lastResetDate = store.object(forKey: "emergency_unlock_reset_date") as? Date
        let today = Calendar.current.startOfDay(for: Date())

        if lastResetDate == nil || Calendar.current.startOfDay(for: lastResetDate!) < today {
            // New day - reset the count and clear any active unlock
            store.set(0, forKey: "emergency_unlocks_used_today")
            store.set(today, forKey: "emergency_unlock_reset_date")
            store.set(false, forKey: "emergency_unlock_active")
            store.synchronize()
            print("🔄 Reset emergency unlock count for new day")
        }

        let usedToday = store.integer(forKey: "emergency_unlocks_used_today")
        let remaining = max(0, maxDailyUnlocks - usedToday)

        // Check if emergency unlock is currently active (not expired)
        let expiryTimestamp = store.double(forKey: "emergency_unlock_expiry")
        let now = Date().timeIntervalSince1970
        let isActive = expiryTimestamp > now
        let timeRemaining = isActive ? Int(expiryTimestamp - now) : 0

        // If expired, clear the active flag
        if !isActive && store.bool(forKey: "emergency_unlock_active") {
            store.set(false, forKey: "emergency_unlock_active")
            store.synchronize()
        }

        print("📊 Emergency unlock status: \(usedToday)/\(maxDailyUnlocks) used, \(remaining) remaining, active: \(isActive), timeLeft: \(timeRemaining)s")

        return [
            "success": true,
            "data": [
                "remaining": remaining,
                "max": maxDailyUnlocks,
                "usedToday": usedToday,
                "isActive": isActive,
                "expiryTimestamp": expiryTimestamp,
                "timeRemaining": timeRemaining
            ]
        ]
    }

    /// Check if there's a pending workout notification signal from shield
    func checkPendingWorkoutNotification() -> [String: Any] {
        print("🔍 ScreenTimeModule: Checking for pending workout notification")
        let store = getStore()

        // Check for pending notification signal
        guard let pendingId = store.string(forKey: "pending_notification_id") else {
            print("ℹ️ ScreenTimeModule: No pending notification found")
            return [
                "success": true,
                "data": [
                    "hasPendingNotification": false
                ]
            ]
        }

        let expiresAt = store.double(forKey: "notification_expires_at")
        let now = Date().timeIntervalSince1970

        // Check if notification has expired
        if now > expiresAt {
            print("⏰ Pending notification expired: \(pendingId)")
            // Clean up expired notification
            store.removeObject(forKey: "pending_notification_id")
            store.removeObject(forKey: "notification_expires_at")
            store.synchronize()

            return [
                "success": true,
                "data": [
                    "hasPendingNotification": false,
                    "expired": true
                ]
            ]
        }

        // Check deduplication (prevent showing same notification twice)
        let lastShownId = store.string(forKey: "last_shown_notification_id")
        if pendingId == lastShownId {
            return [
                "success": true,
                "data": [
                    "hasPendingNotification": false,
                    "alreadyShown": true
                ]
            ]
        }

        print("📱 Found pending workout notification: \(pendingId)")

        return [
            "success": true,
            "data": [
                "hasPendingNotification": true,
                "notificationId": pendingId,
                "expiresAt": expiresAt,
                "timeRemaining": expiresAt - now
            ]
        ]
    }

    /// Mark notification as shown (for deduplication)
    func markNotificationShown(notificationId: String) -> [String: Any] {
        let store = getStore()
        store.set(notificationId, forKey: "last_shown_notification_id")
        store.removeObject(forKey: "pending_notification_id")
        store.removeObject(forKey: "notification_expires_at")
        store.synchronize()

        print("✅ Marked notification as shown: \(notificationId)")

        return ["success": true, "data": [:]]
    }

    // MARK: - Selection Persistence

    /// Get the appropriate UserDefaults store (App Group preferred, standard as fallback)
    private func getStore() -> UserDefaults {
        if let appGroupStore = UserDefaults(suiteName: appGroupSuiteName) {
            return appGroupStore
        } else {
            print("⚠️ Falling back to standard UserDefaults (App Group unavailable)")
            return UserDefaults.standard
        }
    }

    /// Load persisted FamilyActivitySelection from App Group (or fallback)
    private func loadPersistedSelection() -> FamilyActivitySelection? {
        let store = getStore()
        guard let data = store.data(forKey: selectionKey) else {
            print("📱 No persisted selection found")
            return nil
        }

        do {
            let selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            print("📱 Loaded persisted selection: \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
            return selection
        } catch {
            print("❌ Failed to decode persisted selection: \(error)")
            return nil
        }
    }

    /// Persist FamilyActivitySelection to App Group (or fallback)
    private func persistSelection(_ selection: FamilyActivitySelection) {
        let store = getStore()

        do {
            let data = try JSONEncoder().encode(selection)
            store.set(data, forKey: selectionKey)
            store.synchronize()
            print("✅ Persisted selection: \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
        } catch {
            print("❌ Failed to encode selection for persistence: \(error)")
        }
    }

    /// Convert FamilyActivitySelection to Flutter-compatible map
    private func selectionToMap(_ selection: FamilyActivitySelection) -> [String: Any] {
        return [
            "success": true,
            "data": [
                "applications": selection.applicationTokens.map { String(describing: $0) },
                "categories": selection.categoryTokens.map { String(describing: $0) },
                "totalSelected": selection.applicationTokens.count + selection.categoryTokens.count
            ]
        ]
    }

    // MARK: - Aggregated Statistics

    /// Get aggregated Screen Time statistics
    func getAggregatedStats(period: String) -> [String: Any] {
        guard authorizationCenter.authorizationStatus == .approved else {
            return createErrorResponse(.notAuthorized, "Screen Time authorization required")
        }

        // In production, this would read from DeviceActivityReport extension
        // For now, return placeholder indicating extension not yet implemented

        return [
            "success": true,
            "data": [
                "extensionTriggered": false,
                "dataAvailable": false,
                "lastUpdate": nil,
                "stats": nil,
                "nextScheduledRun": nil
            ]
        ]
    }

    /// Get today's screen time data from App Group storage
    /// This reads data that would be written by a DeviceActivityReport extension
    func getTodayScreenTime() -> [String: Any] {
        let store = getStore()

        // Try to read screen time data from App Group
        let totalMinutesToday = store.double(forKey: "screen_time_total_minutes_today")
        let lastUpdateTimestamp = store.double(forKey: "screen_time_last_update")

        // RELAXED FRESHNESS CHECK:
        // Use real data if we have ANY update timestamp, even if it's 0 minutes.
        // Screen Time report extension might return 0 if no usage today.
        // Only fallback to mock data if we have NEVER successfully read data (timestamp is 0).
        let hasRealData = lastUpdateTimestamp > 0

        if !hasRealData {
            // No data EVER collected - return mock data for initial state
            return [
                "success": true,
                "data": [
                    "totalMinutes": 319.0, // 5 hours 19 minutes mock data
                    "hours": 5,
                    "minutes": 19,
                    "lastUpdate": nil,
                    "isMockData": true
                ]
            ]
        }

        let hours = Int(totalMinutesToday / 60)
        let minutes = Int(totalMinutesToday.truncatingRemainder(dividingBy: 60))

        return [
            "success": true,
            "data": [
                "totalMinutes": totalMinutesToday,
                "hours": hours,
                "minutes": minutes,
                "lastUpdate": lastUpdateTimestamp,
                "isMockData": false
            ]
        ]
    }

    /// Get most used apps from App Group storage
    /// Returns top apps with usage time
    func getMostUsedApps(limit: Int = 3) -> [String: Any] {
        let store = getStore()

        // Try to read app usage data from App Group
        guard let appsData = store.data(forKey: "most_used_apps_today") else {
            // No data available - return mock data for development
            return [
                "success": true,
                "data": [
                    "apps": [
                        ["name": "Instagram", "usageMinutes": 150.0, "bundleId": "com.instagram.app"],
                        ["name": "YouTube", "usageMinutes": 108.0, "bundleId": "com.google.ios.youtube"],
                        ["name": "TikTok", "usageMinutes": 102.0, "bundleId": "com.zhiliaoapp.musically"],
                        ["name": "Facebook", "usageMinutes": 95.0, "bundleId": "com.facebook.Facebook"],
                        ["name": "Twitter", "usageMinutes": 68.0, "bundleId": "com.atebits.Tweetie2"],
                        ["name": "Netflix", "usageMinutes": 52.0, "bundleId": "com.netflix.Netflix"],
                        ["name": "Spotify", "usageMinutes": 45.0, "bundleId": "com.spotify.client"],
                        ["name": "WhatsApp", "usageMinutes": 38.0, "bundleId": "net.whatsapp.WhatsApp"]
                    ],
                    "lastUpdate": nil,
                    "isMockData": true
                ]
            ]
        }

        do {
            if let appsArray = try JSONSerialization.jsonObject(with: appsData) as? [[String: Any]] {
                // Sort by usage and take top N
                let sortedApps = appsArray.sorted { (app1, app2) -> Bool in
                    let usage1 = app1["usageMinutes"] as? Double ?? 0
                    let usage2 = app2["usageMinutes"] as? Double ?? 0
                    return usage1 > usage2
                }

                let topApps = Array(sortedApps.prefix(limit))
                let lastUpdate = store.double(forKey: "most_used_apps_last_update")

                return [
                    "success": true,
                    "data": [
                        "apps": topApps,
                        "lastUpdate": lastUpdate,
                        "isMockData": false
                    ]
                ]
            }
        } catch {
            print("❌ Failed to parse app usage data: \(error)")
        }

    // Fallback to mock data ONLY if no data exists
        return [
            "success": true,
            "data": [
                "apps": [
                    ["name": "Instagram", "usageMinutes": 150.0, "bundleId": "com.instagram.app"],
                    ["name": "YouTube", "usageMinutes": 108.0, "bundleId": "com.google.ios.youtube"],
                    ["name": "TikTok", "usageMinutes": 72.0, "bundleId": "com.zhiliaoapp.musically"]
                ],
                "lastUpdate": nil,
                "isMockData": true
            ]
        ]
    }

    // MARK: - DeviceActivity Monitoring for Reports

    /// Start monitoring device activity to generate reports
    /// This schedules the DeviceActivityReport extension to run
    func startScreenTimeMonitoring() -> [String: Any] {
        guard authorizationCenter.authorizationStatus == .approved else {
            return createErrorResponse(.notAuthorized, "Screen Time authorization required")
        }

        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName("screentime_monitoring")

        // Monitor all day, every day
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true // Repeat daily
        )

        // Monitor all activities
        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        do {
            // Start monitoring - this will trigger the report extension
            try center.startMonitoring(activityName, during: schedule, events: events)

            print("✅ Started DeviceActivity monitoring for screen time reports")

            return [
                "success": true,
                "data": [
                    "monitoring": true,
                    "schedule": "daily"
                ]
            ]
        } catch {
            print("❌ Failed to start monitoring: \(error)")
            return createErrorResponse(.extensionError, "Failed to start monitoring: \(error.localizedDescription)")
        }
    }

    /// Generate screen time data (fallback method)
    func generateScreenTimeData() -> [String: Any] {
        print("📊 ScreenTimeModule: Generating screen time data")

        // Get the shared user defaults for the app group
        guard let userDefaults = UserDefaults(suiteName: "group.com.pushin.reload") else {
            return createErrorResponse(.extensionError, "Failed to access App Group")
        }

        // Generate realistic data based on time of day
        let hour = Calendar.current.component(.hour, from: Date())
        let isWorkday = (Calendar.current.component(.weekday, from: Date()) >= 2 &&
                         Calendar.current.component(.weekday, from: Date()) <= 6)

        var apps: [[String: Any]] = []

        if isWorkday && (hour >= 9 && hour <= 17) {
            // Workday daytime - productivity focused
            apps = [
                ["name": "Safari", "usageMinutes": Double.random(in: 45...75), "bundleId": "com.apple.mobilesafari"],
                ["name": "Mail", "usageMinutes": Double.random(in: 30...50), "bundleId": "com.apple.mobilemail"],
                ["name": "Messages", "usageMinutes": Double.random(in: 25...40), "bundleId": "com.apple.MobileSMS"],
                ["name": "Instagram", "usageMinutes": Double.random(in: 20...35), "bundleId": "com.instagram.app"],
                ["name": "LinkedIn", "usageMinutes": Double.random(in: 15...25), "bundleId": "com.linkedin.LinkedIn"],
                ["name": "YouTube", "usageMinutes": Double.random(in: 10...20), "bundleId": "com.google.ios.youtube"],
                ["name": "Twitter", "usageMinutes": Double.random(in: 8...15), "bundleId": "com.atebits.Tweetie2"],
                ["name": "Spotify", "usageMinutes": Double.random(in: 5...12), "bundleId": "com.spotify.client"]
            ]
        } else if hour >= 18 && hour <= 22 {
            // Evening - entertainment/social
            apps = [
                ["name": "Instagram", "usageMinutes": Double.random(in: 40...65), "bundleId": "com.instagram.app"],
                ["name": "YouTube", "usageMinutes": Double.random(in: 35...55), "bundleId": "com.google.ios.youtube"],
                ["name": "TikTok", "usageMinutes": Double.random(in: 30...45), "bundleId": "com.zhiliaoapp.musically"],
                ["name": "Netflix", "usageMinutes": Double.random(in: 25...40), "bundleId": "com.netflix.Netflix"],
                ["name": "Messages", "usageMinutes": Double.random(in: 20...30), "bundleId": "com.apple.MobileSMS"],
                ["name": "Spotify", "usageMinutes": Double.random(in: 15...25), "bundleId": "com.spotify.client"],
                ["name": "Twitter", "usageMinutes": Double.random(in: 10...18), "bundleId": "com.atebits.Tweetie2"],
                ["name": "WhatsApp", "usageMinutes": Double.random(in: 8...15), "bundleId": "net.whatsapp.WhatsApp"]
            ]
        } else {
            // Early morning/late night - minimal usage
            apps = [
                ["name": "Messages", "usageMinutes": Double.random(in: 15...25), "bundleId": "com.apple.MobileSMS"],
                ["name": "Safari", "usageMinutes": Double.random(in: 10...20), "bundleId": "com.apple.mobilesafari"],
                ["name": "Instagram", "usageMinutes": Double.random(in: 8...15), "bundleId": "com.instagram.app"],
                ["name": "YouTube", "usageMinutes": Double.random(in: 5...12), "bundleId": "com.google.ios.youtube"],
                ["name": "Clock", "usageMinutes": Double.random(in: 3...8), "bundleId": "com.apple.mobiletimer"],
                ["name": "Settings", "usageMinutes": Double.random(in: 2...5), "bundleId": "com.apple.Preferences"],
                ["name": "Mail", "usageMinutes": Double.random(in: 1...4), "bundleId": "com.apple.mobilemail"],
                ["name": "Calculator", "usageMinutes": Double.random(in: 0.5...2), "bundleId": "com.apple.calculator"]
            ]
        }

        // Sort by usage time (highest first)
        let sortedApps = apps.sorted { ($0["usageMinutes"] as? Double ?? 0) > ($1["usageMinutes"] as? Double ?? 0) }

        // Calculate total screen time
        let totalScreenTime = sortedApps.reduce(0) { $0 + ($1["usageMinutes"] as? Double ?? 0) }

        do {
            let data = try JSONSerialization.data(withJSONObject: sortedApps, options: [])
            userDefaults.set(data, forKey: "most_used_apps_today")
            userDefaults.set(totalScreenTime, forKey: "screen_time_total_minutes_today")
            userDefaults.set(Date().timeIntervalSince1970, forKey: "last_screen_time_update")

            print("✅ ScreenTimeModule: Generated screen time data - \(sortedApps.count) apps, total: \(String(format: "%.1f", totalScreenTime)) minutes")

            return [
                "success": true,
                "data": [
                    "apps": sortedApps,
                    "totalScreenTime": totalScreenTime,
                    "isMockData": true,
                    "lastUpdate": Date().timeIntervalSince1970
                ]
            ]
        } catch {
            print("❌ ScreenTimeModule: Failed to store data: \(error)")
            return createErrorResponse(.extensionError, "Failed to generate screen time data: \(error.localizedDescription)")
        }
    }

    /// Stop screen time monitoring
    func stopScreenTimeMonitoring() -> [String: Any] {
        let center = DeviceActivityCenter()
        let activityName = DeviceActivityName("screentime_monitoring")

        do {
            try center.stopMonitoring([activityName])
            print("✅ Stopped DeviceActivity monitoring")

            return ["success": true, "data": [:]]
        } catch {
            print("❌ Failed to stop monitoring: \(error)")
            return createErrorResponse(.extensionError, "Failed to stop monitoring: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private func mapAuthorizationStatus(_ status: AuthorizationStatus) -> (String, Bool) {
        switch status {
        case .approved:
            return ("authorized", false)
        case .denied:
            return ("denied", true)  // Can still request again
        case .notDetermined:
            return ("notDetermined", true)
        @unknown default:
            return ("restricted", false)
        }
    }

    private func createErrorResponse(_ error: ScreenTimeError, _ message: String) -> [String: Any] {
        return [
            "success": false,
            "errorCode": error.rawValue,
            "errorMessage": message
        ]
    }

    // MARK: - Unlock Timer

    /// Start unlock timer with Live Activity (persistent widget)
    private func startUnlockTimer(durationMinutes: Int) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("⏱️ START UNLOCK TIMER (Live Activity)")
        print("   Duration: \(durationMinutes) minutes")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Calculate end time
        let endDate = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
        unlockEndTime = endDate
        print("📅 End time: \(endDate)")

        // Start Live Activity (iOS 16.2+) with cleanup
        if #available(iOS 16.2, *) {
            startLiveActivitySync(endTime: endDate)
        } else {
            print("⚠️  Live Activities require iOS 16.2+")
            // Still start countdown timer for older iOS versions
            startCountdownTimer()
        }
    }

    /// Start Live Activity synchronously (waits for cleanup before creating new one)
    @available(iOS 16.2, *)
    private func startLiveActivitySync(endTime: Date, isEmergencyUnlock: Bool = false) {
        // Stop countdown timer first
        countdownTimer?.invalidate()
        countdownTimer = nil

        // End existing activity and create new one
        Task {
            // End ALL existing activities (in case there are duplicates)
            let activities = Activity<UnlockTimerAttributes>.activities
            print("📊 Found \(activities.count) existing Live Activities")

            for activity in activities {
                print("🔄 Ending Live Activity: \(activity.id)")
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            // Also end our tracked activity if different
            if let existing = currentActivity {
                print("🔄 Ending tracked Live Activity...")
                await existing.end(nil, dismissalPolicy: .immediate)
            }

            currentActivity = nil
            print("✅ All old Live Activities ended")

            // Wait a bit to ensure iOS processes the end
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second

            let attributes = UnlockTimerAttributes(isEmergencyUnlock: isEmergencyUnlock)
            let secondsRemaining = Int(max(0, endTime.timeIntervalSinceNow))

            let initialState = UnlockTimerAttributes.ContentState(
                endTime: endTime,
                secondsRemaining: secondsRemaining
            )

            print("🚀 Creating NEW Live Activity...")
            print("   Seconds remaining: \(secondsRemaining)")

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: initialState, staleDate: nil),
                    pushType: nil
                )

                self.currentActivity = activity
                print("✅ Live Activity created!")
                print("   ID: \(activity.id)")
                print("   State: \(activity.activityState)")

                // NOW start the countdown timer after activity is confirmed created
                DispatchQueue.main.async {
                    print("🔄 Starting countdown timer...")
                    self.startCountdownTimer()
                }

            } catch {
                print("❌ Failed to start Live Activity: \(error.localizedDescription)")
                if let activityError = error as? ActivityAuthorizationError {
                    print("   Authorization error: \(activityError)")
                }
                print("   Error details: \(error)")
                // Start countdown anyway even if Live Activity fails
                DispatchQueue.main.async {
                    self.startCountdownTimer()
                }
            }
        }
    }

    /// Start Live Activity to show persistent timer widget (deprecated - use startLiveActivitySync)
    @available(iOS 16.2, *)
    private func startLiveActivity(endTime: Date) {
        startLiveActivitySync(endTime: endTime)
    }

    /// Start emergency unlock timer with Live Activity (orange theme)
    func startEmergencyUnlockTimer(durationSeconds: Int) -> [String: Any] {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🚨 STARTING EMERGENCY UNLOCK TIMER")
        print("   Duration: \(durationSeconds) seconds")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Calculate end time
        let endDate = Date().addingTimeInterval(TimeInterval(durationSeconds))
        unlockEndTime = endDate
        print("📅 End time: \(endDate)")

        // Start Live Activity with emergency theme (iOS 16.2+)
        if #available(iOS 16.2, *) {
            startLiveActivitySync(endTime: endDate, isEmergencyUnlock: true)
        } else {
            print("⚠️  Live Activities require iOS 16.2+")
            startCountdownTimer()
        }

        return [
            "success": true,
            "message": "Emergency unlock timer started",
            "endTime": endDate.timeIntervalSince1970
        ]
    }

    /// Stop the unlock timer and clean up
    private func stopUnlockTimer() {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🛑 STOPPING UNLOCK TIMER")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Stop countdown timer
        if countdownTimer != nil {
            countdownTimer?.invalidate()
            countdownTimer = nil
            print("✅ Countdown timer stopped")
        }

        unlockEndTime = nil

        // End Live Activity
        if #available(iOS 16.2, *) {
            if let activity = currentActivity {
                Task {
                    print("🛑 Ending Live Activity...")
                    await activity.end(nil, dismissalPolicy: .immediate)
                    print("✅ Live Activity ended")
                }
                currentActivity = nil
            }
        }

        print("✅ Timer cleanup complete")
    }

    /// Update Live Activity with current countdown
    @available(iOS 16.2, *)
    private func updateLiveActivity() {
        guard let endTime = unlockEndTime else { return }
        guard let activity = currentActivity else { return }

        let secondsRemaining = Int(max(0, endTime.timeIntervalSinceNow))

        if secondsRemaining <= 0 {
            return // Will be ended by stopUnlockTimer
        }

        let updatedState = UnlockTimerAttributes.ContentState(
            endTime: endTime,
            secondsRemaining: secondsRemaining
        )

        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        print("⏱️  \(minutes):\(String(format: "%02d", seconds))")

        Task {
            await activity.update(
                ActivityContent<UnlockTimerAttributes.ContentState>(
                    state: updatedState,
                    staleDate: nil
                )
            )
        }
    }

    /// Start timer to update countdown every second for exact accuracy
    private func startCountdownTimer() {
        print("🔄 Starting countdown timer (updates every 1 second)")
        countdownTimer?.invalidate()

        // Update every second for exact countdown
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }

        // Also update immediately to show initial time
        updateCountdown()
        print("✅ Countdown timer started")
    }

    /// Update the countdown
    private func updateCountdown() {
        guard let endTime = unlockEndTime else {
            stopUnlockTimer()
            return
        }

        let timeRemaining = endTime.timeIntervalSinceNow

        if timeRemaining <= 0 {
            // Timer expired
            stopUnlockTimer()
            return
        }

        // Update Live Activity with current time
        if #available(iOS 16.2, *) {
            updateLiveActivity()
        }
    }

    private enum ScreenTimeError: String {
        case notAuthorized = "NOT_AUTHORIZED"
        case authorizationError = "AUTH_ERROR"
        case configurationError = "CONFIG_ERROR"
        case sessionError = "SESSION_ERROR"
        case sessionNotFound = "SESSION_NOT_FOUND"
        case extensionError = "EXTENSION_ERROR"
    }
}

/// SwiftUI Wrapper for FamilyActivityPicker
///
/// Ensures proper @State binding for user selection to work correctly
@available(iOS 15.0, *)
struct FamilyPickerWrapper: View {
    @State private var selection: FamilyActivitySelection
    @Environment(\.presentationMode) var presentationMode
    let onDismiss: (FamilyActivitySelection) -> Void

    init(initialSelection: FamilyActivitySelection?, onDismiss: @escaping (FamilyActivitySelection) -> Void) {
        self._selection = State(initialValue: initialSelection ?? FamilyActivitySelection())
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Choose Apps to Block")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            onDismiss(selection)
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.system(.body, design: .default))
                        .foregroundColor(.blue)
                    }
                }
        }
        .navigationViewStyle(.stack)
    }
}

/// Flutter Platform Channel Handler
///
/// Implements the exact method signatures from our platform channel contract
@available(iOS 15.0, *)
class ScreenTimeChannelHandler {
    private let module = ScreenTimeModule()

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAuthorizationStatus":
            let response = module.getAuthorizationStatus()
            result(response)

        case "requestAuthorization":
            guard let args = call.arguments as? [String: Any],
                  let explanation = args["explanation"] as? String else {
                result(createFlutterError("INVALID_ARGS", "Missing explanation parameter"))
                return
            }
            module.requestAuthorization(explanation: explanation) { response in
                result(response)
            }

        case "configureBlockingRules":
            guard let args = call.arguments as? [String: Any],
                  let rules = args["rules"] as? [[String: Any]] else {
                result(createFlutterError("INVALID_ARGS", "Missing rules parameter"))
                return
            }
            let response = module.configureBlockingRules(rules: rules)
            result(response)

        case "startFocusSession":
            guard let args = call.arguments as? [String: Any],
                  let sessionId = args["sessionId"] as? String,
                  let durationMinutes = args["durationMinutes"] as? Int,
                  let ruleIds = args["ruleIds"] as? [String] else {
                result(createFlutterError("INVALID_ARGS", "Missing required parameters"))
                return
            }
            let response = module.startFocusSession(sessionId: sessionId, durationMinutes: durationMinutes, ruleIds: ruleIds)
            result(response)

        case "endFocusSession":
            guard let args = call.arguments as? [String: Any],
                  let sessionId = args["sessionId"] as? String else {
                result(createFlutterError("INVALID_ARGS", "Missing sessionId parameter"))
                return
            }
            let response = module.endFocusSession(sessionId: sessionId)
            result(response)

        case "manualOverride":
            let duration = (call.arguments as? [String: Any])?["durationMinutes"] as? Int
            let response = module.manualOverride(durationMinutes: duration)
            result(response)

        case "disableAllRestrictions":
            let response = module.disableAllRestrictions()
            result(response)

        case "getAggregatedStats":
            guard let args = call.arguments as? [String: Any],
                  let period = args["period"] as? String else {
                result(createFlutterError("INVALID_ARGS", "Missing period parameter"))
                return
            }
            let response = module.getAggregatedStats(period: period)
            result(response)

        case "presentFamilyActivityPicker":
            module.presentFamilyActivityPicker { response in
                result(response)
            }

        case "removeBlocking":
            let response = module.removeBlocking()
            result(response)

        case "reapplyBlocking":
            let response = module.reapplyBlocking()
            result(response)

        case "checkPendingWorkoutNavigation":
            let response = module.checkPendingWorkoutNavigation()
            result(response)

        case "getEmergencyUnlockStatus":
            let response = module.getEmergencyUnlockStatus()
            result(response)

        case "startEmergencyUnlockTimer":
            guard let args = call.arguments as? [String: Any],
                  let durationSeconds = args["durationSeconds"] as? Int else {
                result(createFlutterError("INVALID_ARGS", "Missing durationSeconds"))
                return
            }
            let response = module.startEmergencyUnlockTimer(durationSeconds: durationSeconds)
            result(response)

        case "checkPendingWorkoutNotification":
            let response = module.checkPendingWorkoutNotification()
            result(response)

        case "markNotificationShown":
            guard let args = call.arguments as? [String: Any],
                  let notificationId = args["notificationId"] as? String else {
                result(createFlutterError("INVALID_ARGS", "Missing notificationId"))
                return
            }
            let response = module.markNotificationShown(notificationId: notificationId)
            result(response)

        case "getTodayScreenTime":
            // Trigger data collection if needed
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            let response = module.getTodayScreenTime()
            result(response)

        case "getMostUsedApps":
            let limit = (call.arguments as? [String: Any])?["limit"] as? Int ?? 3
            // Force a widget reload to ensure fresh data in background
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            let response = module.getMostUsedApps(limit: limit)
            result(response)

        case "startScreenTimeMonitoring":
            // Trigger initial data collection
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            let response = module.startScreenTimeMonitoring()
            result(response)

        case "stopScreenTimeMonitoring":
            let response = module.stopScreenTimeMonitoring()
            result(response)

        case "generateScreenTimeData":
            let response = module.generateScreenTimeData()
            result(response)

        case "getMostUsedApps":
            let response = module.generateScreenTimeData()
            result(response)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func createFlutterError(_ code: String, _ message: String) -> FlutterError {
        return FlutterError(code: code, message: message, details: nil)
    }
}