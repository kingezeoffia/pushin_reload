import 'package:flutter/material.dart';
import 'SettingsSection.dart';

/// Privacy and legal settings section
class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Privacy & Legal',
      icon: Icons.shield,
      accentColor: const Color(0xFF10B981), // Success green
      children: [
        SettingsListTile(
          title: 'Privacy Policy',
          subtitle: 'How we protect your data',
          leadingIcon: Icons.privacy_tip_outlined,
          onTap: () {
            // TODO: Navigate to privacy policy
          },
        ),
        SettingsListTile(
          title: 'Terms of Service',
          subtitle: 'Our terms and conditions',
          leadingIcon: Icons.description_outlined,
          onTap: () {
            // TODO: Navigate to terms of service
          },
        ),
        SettingsListTile(
          title: 'Data Usage',
          subtitle: 'How we use your workout data',
          leadingIcon: Icons.analytics_outlined,
          onTap: () {
            // TODO: Navigate to data usage info
          },
        ),
        SettingsListTile(
          title: 'App Permissions',
          subtitle: 'Manage app access permissions',
          leadingIcon: Icons.admin_panel_settings_outlined,
          onTap: () {
            // TODO: Navigate to permissions settings
          },
          showDivider: false,
        ),
      ],
    );
  }
}







