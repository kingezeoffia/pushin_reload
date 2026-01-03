import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftUI
import UIKit

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

    // App Group for persisting selections
    private let appGroupSuiteName = "group.dev.pushin.app"
    private let selectionKey = "family_activity_selection"

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
                    // Configure application blocking
                    do {
                        managedSettingsStore.shield.applications?.formUnion(validTokens)
                        configuredRules.append(ruleId)
                    } catch let error as NSError {
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
            // In production, this would properly deserialize and validate tokens
            // For now, we assume they're valid if they exist
            if !tokenString.isEmpty {
                // Placeholder: Create a dummy token for testing
                // Real implementation would deserialize from stored tokens
                continue
            }
        }

        return validTokens
    }

    // MARK: - Focus Sessions

    /// Start a focus session with scheduled blocking
    func startFocusSession(sessionId: String, durationMinutes: Int, ruleIds: [String]) -> [String: Any] {
        guard authorizationCenter.authorizationStatus == .approved else {
            return createErrorResponse(.notAuthorized, "Screen Time authorization required")
        }

        // 🚨 HARD VALIDATION TEST — Block all application categories using ManagedSettings
        // This is temporary code to validate ManagedSettings functionality
        // Note: .applications = .all may not be available in current SDK configuration
        // DO NOT USE IN PRODUCTION - will be removed after validation
        let store = ManagedSettingsStore()

        store.shield.applicationCategories = .all(except: Set())
        print("🚨 HARD SHIELD ENABLED — ALL APP CATEGORIES BLOCKED")

        let now = Date()
        let endTime = now.addingTimeInterval(TimeInterval(durationMinutes * 60))

        // Create DeviceActivity schedule for this session
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: nowComponents.hour, minute: nowComponents.minute),
            intervalEnd: DateComponents(hour: endComponents.hour, minute: endComponents.minute),
            repeats: false
        )

        do {
            // Start the device activity monitoring
            let activityName = DeviceActivityName(sessionId)
            try DeviceActivityCenter().startMonitoring(activityName, during: schedule)

            activeSessions[sessionId] = schedule

            return [
                "success": true,
                "data": [
                    "sessionId": sessionId,
                    "startTime": now.ISO8601Format(),
                    "endTime": endTime.ISO8601Format(),
                    "activeRuleIds": ruleIds
                ]
            ]
        } catch {
            return createErrorResponse(.sessionError, "Failed to start focus session: \(error.localizedDescription)")
        }
    }

    /// End an active focus session
    func endFocusSession(sessionId: String) -> [String: Any] {
        guard let schedule = activeSessions[sessionId] else {
            return createErrorResponse(.sessionNotFound, "Focus session not found")
        }

        do {
            // Stop the device activity monitoring
            try DeviceActivityCenter().stopMonitoring()

            activeSessions.removeValue(forKey: sessionId)

            // Clear any active shields
            managedSettingsStore.shield.applications = nil
            managedSettingsStore.shield.applicationCategories = .none
            print("✅ ManagedSettings HARD SHIELD DISABLED - Session ended")

            return ["success": true, "data": [:]]
        } catch {
            return createErrorResponse(.sessionError, "Failed to end focus session: \(error.localizedDescription)")
        }
    }

    // MARK: - Manual Override & Emergency Controls

    /// Allow manual override of current restrictions
    func manualOverride() -> [String: Any] {
        // Clear all current shields
        managedSettingsStore.shield.applications = nil
        managedSettingsStore.shield.applicationCategories = .none

        // Stop any active monitoring
        try? DeviceActivityCenter().stopMonitoring()
        activeSessions.removeAll()

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

    // MARK: - Selection Persistence

    /// Load persisted FamilyActivitySelection from App Group
    private func loadPersistedSelection() -> FamilyActivitySelection? {
        guard let store = UserDefaults(suiteName: appGroupSuiteName),
              let data = store.data(forKey: selectionKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        } catch {
            print("Failed to decode persisted selection: \(error)")
            return nil
        }
    }

    /// Persist FamilyActivitySelection to App Group
    private func persistSelection(_ selection: FamilyActivitySelection) {
        guard let store = UserDefaults(suiteName: appGroupSuiteName) else {
            print("App Group not available for persistence")
            return
        }

        do {
            let data = try JSONEncoder().encode(selection)
            store.set(data, forKey: selectionKey)
        } catch {
            print("Failed to encode selection for persistence: \(error)")
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
            let response = module.manualOverride()
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

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func createFlutterError(_ code: String, _ message: String) -> FlutterError {
        return FlutterError(code: code, message: message, details: nil)
    }
}