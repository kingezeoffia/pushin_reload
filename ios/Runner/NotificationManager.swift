import Foundation
import UIKit

// Conditionally import UserNotifications for iOS 10+
#if canImport(UserNotifications)
import UserNotifications
#endif

// Import ActivityKit for Live Activities (iOS 16.1+)
#if canImport(ActivityKit)
import ActivityKit
#endif

/// PUSHIN Notification Manager
///
/// Handles local notifications for Screen Time shield workout reminders.
/// Manages permissions, scheduling, and response handling for workout notifications.
@available(iOS 10.0, *)
class NotificationManager: NSObject {

    // MARK: - Properties

    #if canImport(UserNotifications)
    private let notificationCenter = UNUserNotificationCenter.current()
    #else
    private let notificationCenter: AnyObject? = nil
    #endif
    private let appGroupSuiteName = "group.com.pushin.reload"
    private var monitoringTimer: Timer?
    private var isMonitoringActive = false
    private var countdownTimer: Timer?
    private var unlockEndTime: Date?

    // MARK: - Initialization

    override init() {
        super.init()
        notificationCenter.delegate = self
        setupNotificationCategories()
    }

    deinit {
        stopMonitoringShieldActions()
    }

    // MARK: - Permission Management

    /// Request notification permissions from user
    @available(iOS 10.0, *)
    func requestPermissions() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await notificationCenter.requestAuthorization(options: options)

            if granted {
                print("✅ Notification permissions granted")
                await UIApplication.shared.registerForRemoteNotifications()
            } else {
                print("❌ Notification permissions denied")
            }

