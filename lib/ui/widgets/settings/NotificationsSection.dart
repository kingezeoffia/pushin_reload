import 'package:flutter/material.dart';
import '../../theme/pushin_theme.dart';
import 'SettingsSection.dart';

/// Notifications settings section
class NotificationsSection extends StatefulWidget {
  const NotificationsSection({super.key});

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> {
  bool _streakReminders = true;
  bool _workoutReminders = true;
  bool _dailySummary = false;
  bool _achievementAlerts = true;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Notifications',
      icon: Icons.notifications,
      children: [
        // Streak reminders
        _buildSwitchTile(
          title: 'Streak Reminders',
          subtitle: 'Get notified when your streak is about to break',
          value: _streakReminders,
          onChanged: (value) => setState(() => _streakReminders = value),
          icon: Icons.local_fire_department,
        ),

        // Workout reminders
        _buildSwitchTile(
          title: 'Workout Reminders',
          subtitle: 'Daily reminders to complete your workouts',
          value: _workoutReminders,
          onChanged: (value) => setState(() => _workoutReminders = value),
          icon: Icons.fitness_center,
        ),

        // Daily summary
        _buildSwitchTile(
          title: 'Daily Summary',
          subtitle: 'End-of-day summary of your progress',
          value: _dailySummary,
          onChanged: (value) => setState(() => _dailySummary = value),
          icon: Icons.today,
        ),

        // Achievement alerts
        _buildSwitchTile(
          title: 'Achievement Alerts',
          subtitle: 'Celebrate when you reach milestones',
          value: _achievementAlerts,
          onChanged: (value) => setState(() => _achievementAlerts = value),
          icon: Icons.emoji_events,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: PushinTheme.spacingMd,
            vertical: PushinTheme.spacingSm,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: PushinTheme.primaryBlue,
                size: 20,
              ),
              SizedBox(width: PushinTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: PushinTheme.body1.copyWith(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: PushinTheme.spacingXs),
                    Text(
                      subtitle,
                      style: PushinTheme.caption.copyWith(
                        color: PushinTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: PushinTheme.primaryBlue,
              ),
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Divider(height: 1, color: Color(0xFF334155)), // Slate 700
          ),
      ],
    );
  }
}







