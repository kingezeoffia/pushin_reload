import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/dashboard_design_tokens.dart';

/// Apps Blocked Widget - Shows blocked apps at the bottom of Home screen
///
/// Displays up to 5 blocked app icons in a row, grayed out and semi-transparent
/// as specified in the PRD for the LOCKED state.
///
/// When emergency unlock is active, shows unlocked state with countdown timer.
class AppsBlockedWidget extends StatefulWidget {
  /// Whether emergency unlock is currently active
  final bool isEmergencyUnlockActive;

  /// Remaining seconds in the emergency unlock session
  final int emergencyUnlockTimeRemaining;

  const AppsBlockedWidget({
    super.key,
    this.isEmergencyUnlockActive = false,
    this.emergencyUnlockTimeRemaining = 0,
  });

  // Mock data - in production, this would come from the app controller
  static const List<BlockedApp> mockBlockedApps = [
    BlockedApp(name: 'Instagram', icon: Icons.camera_alt),
    BlockedApp(name: 'TikTok', icon: Icons.music_note),
    BlockedApp(name: 'YouTube', icon: Icons.play_circle_filled),
  ];

  @override
  State<AppsBlockedWidget> createState() => _AppsBlockedWidgetState();
}

class _AppsBlockedWidgetState extends State<AppsBlockedWidget> {
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.emergencyUnlockTimeRemaining;
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(AppsBlockedWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.emergencyUnlockTimeRemaining !=
        oldWidget.emergencyUnlockTimeRemaining) {
      _remainingSeconds = widget.emergencyUnlockTimeRemaining;
    }
    if (widget.isEmergencyUnlockActive != oldWidget.isEmergencyUnlockActive) {
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (widget.isEmergencyUnlockActive && _remainingSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remainingSeconds > 0) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          _timer?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final blockedApps = AppsBlockedWidget.mockBlockedApps;

    // Show emergency unlock state
    if (widget.isEmergencyUnlockActive && _remainingSeconds > 0) {
      return _buildEmergencyUnlockState(blockedApps);
    }

    // Show normal blocked state
    return _buildBlockedState(blockedApps);
  }

  Widget _buildEmergencyUnlockState(List<BlockedApp> blockedApps) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A3A2F), // Dark green tint
            const Color(0xFF0D1F17), // Darker green
          ],
        ),
        borderRadius: BorderRadius.circular(DashboardDesignTokens.cardRadius),
        border: Border.all(
          color: DashboardDesignTokens.accentGreen.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: DashboardDesignTokens.accentGreen.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with unlock icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: DashboardDesignTokens.accentGreen.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lock_open,
                  color: DashboardDesignTokens.accentGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Apps Unlocked',
                style: TextStyle(
                  color: DashboardDesignTokens.accentGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Emergency badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Emergency',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Timer display
          Center(
            child: Column(
              children: [
                Text(
                  'Time Remaining',
                  style: TextStyle(
                    color: DashboardDesignTokens.textSecondary.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: DashboardDesignTokens.accentGreen.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      color: DashboardDesignTokens.accentGreen,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Unlocked apps row (with green tint instead of gray)
          if (blockedApps.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: blockedApps.map((app) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _UnlockedAppIcon(app: app),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),

          // Description
          Center(
            child: Text(
              'Apps will lock again when timer expires',
              style: TextStyle(
                color: DashboardDesignTokens.textSecondary.withOpacity(0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedState(List<BlockedApp> blockedApps) {
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
                Icons.security,
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

/// Individual unlocked app icon (shown during emergency unlock)
class _UnlockedAppIcon extends StatelessWidget {
  final BlockedApp app;

  const _UnlockedAppIcon({required this.app});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: DashboardDesignTokens.accentGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DashboardDesignTokens.accentGreen.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Icon(
        app.icon,
        color: DashboardDesignTokens.accentGreen.withOpacity(0.9),
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
