//
//  UnlockTimerWidgetLiveActivity.swift
//  UnlockTimerWidget
//
//  Created by King Ezeoffia on 06.01.26.
//

import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity widget for unlock timer
@available(iOS 16.1, *)
struct UnlockTimerWidgetLiveActivity: Widget {
    // Green theme colors (regular unlock)
    private let greenPrimary = Color(hex: "10B981")
    private let greenSecondary = Color(hex: "34D399")
    private let greenDark = Color(hex: "059669")

    // Orange theme colors (emergency unlock)
    private let orangePrimary = Color(hex: "FFB347")
    private let orangeSecondary = Color(hex: "FF8C00")
    private let orangeDark = Color(hex: "FF6B00")

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: UnlockTimerAttributes.self) { context in
            let isEmergency = context.attributes.isEmergencyUnlock
            let primaryColor = isEmergency ? orangePrimary : greenPrimary
            let secondaryColor = isEmergency ? orangeSecondary : greenSecondary
            let darkColor = isEmergency ? orangeDark : greenDark
            let title = isEmergency ? "Emergency Unlock" : "Apps Unlocked"

            // Lock Screen / Banner UI
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: isEmergency ? "exclamationmark.lock.fill" : "lock.open.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Time remaining")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color.white.opacity(0.7))
                }

                Spacer()

                // Timer
                Text(formatTime(context.state.secondsRemaining))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [primaryColor, darkColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )

        } dynamicIsland: { context in
            let isEmergency = context.attributes.isEmergencyUnlock
            let primaryColor = isEmergency ? orangePrimary : greenPrimary
            let secondaryColor = isEmergency ? orangeSecondary : greenSecondary
            let subtitleText = isEmergency ? "Emergency" : "Unlocked"
            let bottomText = isEmergency ? "Emergency unlock active" : "Apps unlocked temporarily"

            return DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [primaryColor, secondaryColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)

                            Image(systemName: isEmergency ? "exclamationmark.lock.fill" : "lock.open.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apps")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text(subtitleText)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(secondaryColor)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(context.state.secondsRemaining))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(secondaryColor)
                            .monospacedDigit()
                        Text("remaining")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: isEmergency ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(primaryColor)

                        Text(bottomText)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .padding(.top, 8)
                }

            } compactLeading: {
                Image(systemName: isEmergency ? "exclamationmark.lock.fill" : "lock.open.fill")
                    .foregroundColor(primaryColor)
            } compactTrailing: {
                Text(formatTimeCompact(context.state.secondsRemaining))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryColor)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: isEmergency ? "exclamationmark.lock.fill" : "lock.open.fill")
                    .foregroundColor(primaryColor)
            }
        }
    }

    // Format time as MM:SS
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // Format time compactly (e.g., "4m" or "0:45")
    private func formatTimeCompact(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 1 {
            return "\(minutes)m"
        } else {
            return "0:\(String(format: "%02d", seconds))"
        }
    }
}

// Helper to convert hex color strings to Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
