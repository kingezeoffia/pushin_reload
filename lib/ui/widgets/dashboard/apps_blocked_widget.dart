import 'package:flutter/material.dart';
import '../../theme/dashboard_design_tokens.dart';

/// Apps Blocked Widget - Shows blocked apps at the bottom of Home screen
///
/// Displays up to 5 blocked app icons in a row, grayed out and semi-transparent
/// as specified in the PRD for the LOCKED state.
class AppsBlockedWidget extends StatelessWidget {
  const AppsBlockedWidget({super.key});

  // Mock data - in production, this would come from the app controller
  static const List<BlockedApp> _mockBlockedApps = [
    BlockedApp(name: 'Instagram', icon: Icons.camera_alt),
    BlockedApp(name: 'TikTok', icon: Icons.music_note),
    BlockedApp(name: 'YouTube', icon: Icons.play_circle_filled),
  ];

  @override
  Widget build(BuildContext context) {
    final blockedApps = _mockBlockedApps; // Replace with real data

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: DashboardDesignTokens.cardGradient,
        borderRadius: BorderRadius.circular(DashboardDesignTokens.cardRadius),
        boxShadow: DashboardDesignTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with lock icon
          Row(
            children: [
              Icon(
                Icons.lock,
                color: DashboardDesignTokens.textSecondary.withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Apps Blocked',
                style: TextStyle(
                  color: DashboardDesignTokens.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Blocked apps row
          if (blockedApps.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: blockedApps.map((app) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _BlockedAppIcon(app: app),
                );
              }).toList(),
            )
          else
            // No apps blocked message
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: DashboardDesignTokens.textSecondary.withOpacity(0.4),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No apps blocked yet',
                    style: TextStyle(
                      color:
                          DashboardDesignTokens.textSecondary.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap here to set up app blocking',
                    style: TextStyle(
                      color: DashboardDesignTokens.accentGreen.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Description
          Center(
            child: Text(
              'Complete a workout to unlock your blocked apps',
              style: TextStyle(
                color: DashboardDesignTokens.textSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual blocked app icon
class _BlockedAppIcon extends StatelessWidget {
  final BlockedApp app;

  const _BlockedAppIcon({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: DashboardDesignTokens.cardBackground.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DashboardDesignTokens.textSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Icon(
        app.icon,
        color: DashboardDesignTokens.textSecondary.withOpacity(0.4),
        size: 28,
      ),
    );
  }
}

/// Data model for blocked apps
class BlockedApp {
  final String name;
  final IconData icon;

  const BlockedApp({
    required this.name,
    required this.icon,
  });
}



