import DeviceActivity
import ExtensionKit
import ManagedSettings
import SwiftUI

@available(iOS 16.0, *)
@main
struct PushinReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReportScene()
    }
}

// MARK: - Configuration (must be Equatable)
@available(iOS 16.0, *)
struct ActivityReportConfiguration: Equatable {
    var totalMinutes: Double = 0
}

// MARK: - Scene
@available(iOS 16.0, *)
struct TotalActivityReportScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "Total Activity")

    let content: (ActivityReportConfiguration) -> ActivityReportView = { config in
        ActivityReportView(config: config)
    }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReportConfiguration {
        var config = ActivityReportConfiguration()

        let appGroupId = "group.com.pushin.reload"
        let store = UserDefaults(suiteName: appGroupId)

        var totalMinutes: Double = 0
        var appUsageDictList: [[String: Any]] = []

        for await activityData in data {
            for await segment in activityData.activitySegments {
                for await categoryActivity in segment.categories {
                    totalMinutes += categoryActivity.totalActivityDuration / 60.0

                    for await appActivity in categoryActivity.applications {
                        let name = appActivity.application.localizedDisplayName ?? "Unknown"
                        let bundleId = appActivity.application.bundleIdentifier ?? "unknown"
                        let minutes = appActivity.totalActivityDuration / 60.0

                        if minutes > 0 {
                            appUsageDictList.append([
                                "name": name,
                                "usageMinutes": minutes,
                                "bundleId": bundleId
                            ])
                        }
                    }
                }
            }
        }

        appUsageDictList.sort { ($0["usageMinutes"] as? Double ?? 0) > ($1["usageMinutes"] as? Double ?? 0) }

        store?.set(totalMinutes, forKey: "screen_time_total_minutes_today")
        // CANARY LOGGING: Write debug timestamp to verify extension is running
        let debugTimestamp = Date().timeIntervalSince1970
        store?.set(debugTimestamp, forKey: "DEBUG_LAST_RUN")
        print("Extension running at: \(debugTimestamp)")
        
        store?.set(Date().timeIntervalSince1970, forKey: "screen_time_last_update")

        if let jsonData = try? JSONSerialization.data(withJSONObject: appUsageDictList, options: []) {
            store?.set(jsonData, forKey: "most_used_apps_today")
        }
        store?.synchronize()

        config.totalMinutes = totalMinutes
        return config
    }
}

// MARK: - View
@available(iOS 16.0, *)
struct ActivityReportView: View {
    let config: ActivityReportConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screen Time")
                .font(.headline)
            Text(String(format: "%.0f minutes today", config.totalMinutes))
                .font(.title2)
        }
        .padding()
    }
}
