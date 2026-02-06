import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation
import WidgetKit

@available(iOS 16.0, *)
class PushinActivityMonitor: DeviceActivityMonitor {
    
    let appGroupId = "group.com.pushin.reload"
    
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        // Called when monitoring interval starts (e.g., beginning of day)
        let store = UserDefaults(suiteName: appGroupId)
        store?.set(Date().timeIntervalSince1970, forKey: "screen_time_monitoring_started")
        store?.synchronize()
        
        // Trigger initial data collection
        collectScreenTimeData()
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        // Called when monitoring interval ends - this is where we trigger updates
        collectScreenTimeData()
    }
    
    private func collectScreenTimeData() {
        let store = UserDefaults(suiteName: appGroupId)
        
        // Data collection is handled by DeviceActivityReportExtension when the widget refreshes.
        // We trigger a widget reload here to force the report extension to run and update data.
        store?.set(Date().timeIntervalSince1970, forKey: "screen_time_collection_requested")
        store?.set(true, forKey: "should_collect_screen_time")
        store?.synchronize()
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        
        // Called when a specific event threshold is reached
        // We can use this for real-time updates if needed
    }
}
