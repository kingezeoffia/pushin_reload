//
//  ShieldActionExtension.swift
//  ShieldAction
//
//  Created by King Ezeoffia on 05.01.26.
//

import Foundation
import ManagedSettings
import UIKit
import UserNotifications

/// Shield Action Extension for PUSHIN
/// Handles button taps on the shield overlay:
/// - Primary: "Earn Screen Time" → Opens PUSHIN app to workout screen
/// - Secondary: "Emergency Unlock X/3" → Uses one emergency unlock if available
class ShieldActionExtension: ShieldActionDelegate, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        print("🛡️ ShieldActionExtension: beginRequest called")
    }

    override init() {
        super.init()
        print("🛡️ ShieldActionExtension: Initialized and ready")
    }

    // App Group for communication with main app
    private let appGroupSuiteName = "group.com.pushin.reload"
    private let maxDailyUnlocks = 3

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handleAction(action, completionHandler: completionHandler)
    }

    private func handleAction(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        print("🛡️ Shield Action triggered: \(action)")
        switch action {
        case .primaryButtonPressed:
            // "Earn Screen Time" - signal main app for workout
            print("🏋️ Primary button pressed - signaling main app for workout")
            signalMainAppForWorkout()
            // Keep shield visible - notification will guide user to workout
            print("🛡️ Keeping shield active - notification sent")
            completionHandler(.none)

        case .secondaryButtonPressed:
            // "Emergency Unlock" - use one unlock if available AND if enabled
            // Note: This should only be called if emergency unlock is enabled (button should be hidden otherwise)
            if performEmergencyUnlock() {
                // Emergency unlock successful - shields are cleared, keep app open
                completionHandler(.none)
            } else {
                // No unlocks remaining - don't close, keep shield up
                completionHandler(.none)
            }

        @unknown default:
            completionHandler(.none)
        }
    }

    /// Signal main app to schedule workout notification
    private func signalMainAppForWorkout() {
        guard let store = UserDefaults(suiteName: appGroupSuiteName) else {
            print("⚠️ App group not accessible from extension - entitlements may be missing")
            return
        }

        let notificationId = UUID().uuidString
        let now = Date().timeIntervalSince1970
        let expiresAt = now + 300 // 5 minutes

        store.set(notificationId, forKey: "pending_notification_id")
        store.set(now, forKey: "shield_action_timestamp")
        store.set(expiresAt, forKey: "notification_expires_at")
        store.set(true, forKey: "should_show_workout") // Keep for backward compatibility
        store.synchronize()

        print("📱 Signaled main app for workout (ID: \(notificationId))")

        // BMAD METHOD: Try EVERYTHING to show notification
        scheduleNotificationAggressively(notificationId: notificationId)
    }

    /// BMAD METHOD: Schedule notification with every possible configuration
    private func scheduleNotificationAggressively(notificationId: String) {
        let center = UNUserNotificationCenter.current()

        print("🚀 BMAD: Attempting aggressive notification scheduling...")

        // Check current authorization status
        center.getNotificationSettings { settings in
            print("🔔 Notification auth status: \(settings.authorizationStatus.rawValue)")
            print("🔔 Alert setting: \(settings.alertSetting.rawValue)")
            print("🔔 Sound setting: \(settings.soundSetting.rawValue)")

            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                print("✅ Authorized - proceeding with notification")

                // Create notification content with MAXIMUM priority
                let content = UNMutableNotificationContent()
                content.title = "🏋️ Earn Screen Time"
                content.body = "Tap to start your workout and unlock apps"
                content.sound = .defaultCritical // CRITICAL sound for maximum attention
                content.badge = 1
                content.interruptionLevel = .critical // iOS 15+ critical interruption
                content.categoryIdentifier = "WORKOUT_REMINDER"
                content.userInfo = [
                    "deepLink": "pushin://workout",
                    "notificationId": notificationId,
                    "source": "shield_bmad"
                ]

                // Try immediate trigger (0.1 seconds)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

                let request = UNNotificationRequest(
                    identifier: "pushin_workout_\(notificationId)",
                    content: content,
                    trigger: trigger
                )

                center.add(request) { error in
                    if let error = error {
                        print("❌ BMAD notification failed: \(error.localizedDescription)")

                        // FALLBACK: Try without trigger (immediate)
                        self.tryImmediateNotification(content: content, center: center)
                    } else {
                        print("✅ BMAD notification scheduled successfully!")
                    }
                }
            } else {
                print("❌ Not authorized for notifications - requesting permission")
                center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, error in
                    if granted {
                        print("✅ Permission granted - retrying notification")
                        self.scheduleNotificationAggressively(notificationId: notificationId)
                    } else {
                        print("❌ Permission denied: \(error?.localizedDescription ?? "unknown")")
                    }
                }
            }
        }
    }

    /// FALLBACK: Try immediate notification without trigger
    private func tryImmediateNotification(content: UNMutableNotificationContent, center: UNUserNotificationCenter) {
        print("🔄 BMAD FALLBACK: Trying immediate notification without trigger")

        let request = UNNotificationRequest(
            identifier: "pushin_immediate_\(UUID().uuidString)",
            content: content,
            trigger: nil  // nil = show immediately
        )

        center.add(request) { error in
            if let error = error {
                print("❌ BMAD fallback also failed: \(error.localizedDescription)")
            } else {
                print("✅ BMAD fallback succeeded!")
            }
        }
    }

    /// Check if emergency unlock is enabled in main app settings
    private func isEmergencyUnlockEnabled() -> Bool {
        guard let store = UserDefaults(suiteName: appGroupSuiteName) else {
            print("🛡️ Cannot access app group UserDefaults, defaulting to enabled")
            return true // Default to enabled if can't access settings
        }

        // If the key doesn't exist, it means the setting hasn't been saved yet, default to enabled
        if !store.dictionaryRepresentation().keys.contains("emergency_unlock_enabled") {
            print("🛡️ Emergency unlock setting not found, defaulting to enabled")
            return true
        }

        let enabled = store.bool(forKey: "emergency_unlock_enabled")
        print("🛡️ Emergency unlock enabled: \(enabled)")
        return enabled
    }

    /// Get remaining emergency unlocks for today
    private func getRemainingEmergencyUnlocks() -> Int {
        guard let store = UserDefaults(suiteName: appGroupSuiteName) else {
            return maxDailyUnlocks
        }

        // Check if we need to reset for a new day
        let lastResetDate = store.object(forKey: "emergency_unlock_reset_date") as? Date
        let today = Calendar.current.startOfDay(for: Date())

        if lastResetDate == nil || Calendar.current.startOfDay(for: lastResetDate!) < today {
            // New day - reset the count
            store.set(0, forKey: "emergency_unlocks_used_today")
            store.set(today, forKey: "emergency_unlock_reset_date")
            store.synchronize()
            return maxDailyUnlocks
        }

        let usedToday = store.integer(forKey: "emergency_unlocks_used_today")
        return max(0, maxDailyUnlocks - usedToday)
    }

    /// Emergency unlock - clears all shields if unlocks available
    /// Returns true if unlock was performed, false if no unlocks remaining
    private func performEmergencyUnlock() -> Bool {
        guard let store = UserDefaults(suiteName: appGroupSuiteName) else {
            return false
        }

        // Check remaining unlocks
        let remaining = getRemainingEmergencyUnlocks()
        if remaining <= 0 {
            print("❌ No emergency unlocks remaining today")
            return false
        }

        // Use one unlock
        let usedToday = store.integer(forKey: "emergency_unlocks_used_today")
        let unlockDurationMinutes = store.integer(forKey: "emergency_unlock_minutes")
        let durationMinutes = unlockDurationMinutes > 0 ? unlockDurationMinutes : 30 // Default 30 min
        let expiryTimestamp = Date().timeIntervalSince1970 + Double(durationMinutes * 60)

        store.set(usedToday + 1, forKey: "emergency_unlocks_used_today")
        store.set(true, forKey: "emergency_unlock_requested")
        store.set(Date().timeIntervalSince1970, forKey: "emergency_unlock_timestamp")
        store.set(expiryTimestamp, forKey: "emergency_unlock_expiry")
        store.set(true, forKey: "emergency_unlock_active")
        store.synchronize()

        // Clear all shields via ManagedSettingsStore
        let managedSettingsStore = ManagedSettingsStore()
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = .none

        print("🚨 Emergency unlock used - \(remaining - 1) remaining today")
        return true
    }
}
