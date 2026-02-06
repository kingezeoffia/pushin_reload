import DeviceActivity
import SwiftUI

/// Main entry point for the Device Activity Report extension.
/// This extension collects screen time usage data and writes it 
/// to the shared App Group for the main Flutter app to read.
@main
@available(iOS 16.0, *)
struct PushinReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // This scene runs periodically to collect today's screen time
        TodayReportScene()
        
        // This scene can be used for weekly summaries
        WeeklyReportScene()
    }
}
