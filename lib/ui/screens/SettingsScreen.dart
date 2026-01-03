import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/pushin_theme.dart';
import '../widgets/settings/settings_greeting_card.dart';
import '../widgets/settings/AccountSection.dart';
import '../widgets/settings/NotificationsSection.dart';
import '../widgets/settings/ThemesSection.dart';
import '../widgets/settings/PrivacySection.dart';
import '../widgets/settings/SupportSection.dart';
import '../../state/auth_state_provider.dart';

/// Settings screen with organized sections for app personalization
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthStateProvider>();
    final userName = authState.currentUser?.name ?? 'User';

    return Container(
      decoration: const BoxDecoration(
        gradient: PushinTheme.surfaceGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(PushinTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings Greeting Card
              SettingsGreetingCard(userName: userName),

              SizedBox(height: PushinTheme.spacingXl),

              // Header
              _buildHeader(),

              SizedBox(height: PushinTheme.spacingXl),

              // Settings sections
              const AccountSection(),

              SizedBox(height: PushinTheme.spacingLg),

              const NotificationsSection(),

              SizedBox(height: PushinTheme.spacingLg),

              const ThemesSection(),

              SizedBox(height: PushinTheme.spacingLg),

              const PrivacySection(),

              SizedBox(height: PushinTheme.spacingLg),

              const SupportSection(),

              SizedBox(height: PushinTheme.spacingXl),

              // App version and logout
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Settings',
          style: PushinTheme.headline2,
        ),
        SizedBox(height: PushinTheme.spacingXs),
        Text(
          'Personalize your app experience',
          style: PushinTheme.body2,
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: Color(0xFF334155)), // Slate 700
        SizedBox(height: PushinTheme.spacingMd),

        // App version
        Center(
          child: Text(
            'Pushin v1.0.0',
            style: PushinTheme.caption.copyWith(
              color: PushinTheme.textTertiary,
            ),
          ),
        ),

        SizedBox(height: PushinTheme.spacingMd),

        // Logout button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              // TODO: Implement logout functionality
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: PushinTheme.errorRed,
              side: const BorderSide(color: Color(0xFFEF4444)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
              ),
            ),
            child: Text(
              'Logout',
              style: PushinTheme.buttonText.copyWith(
                color: PushinTheme.errorRed,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
