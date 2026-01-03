import 'package:flutter/material.dart';
import 'SettingsSection.dart';

/// Support and help settings section
class SupportSection extends StatelessWidget {
  const SupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Support & Help',
      icon: Icons.help,
      accentColor: const Color(0xFFF59E0B), // Warning yellow
      children: [
        SettingsListTile(
          title: 'Help Center',
          subtitle: 'FAQs and tutorials',
          leadingIcon: Icons.help_center_outlined,
          onTap: () {
            // TODO: Navigate to help center
          },
        ),
        SettingsListTile(
          title: 'Contact Support',
          subtitle: 'Get help from our team',
          leadingIcon: Icons.support_agent,
          onTap: () {
            // TODO: Navigate to contact support
          },
        ),
        SettingsListTile(
          title: 'Report a Bug',
          subtitle: 'Help us improve the app',
          leadingIcon: Icons.bug_report_outlined,
          onTap: () {
            // TODO: Navigate to bug report form
          },
        ),
        SettingsListTile(
          title: 'Feature Request',
          subtitle: 'Suggest new features',
          leadingIcon: Icons.lightbulb_outlined,
          onTap: () {
            // TODO: Navigate to feature request form
          },
          showDivider: false,
        ),
      ],
    );
  }
}







