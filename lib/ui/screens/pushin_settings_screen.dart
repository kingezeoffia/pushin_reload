import 'package:flutter/material.dart';
import '../theme/settings_design_tokens.dart';
import '../widgets/GOStepsBackground.dart';
import '../widgets/PressAnimationButton.dart';
import '../widgets/settings/enhanced_settings_section.dart';

/// Production-ready PUSHIN Settings Screen
/// Focuses on app-specific functionality: blocked apps, workouts, time management
class PushinSettingsScreen extends StatefulWidget {
  const PushinSettingsScreen({super.key});

  @override
  State<PushinSettingsScreen> createState() => _PushinSettingsScreenState();
}

class _PushinSettingsScreenState extends State<PushinSettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _pageLoadController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Mock data - replace with real controller data
  String currentPlan = 'Pro'; // Free, Pro, Advanced
  int blockedAppsCount = 2;
  int blockedAppsLimit = 3;
  int todayWorkouts = 3;
  int todayEarnedMinutes = 45;
  int todayUsedMinutes = 32;
  bool screenTimeEnabled = true;
  bool cameraEnabled = true;

  @override
  void initState() {
    super.initState();
    _pageLoadController = AnimationController(
      duration: SettingsDesignTokens.pageLoad,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pageLoadController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageLoadController,
      curve: Curves.easeOutCubic,
    ));
    _pageLoadController.forward();
  }

  @override
  void dispose() {
    _pageLoadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding.bottom;
    final totalBottomSpace = safePadding + 80;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.15,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Dynamic Header with Stats
                  SliverToBoxAdapter(
                    child: _buildDynamicHeader(),
                  ),

                // Core Settings Sections
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // 1. ACCOUNT & SUPPORT
                        EnhancedSettingsSection(
                          title: 'Account & Support',
                          icon: Icons.person,
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade800,
                              Colors.grey.shade700,
                            ],
                          ),
                          delay: 100,
                          children: const [
                            EnhancedSettingsTile(
                              title: 'Profile Settings',
                              subtitle: 'Name, email, profile photo',
                              leadingIcon: Icons.person_outline,
                              type: SettingsTileType.navigation,
                            ),
                            EnhancedSettingsTile(
                              title: 'Help & Support',
                              subtitle: 'FAQs and contact us',
                              leadingIcon: Icons.help_outline,
                              type: SettingsTileType.navigation,
                            ),
                            EnhancedSettingsTile(
                              title: 'Privacy Policy',
                              leadingIcon: Icons.privacy_tip_outlined,
                              type: SettingsTileType.navigation,
                            ),
                            EnhancedSettingsTile(
                              title: 'Terms of Service',
                              leadingIcon: Icons.description_outlined,
                              type: SettingsTileType.navigation,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 2. BLOCKED APPS MANAGEMENT
                        EnhancedSettingsSection(
                          title: 'Blocked Apps',
                          icon: Icons.block,
                          gradient: SettingsDesignTokens.dangerGradient,
                          delay: 200,
                          children: [
                            EnhancedSettingsTile(
                              title: 'Manage Blocked Apps',
                              subtitle: '$blockedAppsCount of $blockedAppsLimit apps blocked',
                              leadingIcon: Icons.apps,
                              type: SettingsTileType.navigation,
                              onTap: _navigateToBlockedApps,
                            ),
                            if (blockedAppsCount >= blockedAppsLimit)
                              EnhancedSettingsTile(
                                title: 'Upgrade to Block More',
                                subtitle: 'Advanced: Block up to 5 apps',
                                leadingIcon: Icons.workspace_premium,
                                type: SettingsTileType.navigation,
                                onTap: _showUpgradeDialog,
                              ),
                            EnhancedSettingsTile(
                              title: 'Blocking Strictness',
                              subtitle: 'Strict mode (no bypasses)',
                              leadingIcon: Icons.security,
                              type: SettingsTileType.navigation,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 2. WORKOUT SETTINGS
                        EnhancedSettingsSection(
                          title: 'Workout Settings',
                          icon: Icons.fitness_center,
                          gradient: SettingsDesignTokens.successGradient,
                          delay: 300,
                          children: [
                            EnhancedSettingsTile(
                              title: 'Available Workouts',
                              subtitle: 'Push-ups, Squats, Plank',
                              leadingIcon: Icons.sports_gymnastics,
                              type: SettingsTileType.navigation,
                              onTap: _navigateToWorkouts,
                            ),
                            EnhancedSettingsTile(
                              title: 'Push-ups Rep Count',
                              subtitle: '20 reps = 10 minutes unlock',
                              leadingIcon: Icons.trending_up,
                              type: SettingsTileType.navigation,
                            ),
                            EnhancedSettingsTile(
                              title: 'Manual Rep Counting',
                              subtitle: 'Enable when camera fails',
                              type: SettingsTileType.toggle,
                              initialValue: false,
                            ),
                            EnhancedSettingsTile(
                              title: 'Fitness Level',
                              subtitle: 'Intermediate (affects difficulty)',
                              leadingIcon: Icons.local_fire_department,
                              type: SettingsTileType.navigation,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 4. TIME & LIMITS SETTINGS
                        EnhancedSettingsSection(
                          title: 'Time & Limits',
                          icon: Icons.access_time,
                          gradient: SettingsDesignTokens.accentGradient,
                          delay: 400,
                          children: [
                            EnhancedSettingsTile(
                              title: 'Daily Unlock Cap',
                              subtitle: currentPlan == 'Advanced'
                                  ? 'Unlimited'
                                  : currentPlan == 'Pro'
                                      ? '3 hours per day'
                                      : '1 hour per day',
                              leadingIcon: Icons.timelapse,
                              type: SettingsTileType.navigation,
                            ),
                            EnhancedSettingsTile(
                              title: 'Grace Period',
                              subtitle: _getGracePeriodText(),
                              leadingIcon: Icons.timer,
                              type: SettingsTileType.navigation,
                            ),
                            EnhancedSettingsTile(
                              title: 'Time per Workout',
                              subtitle: '30 seconds per rep',
                              leadingIcon: Icons.schedule,
                              type: SettingsTileType.navigation,
                            ),
                            EnhancedSettingsTile(
                              title: 'Daily Reset Time',
                              subtitle: 'Midnight (local timezone)',
                              leadingIcon: Icons.nightlight_round,
                              type: SettingsTileType.navigation,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 5. PLAN & BILLING
                        EnhancedSettingsSection(
                          title: 'Plan & Billing',
                          icon: Icons.workspace_premium,
                          gradient: SettingsDesignTokens.primaryGradient,
                          delay: 500,
                          children: [
                            EnhancedSettingsTile(
                              title: 'Current Plan',
                              subtitle: '$currentPlan - ${_getPlanPrice()}',
                              leadingIcon: Icons.card_membership,
                              type: SettingsTileType.navigation,
                              onTap: _navigateToPlanDetails,
                            ),
                            if (currentPlan != 'Advanced')
                              EnhancedSettingsTile(
                                title: 'Upgrade Plan',
                                subtitle: 'Unlock more apps & workouts',
                                leadingIcon: Icons.arrow_upward,
                                type: SettingsTileType.navigation,
                                onTap: _showUpgradeDialog,
                              ),
                            EnhancedSettingsTile(
                              title: 'Billing History',
                              subtitle: 'View past payments',
                              leadingIcon: Icons.receipt_long,
                              type: SettingsTileType.navigation,
                            ),
                            if (currentPlan != 'Free')
                              EnhancedSettingsTile(
                                title: 'Manage Subscription',
                                subtitle: 'Next payment: Jan 1, 2026',
                                leadingIcon: Icons.settings_outlined,
                                type: SettingsTileType.navigation,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 6. PERMISSIONS & BLOCKING
                        EnhancedSettingsSection(
                          title: 'Permissions',
                          icon: Icons.verified_user,
                          gradient: SettingsDesignTokens.warningGradient,
                          delay: 600,
                          children: [
                            EnhancedSettingsTile(
                              title: 'Screen Time Access',
                              subtitle: screenTimeEnabled
                                  ? '✓ Enabled'
                                  : '✗ Disabled - Tap to enable',
                              leadingIcon: Icons.phone_android,
                              type: SettingsTileType.navigation,
                              onTap: _requestScreenTimePermission,
                            ),
                            EnhancedSettingsTile(
                              title: 'Camera for Pose Detection',
                              subtitle: cameraEnabled
                                  ? '✓ Enabled'
                                  : '✗ Disabled - Tap to enable',
                              leadingIcon: Icons.camera_alt,
                              type: SettingsTileType.navigation,
                              onTap: _requestCameraPermission,
                            ),
                            EnhancedSettingsTile(
                              title: 'Notification Permissions',
                              subtitle: 'Time warnings & reminders',
                              leadingIcon: Icons.notifications_active,
                              type: SettingsTileType.toggle,
                              initialValue: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildLogoutButton(),
                      ],
                    ),
                  ),
                ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: totalBottomSpace),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.05,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Personalize your experience',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.6),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLogoutButton() {
    return PressAnimationButton(
      onTap: _logout,
      child: Container(
        width: MediaQuery.of(context).size.width - 140, // Full width minus 40px padding + 100px (50px each side)
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Center(
          child: Text(
            'Logout',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  String _getGracePeriodText() {
    switch (currentPlan) {
      case 'Advanced':
        return '120 seconds buffer';
      case 'Pro':
        return '60 seconds buffer';
      default:
        return '30 seconds buffer';
    }
  }

  String _getPlanPrice() {
    switch (currentPlan) {
      case 'Advanced':
        return '€14.99/month';
      case 'Pro':
        return '€9.99/month';
      default:
        return 'Free';
    }
  }

  // Navigation methods
  void _navigateToBlockedApps() {
    // TODO: Navigate to blocked apps management screen
    print('Navigate to blocked apps');
  }

  void _navigateToWorkouts() {
    // TODO: Navigate to workout selection screen
    print('Navigate to workouts');
  }

  void _navigateToPlanDetails() {
    // TODO: Navigate to plan details screen
    print('Navigate to plan details');
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6060FF).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 48,
                  color: Color(0xFF6060FF),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Upgrade to Advanced',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock unlimited apps, all workouts, and unlimited daily time!',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: Text(
                            'Maybe Later',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/paywall');
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Center(
                          child: Text(
                            'Upgrade Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2A2A6A),
                            ),
                          ),
                        ),
                      ),
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

  void _requestScreenTimePermission() {
    // TODO: Request Screen Time permission
    print('Request Screen Time permission');
  }

  void _requestCameraPermission() {
    // TODO: Request Camera permission
    print('Request Camera permission');
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout,
                  size: 48,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to logout?',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () {
                        // TODO: Implement logout logic
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Center(
                          child: Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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
