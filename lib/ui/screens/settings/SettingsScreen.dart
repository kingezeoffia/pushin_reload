import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../services/ShieldNotificationMonitor.dart';
import '../../theme/pushin_theme.dart';
import 'ManageAppsScreen.dart';
import 'EmergencyUnlockSettingsScreen.dart';

/// Settings Screen - User configuration and account management
///
/// Design: Modern, sleek aesthetic matching onboarding screens
/// - Clean typography hierarchy
/// - Minimal containers and shadows
/// - Generous whitespace
/// - Subtle visual elements
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A0F),
              Color(0xFF0F0F18),
              Color(0xFF12121D),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Clean Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customize your experience',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Plan Card (KEPT EXACTLY AS IS)
                    Consumer<PushinAppController>(
                      builder: (context, controller, _) {
                        return _PlanCard(
                          planTier: controller.planTier,
                          onUpgrade: () => Navigator.pushNamed(context, '/paywall'),
                        );
                      },
                    ),

                    const SizedBox(height: 36),

                    // App Blocking Section
                    const _SectionHeader(title: 'App Blocking'),
                    const SizedBox(height: 16),
                    _SettingsItem(
                      icon: Icons.block_rounded,
                      iconColor: const Color(0xFFFF6B6B),
                      title: 'Manage Blocked Apps',
                      subtitle: 'Choose which apps require workouts',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageAppsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 8),

                    Consumer<PushinAppController>(
                      builder: (context, controller, _) {
                        return _SettingsItem(
                          icon: Icons.timer_outlined,
                          iconColor: const Color(0xFFFFB347),
                          title: 'Emergency Unlock',
                          subtitle: controller.emergencyUnlockEnabled
                              ? '${controller.emergencyUnlockMinutes} minutes (${controller.emergencyUnlocksRemaining} remaining)'
                              : 'Disabled',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EmergencyUnlockSettingsScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Account Section
                    const _SectionHeader(title: 'Account'),
                    const SizedBox(height: 16),
                    _SettingsItem(
                      icon: Icons.person_outline_rounded,
                      iconColor: const Color(0xFF7C8CFF),
                      title: 'Profile',
                      subtitle: 'Edit your information',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Navigate to profile screen
                      },
                    ),

                    const SizedBox(height: 8),

                    _SettingsItem(
                      icon: Icons.fitness_center_rounded,
                      iconColor: const Color(0xFF4ADE80),
                      title: 'Fitness Level & Goals',
                      subtitle: 'Update your preferences',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Navigate to fitness preferences
                      },
                    ),

                    const SizedBox(height: 32),

                    // Support Section
                    const _SectionHeader(title: 'Support'),
                    const SizedBox(height: 16),
                    _SettingsItem(
                      icon: Icons.notifications_none_rounded,
                      iconColor: const Color(0xFF60A5FA),
                      title: 'Notifications',
                      subtitle: 'Manage reminders and alerts',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Navigate to notifications settings
                      },
                    ),

                    const SizedBox(height: 8),

                    _SettingsItem(
                      icon: Icons.help_outline_rounded,
                      iconColor: const Color(0xFF60A5FA),
                      title: 'Help & Support',
                      subtitle: 'Get help or contact us',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Navigate to help screen
                      },
                    ),

                    const SizedBox(height: 32),

                    // Debug Section
                    const _SectionHeader(title: 'Debug Tools'),
                    const SizedBox(height: 16),
                    if (Platform.isIOS) ...[
                      _SettingsItem(
                        icon: Icons.bug_report_outlined,
                        iconColor: const Color(0xFFFF9500),
                        title: 'Test Notification System',
                        subtitle: 'Verify notifications are working',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _testNotificationSystem(context);
                        },
                      ),
                      const SizedBox(height: 8),
                      _SettingsItem(
                        icon: Icons.refresh_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: 'Check for Pending Notifications',
                        subtitle: 'Manually check shield notifications',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _checkPendingNotifications(context);
                        },
                      ),
                      const SizedBox(height: 32),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Debug tools are only available on iOS',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Legal Section
                    const _SectionHeader(title: 'Legal'),
                    const SizedBox(height: 16),
                    _SettingsItem(
                      icon: Icons.shield_outlined,
                      iconColor: Colors.white.withOpacity(0.5),
                      title: 'Privacy Policy',
                      subtitle: 'View our privacy policy',
                      showChevron: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Open privacy policy
                      },
                    ),

                    const SizedBox(height: 8),

                    _SettingsItem(
                      icon: Icons.description_outlined,
                      iconColor: Colors.white.withOpacity(0.5),
                      title: 'Terms of Service',
                      subtitle: 'View terms and conditions',
                      showChevron: true,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Open terms of service
                      },
                    ),

                    const SizedBox(height: 40),

                    // Log Out Button - Sleek minimal design
                    _LogOutButton(
                      onTap: () => _showLogoutDialog(context),
                    ),

                    const SizedBox(height: 24),

                    // App Version - Clean footer
                    Center(
                      child: Text(
                        'PUSHIN\' v1.0.0',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.25),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _testNotificationSystem(BuildContext context) async {
    final monitor = ShieldNotificationMonitor();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.science_outlined,
                size: 48,
                color: Color(0xFFFF9500),
              ),
              const SizedBox(height: 16),
              const Text(
                'Running Notification Test',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Check the console logs for detailed results',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _DialogButton(
                label: 'Close',
                onTap: () => Navigator.pop(context),
                isPrimary: true,
                primaryColor: const Color(0xFFFF9500),
              ),
            ],
          ),
        ),
      ),
    );

    // Run the test
    await monitor.testNotificationSystem();
  }

  void _checkPendingNotifications(BuildContext context) async {
    final monitor = ShieldNotificationMonitor();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Checking for pending notifications...'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );

    // Manually trigger a check
    await monitor.manualCheckForNotifications();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Check complete. See console for details.'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with subtle glow
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 30,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Log Out?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to log out? Your progress will be saved.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.55),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialogButton(
                      label: 'Log Out',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/onboarding',
                          (route) => false,
                        );
                      },
                      isPrimary: true,
                      primaryColor: const Color(0xFFFF6B6B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sleek Dialog Button
class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? primaryColor;

  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
    this.primaryColor,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor ?? Colors.white;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: widget.isPrimary
              ? (color.withOpacity(_isPressed ? 0.85 : 1.0))
              : Colors.white.withOpacity(_isPressed ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.isPrimary
                  ? const Color(0xFF1A1A24)
                  : Colors.white.withOpacity(0.8),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleek Section Header - Minimal, elegant text styling
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.35),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Modern Settings Item - Clean, minimal card design
class _SettingsItem extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(_isPressed ? 0.12 : 0.06),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Icon container - subtle, elegant
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                widget.icon,
                color: widget.iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.45),
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron - subtle
            if (widget.showChevron)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.25),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

