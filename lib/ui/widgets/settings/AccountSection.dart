import 'package:flutter/material.dart';
import 'SettingsSection.dart';

/// Account settings section
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Account',
      icon: Icons.person,
      children: [
        SettingsListTile(
          title: 'Name',
          subtitle: 'King E.',
          leadingIcon: Icons.person_outline,
          onTap: () {
            // TODO: Navigate to name editing screen
          },
        ),
        SettingsListTile(
          title: 'Email',
          subtitle: 'john.doe@example.com',
          leadingIcon: Icons.email_outlined,
          onTap: () {
            // TODO: Navigate to email editing screen
          },
        ),
        SettingsListTile(
          title: 'Fitness Level',
          subtitle: 'Intermediate',
          leadingIcon: Icons.fitness_center,
          onTap: () {
            // TODO: Navigate to fitness level selection
          },
        ),
        SettingsListTile(
          title: 'Goals',
          subtitle: 'Build strength, Lose weight',
          leadingIcon: Icons.flag_outlined,
          onTap: () {
            // TODO: Navigate to goals selection
          },
          showDivider: false,
        ),
      ],
    );
  }
}


