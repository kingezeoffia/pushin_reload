import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controller/PushinAppController.dart';
import '../../theme/pushin_theme.dart';
import 'ManageAppsScreen.dart';

/// Settings Screen - User configuration and account management
///
/// Design:
/// - Section-based layout with cards
/// - Blocked apps management
/// - Emergency unlock settings
/// - Subscription/plan details
/// - Profile information
///
/// Visual Reference: GO Club settings (dark theme, card sections)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                backgroundColor: Colors.transparent,
                expandedHeight: 120,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                ),
              ),
              
              // Content
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Plan Card
                    Consumer<PushinAppController>(
                      builder: (context, controller, _) {
                        return _PlanCard(
                          planTier: controller.planTier,
                          onUpgrade: () => Navigator.pushNamed(context, '/paywall'),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Blocking Section
                    const _SectionHeader(title: 'App Blocking'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      icon: Icons.block,
                      iconColor: PushinTheme.errorRed,
                      title: 'Manage Blocked Apps',
                      subtitle: 'Choose which apps require workouts',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManageAppsScreen(),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _SettingsCard(
                      icon: Icons.access_time,
                      iconColor: PushinTheme.warningYellow,
                      title: 'Emergency Unlock',
                      subtitle: '5 minutes (once per day)',
                      onTap: () => _showEmergencyUnlockDialog(context),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Account Section
                    const _SectionHeader(title: 'Account'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      icon: Icons.person_outline,
                      iconColor: PushinTheme.primaryBlue,
                      title: 'Profile',
                      subtitle: 'Edit your information',
                      onTap: () {
                        // Navigate to profile screen
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _SettingsCard(
                      icon: Icons.fitness_center,
                      iconColor: PushinTheme.successGreen,
                      title: 'Fitness Level & Goals',
                      subtitle: 'Update your preferences',
                      onTap: () {
                        // Navigate to fitness preferences
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // App Section
                    const _SectionHeader(title: 'App'),
                    const SizedBox(height: 12),
                    _SettingsCard(
                      icon: Icons.notifications_outlined,
                      iconColor: PushinTheme.primaryBlue,
                      title: 'Notifications',
                      subtitle: 'Manage reminders and alerts',
                      onTap: () {
                        // Navigate to notifications settings
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _SettingsCard(
                      icon: Icons.help_outline,
                      iconColor: PushinTheme.primaryBlue,
                      title: 'Help & Support',
                      subtitle: 'Get help or contact us',
                      onTap: () {
                        // Navigate to help screen
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _SettingsCard(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: PushinTheme.textSecondary,
                      title: 'Privacy Policy',
                      subtitle: 'View our privacy policy',
                      onTap: () {
                        // Open privacy policy
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _SettingsCard(
                      icon: Icons.description_outlined,
                      iconColor: PushinTheme.textSecondary,
                      title: 'Terms of Service',
                      subtitle: 'View terms and conditions',
                      onTap: () {
                        // Open terms of service
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Log Out Button
                    GestureDetector(
                      onTap: () => _showLogoutDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: PushinTheme.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: PushinTheme.errorRed.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: PushinTheme.errorRed,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // App Version
                    Center(
                      child: Text(
                        'PUSHIN\' v1.0.0',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyUnlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: PushinTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 56,
                color: PushinTheme.warningYellow,
              ),
              const SizedBox(height: 16),
              const Text(
                'Emergency Unlock',
                style: PushinTheme.headline3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use this only in genuine emergencies. You\'ll get 5 minutes of access without working out. Limited to once per day.',
                style: PushinTheme.body2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PushinTheme.warningYellow,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // Trigger emergency unlock
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Emergency unlock activated (5 minutes)'),
                            backgroundColor: PushinTheme.warningYellow,
                          ),
                        );
                      },
                      child: const Text('Unlock'),
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: PushinTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.logout,
                size: 56,
                color: PushinTheme.errorRed,
              ),
              const SizedBox(height: 16),
              const Text(
                'Log Out?',
                style: PushinTheme.headline3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to log out? Your progress will be saved.',
                style: PushinTheme.body2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PushinTheme.errorRed,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        // Handle logout
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/onboarding',
                          (route) => false,
                        );
                      },
                      child: const Text('Log Out'),
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

/// Section Header Widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Settings Card Widget
class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PushinTheme.surfaceDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.4),
                  size: 16,
                ),
              ],
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
      case 'standard':
        return 'Standard Plan';
      case 'advanced':
        return 'Advanced Plan';
      default:
        return 'Free Plan';
    }
  }

  String _getPlanDescription() {
    switch (planTier) {
      case 'standard':
        return '3 workouts • 3 hours daily cap';
      case 'advanced':
        return '5 workouts • Unlimited usage';
      default:
        return '1 workout • 1 hour daily cap';
    }
  }
}




















