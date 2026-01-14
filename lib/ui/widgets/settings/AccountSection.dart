import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'SettingsSection.dart';
import 'package:pushin_reload/ui/screens/settings/EditNameScreen.dart';
import 'package:pushin_reload/ui/screens/settings/EditEmailScreen.dart';
import 'package:pushin_reload/ui/screens/settings/ChangePasswordScreen.dart';
import 'package:pushin_reload/state/auth_state_provider.dart';

/// Account settings section
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthStateProvider>(context);
    final user = authState.currentUser;

    return SettingsSection(
      title: 'Account',
      icon: Icons.person,
      children: [
        SettingsListTile(
          title: 'Name',
          subtitle: user?.name ?? 'Not set',
          leadingIcon: Icons.person_outline,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditNameScreen()),
            );
          },
        ),
        SettingsListTile(
          title: 'Email',
          subtitle: user?.email ?? 'Not set',
          leadingIcon: Icons.email_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditEmailScreen()),
            );
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
          title: 'Password',
          subtitle: 'Change your password',
          leadingIcon: Icons.lock_outline,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen()),
            );
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