/// Sleek Log Out Button - Minimal, text-focused design
class _LogOutButton extends StatefulWidget {
  final VoidCallback onTap;

  const _LogOutButton({required this.onTap});

  @override
  State<_LogOutButton> createState() => _LogOutButtonState();
}

class _LogOutButtonState extends State<_LogOutButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _isPressed
              ? const Color(0xFFFF6B6B).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFFF6B6B).withOpacity(_isPressed ? 0.4 : 0.25),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            'Log Out',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFF6B6B).withOpacity(_isPressed ? 1.0 : 0.9),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Plan Card Widget
class _PlanCard extends StatelessWidget {
  final String planTier;
  final VoidCallback onUpgrade;

  const _PlanCard({
    required this.planTier,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = planTier == 'free';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isFree
            ? null
            : const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isFree ? PushinTheme.surfaceDark : null,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isFree
            ? null
            : [
                BoxShadow(
                  color: PushinTheme.primaryBlue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isFree ? Icons.star_outline : Icons.star,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getPlanName(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _getPlanDescription(),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (isFree) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: PushinTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Upgrade Plan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                // Navigate to manage subscription
              },
              child: Text(
                'Manage Subscription →',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getPlanName() {
    switch (planTier) {
      case 'pro':
        return 'Pro Plan';
      case 'advanced':
        return 'Advanced Plan';
      default:
        return 'Free Plan';
    }
  }

  String _getPlanDescription() {
    switch (planTier) {
      case 'pro':
        return '3 workouts • 3 hours daily cap';
      case 'advanced':
        return '5 workouts • Unlimited usage';
      default:
        return '1 workout • 1 hour daily cap';
    }
  }
}


