            return granted
        } catch {
            print("❌ Error requesting notification permissions: \(error.localizedDescription)")
            return false
        }
    }

    /// Check current authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.notificationSettings().authorizationStatus
    }

    // MARK: - Notification Categories

    private func setupNotificationCategories() {
        // Start Workout action
        let startAction = UNNotificationAction(
            identifier: "START_WORKOUT",
            title: "Start Workout",
            options: .foreground
        )

        // Later action (dismisses notification)
        let laterAction = UNNotificationAction(
            identifier: "LATER",
            title: "Later",
            options: .destructive
        )

        // Workout reminder category
        let workoutCategory = UNNotificationCategory(
            identifier: "WORKOUT_REMINDER",
            actions: [startAction, laterAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        notificationCenter.setNotificationCategories([workoutCategory])
        print("📱 Notification categories configured")
    }

    // MARK: - Shield Action Monitoring

    /// Start monitoring App Group for shield action signals
    func startMonitoringShieldActions() {
        guard !isMonitoringActive else { return }

        isMonitoringActive = true
        print("👀 Started monitoring shield actions")

        // Check immediately for any pending actions
        checkForPendingShieldActions()

        // Set up periodic monitoring (every 2 seconds when app is active)
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { [weak self] _ in
            self?.checkForPendingShieldActions()
        }
    }

    /// Stop monitoring shield actions
    func stopMonitoringShieldActions() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        isMonitoringActive = false
        print("⏹️ Stopped monitoring shield actions")
    }

    /// Check App Group for pending shield actions and schedule notifications
    private func checkForPendingShieldActions() {
        guard let store = UserDefaults(suiteName: appGroupSuiteName) else {
            print("⚠️ Cannot access App Group for shield monitoring")
            return
        }

        // Check for pending notification
        guard let pendingId = store.string(forKey: "pending_notification_id") else {
            return // No pending notification
        }

        let expiresAt = store.double(forKey: "notification_expires_at")
        let now = Date().timeIntervalSince1970

        // Check if notification has expired
        if now > expiresAt {
            print("⏰ Pending notification expired: \(pendingId)")
            cleanupExpiredNotification(pendingId, store: store)
            return
        }

        // Check deduplication
        if !shouldScheduleNotification(pendingId, store: store) {
            return
        }

        // Schedule the notification
        if let notificationId = scheduleWorkoutNotification(withId: pendingId) {
            // Mark as scheduled to prevent duplicates
            store.set(notificationId, forKey: "last_scheduled_notification_id")
            store.set(now, forKey: "last_notification_time")
            store.synchronize()

            // Clear the pending flag
            store.removeObject(forKey: "pending_notification_id")
            store.synchronize()

            print("✅ Scheduled workout notification: \(notificationId)")
        }
    }

    /// Determine if we should schedule a notification (deduplication logic)
    private func shouldScheduleNotification(_ notificationId: String, store: UserDefaults) -> Bool {
        let lastScheduledId = store.string(forKey: "last_scheduled_notification_id")
        let lastNotificationTime = store.double(forKey: "last_notification_time")
        let now = Date().timeIntervalSince1970

        // Don't schedule if same ID already processed
        if notificationId == lastScheduledId {
            return false
        }

        // Throttle: max 1 notification per minute to prevent spam
        if now - lastNotificationTime < 60 {
            print("⏱️ Throttling notification - too soon since last one")
            return false
        }

        return true
    }

    /// Clean up expired pending notification
    private func cleanupExpiredNotification(_ notificationId: String, store: UserDefaults) {
        store.removeObject(forKey: "pending_notification_id")
        store.removeObject(forKey: "notification_expires_at")
        store.synchronize()
        print("🧹 Cleaned up expired notification: \(notificationId)")
    }

    // MARK: - Notification Scheduling

    /// Schedule workout notification with given ID
    func scheduleWorkoutNotification(withId notificationId: String) -> String? {
        let content = UNMutableNotificationContent()
        content.title = "Earn Screen Time 📱"
        content.body = "Complete a quick workout to unblock your apps"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.categoryIdentifier = "WORKOUT_REMINDER"
        content.threadIdentifier = "workout-reminder"

        // Add deep link and metadata
        content.userInfo = [
            "deepLink": "pushin://workout",
            "notificationId": notificationId,
            "source": "shield_action",
            "createdAt": Date().timeIntervalSince1970
        ]

        // Schedule immediately (no delay)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )

        do {
            try notificationCenter.add(request)
            print("📱 Scheduled workout notification: \(notificationId)")
            return notificationId
        } catch {
            print("❌ Failed to schedule notification: \(error.localizedDescription)")
            return nil
        }
    }

    /// Cancel pending notifications
    func cancelPendingNotifications() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["WORKOUT_REMINDER"])
        print("🗑️ Cancelled pending workout notifications")
    }

    /// Cancel specific notification by ID
    func cancelNotification(withId notificationId: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationId])
        print("🗑️ Cancelled notification: \(notificationId)")
    }

    // MARK: - Notification Response Handling

    /// Handle notification response (called by UNUserNotificationCenterDelegate)
    private func handleNotificationResponse(_ response: UNNotificationResponse) {
        let notificationId = response.notification.request.identifier
        let actionId = response.actionIdentifier

        print("📱 Handling notification response: \(notificationId), action: \(actionId)")

        // Clear the notification
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationId])

        // Reset badge count
        UIApplication.shared.applicationIconBadgeNumber = 0

        switch actionId {
        case "START_WORKOUT":
            // User tapped "Start Workout" action
            navigateToWorkoutScreen(source: "notification_action")
            trackNotificationInteraction(notificationId, action: "start_workout")

        case "LATER":
            // User tapped "Later" - just dismiss
            trackNotificationInteraction(notificationId, action: "dismissed")

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            navigateToWorkoutScreen(source: "notification_tap")
            trackNotificationInteraction(notificationId, action: "tapped")

        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            trackNotificationInteraction(notificationId, action: "dismissed")

        default:
            trackNotificationInteraction(notificationId, action: "unknown")
        }
    }

    // MARK: - Navigation

    /// Navigate to workout selection screen
    private func navigateToWorkoutScreen(source: String) {
        // Send navigation signal to Flutter via platform channel
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToWorkout"),
            object: nil,
            userInfo: ["source": source]
        )

        print("🧭 Navigation signal sent to workout screen (source: \(source))")
    }

    // MARK: - Analytics

    /// Track notification interactions for analytics
    private func trackNotificationInteraction(_ notificationId: String, action: String) {
        let eventData: [String: Any] = [
            "notificationId": notificationId,
            "action": action,
            "timestamp": Date().timeIntervalSince1970,
            "source": "shield_workout_reminder"
        ]

        // Store in App Group for analytics
        if let store = UserDefaults(suiteName: appGroupSuiteName) {
            store.set(eventData, forKey: "last_notification_interaction")
            store.synchronize()
        }

        print("📊 Tracked notification interaction: \(action)")
    }

    // MARK: - Lifecycle

    /// Called when app becomes active - resume monitoring
    func applicationDidBecomeActive() {
        startMonitoringShieldActions()
    }

    /// Called when app enters background - pause monitoring
    func applicationDidEnterBackground() {
        stopMonitoringShieldActions()
    }

    /// Called on app launch - check for pending notifications
    func applicationDidLaunch() {
        // Check for any pending notifications from before app was killed
        checkForPendingShieldActions()

        // Clean up expired delivered notifications
        cleanupExpiredDeliveredNotifications()
    }

    /// Clean up expired delivered notifications
    private func cleanupExpiredDeliveredNotifications() {
        notificationCenter.getDeliveredNotifications { notifications in
            let expiredNotifications = notifications.filter { notification in
                // Check if notification is older than 1 hour
                let createdAt = notification.request.content.userInfo["createdAt"] as? Double ?? 0
                let now = Date().timeIntervalSince1970
                return now - createdAt > 3600 // 1 hour
            }

            if !expiredNotifications.isEmpty {
                let identifiers = expiredNotifications.map { $0.request.identifier }
                self.notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
                print("🧹 Cleaned up \(expiredNotifications.count) expired delivered notifications")
            }
        }
    }

    // MARK: - Unlock Timer Notifications

    /// Start showing persistent unlock timer notification
    @available(iOS 16.1, *)
    func startUnlockTimer(durationMinutes: Int) {
        // Calculate end time
        unlockEndTime = Date().addingTimeInterval(TimeInterval(durationMinutes * 60))

        // Start Live Activity for Dynamic Island
        Task {
            await LiveActivityManager.shared.startUnlockTimer(durationMinutes: durationMinutes)
        }

        // Show persistent notification
        showUnlockTimerNotification(minutesRemaining: durationMinutes)

        // Start countdown timer to update notification every minute
        startCountdownTimer()

        print("⏱️ Started unlock timer: \(durationMinutes) minutes")
    }

    /// Stop the unlock timer and clean up
    @available(iOS 16.1, *)
    func stopUnlockTimer() {
        // Stop countdown timer
        countdownTimer?.invalidate()
        countdownTimer = nil
        unlockEndTime = nil

        // End Live Activity
        Task {
            await LiveActivityManager.shared.endActivity()
        }

        // Remove timer notification
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ["UNLOCK_TIMER"])

        print("⏱️ Stopped unlock timer")
    }

    /// Show or update the unlock timer notification
    private func showUnlockTimerNotification(minutesRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🔓 Apps Unlocked"
        content.body = minutesRemaining == 1
            ? "1 minute remaining"
            : "\(minutesRemaining) minutes remaining"
        content.sound = nil // Silent update
        content.categoryIdentifier = "UNLOCK_TIMER"
        content.threadIdentifier = "unlock-timer"
        content.interruptionLevel = .passive // Low priority

        // Add metadata
        content.userInfo = [
            "type": "unlock_timer",
            "minutesRemaining": minutesRemaining,
            "updatedAt": Date().timeIntervalSince1970
        ]

        // Use same identifier to update existing notification
        let request = UNNotificationRequest(
            identifier: "UNLOCK_TIMER",
            content: content,
            trigger: nil // Show immediately
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Failed to show unlock timer notification: \(error.localizedDescription)")
            }
        }
    }

    /// Start timer to update countdown every minute
    private func startCountdownTimer() {
        countdownTimer?.invalidate()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
    }

    /// Update the countdown notification
    private func updateCountdown() {
        guard let endTime = unlockEndTime else {
            stopUnlockTimerLegacy()
            return
        }

        let now = Date()
        let timeRemaining = endTime.timeIntervalSince(now)
        let minutesRemaining = Int(ceil(timeRemaining / 60.0))

        if minutesRemaining <= 0 {
            // Timer expired
            stopUnlockTimerLegacy()
            return
        }

        // Update notification
        showUnlockTimerNotification(minutesRemaining: minutesRemaining)
    }

    /// Legacy stop method for iOS < 16.1
    private func stopUnlockTimerLegacy() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        unlockEndTime = nil
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ["UNLOCK_TIMER"])
    }
}

// MARK: - UNUserNotificationCenterDelegate

@available(iOS 15.0, *)
extension NotificationManager: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotificationResponse(response)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        // User tapped notification settings button
        print("⚙️ User opened notification settings")
    }
}