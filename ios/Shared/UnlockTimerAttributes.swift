import Foundation
import ActivityKit

/// Live Activity attributes for unlock timer
/// This file must be added to both Runner and UnlockTimerWidget targets
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
