//
//  ShieldConfigurationExtension.swift
//  ShieldConfiguration
//
//  Created by King Ezeoffia on 05.01.26.
//

import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Shield Configuration Extension for PUSHIN
/// Customizes the iOS shield overlay with "Earn Screen Time" and "Emergency Unlock" buttons
class ShieldConfigurationExtension: ShieldConfigurationDataSource, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        print("🛡️ ShieldConfigurationExtension: beginRequest called")
    }

    override init() {
        super.init()
        print("🛡️ ShieldConfigurationExtension: Initialized and ready to configure shields")
    }

    // App Group for reading emergency unlock count
    private let appGroupSuiteName = "group.com.pushin.reload"
    private let maxDailyUnlocks = 3

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        print("🛡️ ShieldConfiguration: Creating shield for app: \(application.localizedDisplayName ?? "Unknown")")
        return createPushinShield(for: application.localizedDisplayName ?? "This App")
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return createPushinShield(for: application.localizedDisplayName ?? "This App")
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return createPushinShield(for: webDomain.domain ?? "This Website")
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return createPushinShield(for: webDomain.domain ?? "This Website")
    }

    /// Check if emergency unlock is enabled in main app settings
    private func isEmergencyUnlockEnabled() -> Bool {
        guard let store = UserDefaults(suiteName: appGroupSuiteName) else {
            print("🛡️ ShieldConfiguration: Cannot access app group UserDefaults, defaulting to enabled")
            return true // Default to enabled if can't access settings
        }

        // If the key doesn't exist, it means the setting hasn't been saved yet, default to enabled
        if !store.dictionaryRepresentation().keys.contains("emergency_unlock_enabled") {
            print("🛡️ ShieldConfiguration: Emergency unlock setting not found, defaulting to enabled")
            return true
        }

        let enabled = store.bool(forKey: "emergency_unlock_enabled")
        print("🛡️ ShieldConfiguration: Emergency unlock enabled: \(enabled)")
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

    /// Creates the custom PUSHIN shield with branded buttons
    private func createPushinShield(for itemName: String) -> ShieldConfiguration {
        // PUSHIN brand purple color
        let pushinPurple = UIColor(red: 138/255, green: 43/255, blue: 226/255, alpha: 1.0)

        // Check if emergency unlock is enabled
        let emergencyEnabled = isEmergencyUnlockEnabled()
        print("🛡️ Creating shield for \(itemName) - emergency unlock enabled: \(emergencyEnabled)")

        // Get remaining emergency unlocks (only if enabled)
        let remaining = emergencyEnabled ? getRemainingEmergencyUnlocks() : 0
        let emergencyButtonText = "Emergency Unlock \(remaining)/\(maxDailyUnlocks)"
        let emergencyButtonColor: UIColor = (emergencyEnabled && remaining > 0) ? .systemRed : .gray

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1.0),
            icon: UIImage(systemName: "lock.fill"),
            title: ShieldConfiguration.Label(
                text: "\(itemName) is locked",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Complete a Workout",
                color: UIColor(white: 0.6, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Unlock Apps",
                color: .black
            ),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: emergencyEnabled ? ShieldConfiguration.Label(
                text: emergencyButtonText,
                color: emergencyButtonColor
            ) : nil
        )
    }
}
