import 'dart:ui';
import 'dart:io';
import 'dart:convert'; // Added for Base64 encoding
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../widgets/settings/enhanced_settings_section.dart'
    hide EnhancedSettingsTile;
import '../widgets/settings/enhanced_settings_tile.dart';
import '../widgets/GOStepsBackground.dart';
import '../widgets/LogoutPopup.dart';
import '../theme/enhanced_settings_design_tokens.dart';
import '../../../state/auth_state_provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../services/platform/ScreenTimeMonitor.dart';
import '../../../services/PaymentService.dart';
import '../../../services/StripeCheckoutService.dart';
import 'paywall/PaywallScreen.dart';
import 'settings/EmergencyUnlockSettingsScreen.dart';
import 'settings/EditNameScreen.dart';
import 'settings/EditEmailScreen.dart';
import 'settings/ChangePasswordScreen.dart';
import 'auth/FirstWelcomeScreen.dart';
import 'rating/RatingScreen.dart';
import 'subscription/SubscriptionCancelledScreen.dart';

/// Premium Logout Button - A sleek pill-shaped logout button with interactive feedback
class PremiumLogoutButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const PremiumLogoutButton({
    Key? key,
    this.onPressed,
  }) : super(key: key);

  @override
  State<PremiumLogoutButton> createState() => _PremiumLogoutButtonState();
}

class _PremiumLogoutButtonState extends State<PremiumLogoutButton> {
  bool _isPressed = false;

  final Color dangerRed = EnhancedSettingsDesignTokens.dangerRed;
  final Color cardColor = EnhancedSettingsDesignTokens.cardDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 44, // Shorter "pill" height
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24), // Pill shape
            color: dangerRed, // Solid red background
            border: Border.all(
                color: Colors.transparent,
                width: 0), // Explicitly remove any borders
            boxShadow: [
              BoxShadow(
                color: dangerRed.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReflectiveIcon(Icons.logout_rounded),
              const SizedBox(width: 10),
              Text(
                "Logout",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReflectiveIcon(IconData icon) {
    return Icon(
      icon,
      size: 18,
      color: Colors.white,
    );
  }
}

/// Enhanced Settings Screen - The highlight of the PUSHIN app
/// Features premium animations, glassmorphism, and iOS-like design
class EnhancedSettingsScreen extends StatefulWidget {
  const EnhancedSettingsScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedSettingsScreen> createState() => _EnhancedSettingsScreenState();
}

class _EnhancedSettingsScreenState extends State<EnhancedSettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;

  // Shimmer animation for promo banner
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  // Rating status
  bool _hasRated = false;

  // Listener for subscription cancellation
  late VoidCallback _subscriptionCancelledListener;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadRatingStatus();

    // Listen for subscription cancellation to show cancellation screen
    final pushinController = Provider.of<PushinAppController>(context, listen: false);
    _subscriptionCancelledListener = _onSubscriptionCancelled;
    pushinController.subscriptionCancelledPlan
        .addListener(_subscriptionCancelledListener);
  }

  Future<void> _loadRatingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasRated = prefs.getBool('has_rated_app') ?? false;
    });
  }

  void _initializeAnimations() {
    _headerController = AnimationController(
      duration: EnhancedSettingsDesignTokens.pageLoadDuration,
      vsync: this,
    );

    _headerSlideAnimation = Tween<double>(
      begin: -50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));

    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    ));

    // Shimmer animation for promo banner
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _headerController.forward();
  }

  @override
  void dispose() {
    // Remove listener
    final pushinController = Provider.of<PushinAppController>(context, listen: false);
    pushinController.subscriptionCancelledPlan.removeListener(_subscriptionCancelledListener);

    _headerController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  /// Called when subscription is cancelled - navigate to cancellation screen
  void _onSubscriptionCancelled() {
    if (!mounted) return;
    final pushinController = Provider.of<PushinAppController>(context, listen: false);
    final cancelledPlan = pushinController.subscriptionCancelledPlan.value;

    if (cancelledPlan != null) {
      debugPrint('😢 Settings: Subscription cancellation detected');
      debugPrint('   - Cancelled plan: \$cancelledPlan');

      // Clear the state immediately
      pushinController.clearSubscriptionCancelled();

      // Navigate to cancellation screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SubscriptionCancelledScreen(
            previousPlan: cancelledPlan,
            onContinue: () {
              // Refresh subscription status when user continues
              pushinController.refreshPlanTier();
            },
          ),
        ),
      );
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'support@pushin.app',
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Pushin Support Request',
      }),
    );

    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      debugPrint('Error launching email: \$e');
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '\${Uri.encodeComponent(e.key)}=\${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    final pushinController = Provider.of<PushinAppController>(context);
    final authProvider = Provider.of<AuthStateProvider>(context);

    debugPrint('🎯 Settings Screen Build:');
    debugPrint('   - User authenticated: \${authProvider.isAuthenticated}');
    debugPrint('   - User email: \${authProvider.currentUser?.email ?? "none"}');
    debugPrint('   - Plan tier: \${pushinController.planTier}');

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          bottom:
              false, // Don't include bottom safe area - navigation pill handles this
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Animated Header
              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: _headerController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _headerSlideAnimation.value),
                      child: Opacity(
                        opacity: _headerFadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(
                        EnhancedSettingsDesignTokens.spacingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title with Subscription Badge
                        Row(
                          children: [
                            const Text(
                              'Settings',
                              style: EnhancedSettingsDesignTokens.titleLarge,
                            ),
                            const SizedBox(width: 12),
                            _SubscriptionBadge(),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Subtitle
                        Text(
                          'Personalize your experience',
                          style: EnhancedSettingsDesignTokens.subtitle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // GO Club Style Banner Widget
              SliverToBoxAdapter(
                child: _buildPromoBanner(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Account Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: EnhancedSettingsDesignTokens.spacingLarge),
                  child: EnhancedSettingsSection(
                    title: 'Account',
                    icon: Icons.person,
                    gradient: EnhancedSettingsDesignTokens.primaryGradient,
                    delay: 100,
                    children: [
                      EnhancedSettingsTile(
                        icon: Icons.person,
                        title: 'Edit Name',
                        subtitle: 'Change your display name',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const EditNameScreen()),
                          );
                        },
                      ),
                      EnhancedSettingsTile(
                        icon: Icons.email,
                        title: 'Edit E-Mail',
                        subtitle: 'Change your email address',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const EditEmailScreen()),
                          );
                        },
                      ),
                      EnhancedSettingsTile(
                        icon: Icons.lock,
                        title: 'Change Password',
                        subtitle: 'Update your password',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const ChangePasswordScreen()),
                          );
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // App Blocking Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: EnhancedSettingsDesignTokens.spacingLarge),
                  child: EnhancedSettingsSection(
                    title: 'App Blocking',
                    icon: Icons.block,
                    gradient: EnhancedSettingsDesignTokens.accentGradient,
                    delay: 200,
                    children: [
                      _BlockedAppsTile(
                        onTap: () => _showFocusSessionsDialog(),
                      ),
                      EnhancedSettingsTile(
                        icon: Icons.emergency,
                        title: 'Emergency Unlock',
                        subtitle: pushinController.planTier == 'pro' || pushinController.planTier == 'advanced'
                            ? 'Set timer for urgent access'
                            : 'Available in PUSHIN Pro',
                        onTap: () => _showEmergencyUnlockDialog(),
                        showDivider: false,
                        iconColor: const Color(0xFFEF4444), // dangerRed color
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Community & Support Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: EnhancedSettingsDesignTokens.spacingLarge),
                  child: EnhancedSettingsSection(
                    title: 'Community & Support',
                    icon: Icons.favorite_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    delay: 400,
                    children: [
                      // App Rating Tile (Conditional)
                      if (!_hasRated)
                        EnhancedSettingsTile(
                          icon: Icons.star_rounded,
                          title: 'Help us Grow',
                          subtitle: 'Support us with a rating!',
                          onTap: () => _showRatingScreen(),
                          iconColor: const Color(0xFF60A5FA), // light blue color
                        ),

                      // Support Tile
                      EnhancedSettingsTile(
                        icon: Icons.mail_rounded,
                        title: 'Contact Support',
                        subtitle: 'Found a bug? Let us know!',
                        onTap: () => _launchEmail(),
                        showDivider: false,
                        iconColor: const Color(0xFF60A5FA),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Privacy & Security Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: EnhancedSettingsDesignTokens.spacingLarge),
                  child: EnhancedSettingsSection(
                    title: 'Privacy & Security',
                    icon: Icons.security,
                    gradient: EnhancedSettingsDesignTokens.successGradient,
                    delay: 450,
                    children: [
                      EnhancedSettingsTile(
                        icon: Icons.privacy_tip,
                        title: 'Privacy Policy',
                        onTap: () => _launchURL('https://pushin.app/privacy'),
                        iconColor: const Color(0xFF10B981), // green color
                      ),
                      EnhancedSettingsTile(
                        icon: Icons.description,
                        title: 'Terms of Service',
                        onTap: () => _launchURL('https://pushin.app/terms'),
                        showDivider: false,
                        iconColor: const Color(0xFF10B981), // green color
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),



              // Manage Subscription Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: EnhancedSettingsDesignTokens.spacingLarge),
                  child: EnhancedSettingsSection(
                    title: 'Manage Subscription',
                    icon: Icons.subscriptions,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFEB3B), Color(0xFFFFC107)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    delay: 500,
                    children: [
                      EnhancedSettingsTile(
                        icon: Icons.sync,
                        title: 'Edit Subscription',
                        subtitle: 'Manage billing and plan',
                        iconColor: const Color(0xFFFFEB3B), // yellow color
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          if (!mounted) return;

                          final controller = Provider.of<PushinAppController>(
                              context,
                              listen: false);
                          final planTier = controller.planTier;

                          // For free users, show paywall to upgrade
                          if (planTier == 'free') {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const PaywallScreen(),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  // Smooth slide transition from bottom
                                  const begin = Offset(0.0, 1.0);
                                  const end = Offset.zero;
                                  const curve = Curves.easeOutCubic;

                                  var tween = Tween(begin: begin, end: end)
                                      .chain(CurveTween(curve: curve));
                                  var offsetAnimation = animation.drive(tween);

                                  return SlideTransition(
                                    position: offsetAnimation,
                                    child: child,
                                  );
                                },
                                transitionDuration:
                                    const Duration(milliseconds: 400),
                              ),
                            );
                          } else {
                            // For paid users (pro/advanced), open Stripe Customer Portal
                            final authProvider = Provider.of<AuthStateProvider>(
                                context,
                                listen: false);
                            final userId = authProvider.currentUser?.id;

                            // Capture ScaffoldMessenger before async operations to avoid widget lifecycle issues
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(context, rootNavigator: true);

                            if (userId != null) {
                              // Show loading dialog
                              if (mounted) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: EnhancedSettingsDesignTokens.cardDark,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(
                                            color: Color(0xFFFFEB3B),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Opening subscription portal...',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final paymentService = PaymentConfig.createService();

                              debugPrint('🔧 EnhancedSettings: Opening portal for user: $userId');
                              debugPrint('   - Current Plan Tier: $planTier');

                              // Set subscription status before opening portal (handled in DeepLinkHandler)
                              // This allows us to detect changes when they return
                              final deepLinkHandler = controller.deepLinkHandler;
                              if (deepLinkHandler != null) {
                                final cachedStatus = await paymentService.getCachedSubscriptionStatus(userId: userId);
                                deepLinkHandler.setSubscriptionBeforePortal(cachedStatus);
                              }

                              // Open portal and handle result
                              final success = await paymentService.openCustomerPortal(
                                userId: userId,
                              );

                              // Dismiss loading dialog
                              if (mounted) {
                                navigator.pop();
                              }

                              // Show error if portal failed to open
                              if (!success && mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Unable to open subscription portal. Your subscription data may be out of sync. Please try again.',
                                    ),
                                    backgroundColor: EnhancedSettingsDesignTokens.dangerRed,
                                    duration: const Duration(seconds: 4),
                                    action: SnackBarAction(
                                      label: 'Retry',
                                      textColor: Colors.white,
                                      onPressed: () async {
                                        // Retry opening portal
                                        final retrySuccess = await paymentService.openCustomerPortal(
                                          userId: userId,
                                        );
                                        if (!retrySuccess) {
                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Still unable to open portal. Please check your internet connection.'),
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }
                            } else {
                              // No user ID - user might need to sign in
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Please sign in to manage your subscription.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
              ),

              
              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Logout Button
              SliverToBoxAdapter(
                child: _buildLogoutButton(),
              ),

              const SliverToBoxAdapter(
                  child: SizedBox(
                      height:
                          128)), // Navigation pill (64px) + margin (8px) + extra spacing (56px)
            ],
          ),
        ),
      ),
    );
  }

  /// Build GO Club style promotional banner with shimmer effect
  Widget _buildPromoBanner() {
    final controller = Provider.of<PushinAppController>(context, listen: false);
    final planTier = controller.planTier;

    // Show user banner for advanced users
    if (planTier == 'advanced') {
      return Consumer<AuthStateProvider>(
        builder: (context, authProvider, _) {
          return _buildUserBanner(authProvider);
        },
      );
    }

    // Determine banner text based on plan
    final isOnPro = planTier == 'pro';
    final labelText = isOnPro ? 'UPGRADE TO:' : 'TRY NOW:';
    final titleText = isOnPro ? 'PUSHIN Adv.' : 'PUSHIN Pro';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EnhancedSettingsDesignTokens.spacingLarge,
      ),
      child: AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.only(
                bottom: EnhancedSettingsDesignTokens.spacingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                  EnhancedSettingsDesignTokens.borderRadiusLarge),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                  EnhancedSettingsDesignTokens.borderRadiusLarge - 3),
              child: Stack(
                children: [
                  // Base gradient background with content
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFD4FF00), Color(0xFFB8E600)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _handleUpgrade(),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // GO Logo Circle
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Concentric circles effect
                                    ...List.generate(3, (index) {
                                      return Container(
                                        width: 60 - (index * 8.0),
                                        height: 60 - (index * 8.0),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFFD4FF00),
                                            width: 2,
                                          ),
                                        ),
                                      );
                                    }),
                                    const Text(
                                      'GO',
                                      style: TextStyle(
                                        color: Color(0xFFD4FF00),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Text Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      labelText,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      titleText,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Arrow
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.black,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Full-width shimmer overlay
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(
                                -2.0 + (_shimmerAnimation.value * 2), -0.5),
                            end: Alignment(
                                -1.0 + (_shimmerAnimation.value * 2), 0.5),
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.5),
                              Colors.white.withOpacity(0.3),
                              Colors.white.withOpacity(0.0),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build user banner for Advanced users with profile picture and name
  /// Styled exactly like the promotional GO banner
  Widget _buildUserBanner(AuthStateProvider authProvider) {
    final userName = authProvider.currentUser?.name ?? 'User';
    final profileImagePath = authProvider.currentUser?.profileImagePath;
    final hasProfileImage =
        profileImagePath != null && File(profileImagePath).existsSync();

    debugPrint(
        '🖼️ Building user banner - profileImagePath: \$profileImagePath, hasProfileImage: \$hasProfileImage');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EnhancedSettingsDesignTokens.spacingLarge,
      ),
      child: hasProfileImage
          ? Container(
              margin: const EdgeInsets.only(
                  bottom: EnhancedSettingsDesignTokens.spacingMedium),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                    EnhancedSettingsDesignTokens.borderRadiusLarge),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                    EnhancedSettingsDesignTokens.borderRadiusLarge - 3),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFD4FF00), Color(0xFFB8E600)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleAddProfilePicture(),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // User Profile Circle (same size as GO circle)
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Builder(
                                  builder: (context) {
                                    final profilePictureServer = authProvider.currentUser?.profilePictureServer;
                                    
                                    if (profilePictureServer != null) {
                                      try {
                                        final bytes = base64Decode(profilePictureServer);
                                        return Image.memory(
                                          bytes,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            if (hasProfileImage) {
                                              return Image.file(
                                                File(profileImagePath!),
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              );
                                            }
                                            return const Icon(Icons.person, color: Color(0xFFD4FF00));
                                          },
                                        );
                                      } catch (e) {
                                        // Fallback to local
                                      }
                                    }
                                    
                                    if (hasProfileImage) {
                                      return Image.file(
                                        File(profileImagePath!),
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                           return const Icon(Icons.person, color: Color(0xFFD4FF00));
                                        },
                                      );
                                    }
                                    
                                    return const Icon(Icons.person, color: Color(0xFFD4FF00));
                                  }
                                ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // User Name with label (same styling as GO banner text)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'KEEP PUSHIN:',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userName,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.only(
                      bottom: EnhancedSettingsDesignTokens.spacingMedium),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                        EnhancedSettingsDesignTokens.borderRadiusLarge),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                        EnhancedSettingsDesignTokens.borderRadiusLarge - 3),
                    child: Stack(
                      children: [
                        // Base gradient background with content (same as GO banner)
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFD4FF00), Color(0xFFB8E600)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _handleAddProfilePicture(),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    // User Profile Circle (same size as GO circle)
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: const CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.transparent,
                                        child: Icon(
                                          Icons.person,
                                          color: Color(0xFFD4FF00),
                                          size: 32,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    // User Name with label (same styling as GO banner text)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'KEEP PUSHIN:',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            userName,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              height: 1,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Full-width shimmer overlay (same as GO banner)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(
                                      -2.0 + (_shimmerAnimation.value * 2),
                                      -0.5),
                                  end: Alignment(
                                      -1.0 + (_shimmerAnimation.value * 2),
                                      0.5),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.5),
                                    Colors.white.withOpacity(0.3),
                                    Colors.white.withOpacity(0.0),
                                    Colors.transparent,
                                  ],
                                  stops: const [
                                    0.0,
                                    0.2,
                                    0.35,
                                    0.5,
                                    0.65,
                                    0.8,
                                    1.0
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLogoutButton() {
    final authProvider = Provider.of<AuthStateProvider>(context);
    final isAuthenticated = authProvider.isAuthenticated;

    debugPrint('🧭 BUILD LOGOUT BUTTON:');
    debugPrint('   - isAuthenticated: \$isAuthenticated');
    debugPrint('   - isGuestMode: \${authProvider.isGuestMode}');
    debugPrint('   - guestCompletedSetup: \${authProvider.guestCompletedSetup}');
    final userEmail = authProvider.currentUser?.email ?? "null";
    // START: Simplified debug print
    debugPrint('   - currentUser: $userEmail');

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: EnhancedSettingsDesignTokens.spacingLarge),
      child: Center(
        child: !isAuthenticated
            ? _buildSignUpButton()
            : PremiumLogoutButton(
                onPressed: () => _handleLogout(),
              ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return GestureDetector(
      onTap: () {
        debugPrint('🧭 SIGN UP BUTTON TAPPED');
        final authProvider =
            Provider.of<AuthStateProvider>(context, listen: false);

        debugPrint('   - isAuthenticated: \${authProvider.isAuthenticated}');
        debugPrint('   - isGuestMode: \${authProvider.isGuestMode}');
        debugPrint(
            '   - isOnboardingCompleted: \${authProvider.isOnboardingCompleted}');

        // For all unauthenticated users, navigate to first welcome screen with sign up and sign in buttons
        debugPrint(
            '   → Navigating to FirstWelcomeScreen for unauthenticated users');
        // since state-driven navigation doesn't work from within the main app
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const FirstWelcomeScreen(),
          ),
        );
        HapticFeedback.lightImpact();
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF10B981), // Green color
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add_rounded,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              "Sign Up",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Navigation Methods

  void _showEmergencyUnlockDialog() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    
    final controller = Provider.of<PushinAppController>(context, listen: false);
    final planTier = controller.planTier;
    
    // Redirect free/guest users to paywall
    if (planTier != 'pro' && planTier != 'advanced') {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PaywallScreen(preSelectedPlan: 'pro'),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Smooth slide transition from bottom
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      // Pro/Advanced users can access emergency unlock settings
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const EmergencyUnlockSettingsScreen(),
        ),
      );
    }
  }

  Future<void> _launchURL(String url) async {
    HapticFeedback.lightImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  void _handleAddProfilePicture() {
    HapticFeedback.lightImpact();

    // Show bottom sheet with options
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: EnhancedSettingsDesignTokens.cardDark,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Add Profile Picture',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6060FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF6060FF),
                  ),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF10B981),
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
      );

      if (image != null) {
        await _cropAndSaveImage(image.path);
      } else {
        // User cancelled, no action needed
      }
    } catch (e) {
      debugPrint('Failed to take photo: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        await _cropAndSaveImage(image.path);
      } else {
         // User cancelled
      }
    } catch (e) {
      debugPrint('Failed to pick image: $e');
    }
  }

  Future<void> _cropAndSaveImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 512,
        maxHeight: 512,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: Colors.black,
            toolbarWidgetColor: const Color(0xFFD4FF00),
            backgroundColor: Colors.black,
            activeControlsWidgetColor: const Color(0xFFD4FF00),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateButtonsHidden: false,
            cancelButtonTitle: 'Cancel',
            doneButtonTitle: 'Done',
          ),
        ],
      );

      if (croppedFile != null) {
        await _saveProfileImage(croppedFile.path);
      }
    } catch (e) {
      debugPrint('Failed to crop image: $e');
    }
  }

  Future<void> _saveProfileImage(String imagePath) async {
    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final String profileImageDir = '${directory.path}/profile_images';

      // Create directory if it doesn't exist
      await Directory(profileImageDir).create(recursive: true);

      // Generate unique filename
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      // Use a standard extension if original is weird, but try to keep it
      String extension = path.extension(imagePath);
      if (extension.isEmpty) extension = '.jpg';
      
      final String fileName = 'profile_$timestamp$extension';
      final String savedPath = '$profileImageDir/$fileName';

      // Copy image to permanent location
      await File(imagePath).copy(savedPath);

      if (!mounted) return;

      // Update auth provider with new image path
      final authProvider =
          Provider.of<AuthStateProvider>(context, listen: false);
      // Still set local path for immediate feedback/offline support
      await authProvider.setProfileImagePath(savedPath);
      
      // Upload to server if user is logged in
      if (authProvider.currentUser != null) {
        debugPrint('☁️ Uploading profile picture to server...');
        final bytes = await File(savedPath).readAsBytes();
        final base64Image = base64Encode(bytes);
        
        final success = await authProvider.updateProfile(
          profilePicture: base64Image,
        );
        
        if (success) {
          debugPrint('✅ Profile picture uploaded to server successfully');
        } else {
          debugPrint('❌ Failed to upload profile picture to server');
        }
      }
      
      // Force UI rebuild
      setState(() {});

      if (mounted) {
        // Force UI rebuild
        setState(() {});
      }
      
      debugPrint('✅ Image saved successfully to: $savedPath');


    } catch (e) {
      debugPrint('Failed to save image: $e');
    }
  }

  void _handleUpgrade() {
    HapticFeedback.heavyImpact();
    if (!mounted) return;

    // Determine which plan to pre-select based on current plan tier
    final controller = Provider.of<PushinAppController>(context, listen: false);
    final planTier = controller.planTier;
    final preSelectedPlan = planTier == 'pro' ? 'advanced' : 'pro';

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PaywallScreen(preSelectedPlan: preSelectedPlan),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Smooth slide transition from bottom
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _handleLogout() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor:
          Colors.transparent, // We handle the background in the popup itself
      transitionDuration: Duration.zero,
      pageBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        return LogoutPopup(
          onCancel: () {
            Navigator.of(context).pop(); // Just close the popup
          },
          onLogout: () async {
            // Close the dialog first
            Navigator.of(context).pop();

            // Perform logout - this will clear all state and navigate to WelcomeScreen
            final authProvider =
                Provider.of<AuthStateProvider>(context, listen: false);
            await authProvider.logout();

            // Small delay to ensure state is fully updated
            await Future.delayed(const Duration(milliseconds: 100));

            // Force navigation back to FirstWelcomeScreen and clear navigation stack
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const FirstWelcomeScreen()),
                (route) => false,
              );
            }
          },
        );
      },
    );
  }

  void _showFocusSessionsDialog() async {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    try {
      final appController = context.read<PushinAppController>();
      
      // Show loading feedback if Screen Time permission not yet granted
      // This helps users know something is happening while the system dialog prepares
      if (!appController.isScreenTimeAuthorized && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loading Screen Time options...'),
              duration: Duration(seconds: 2), // Short duration as the picker should appear soon
            ),
          );
      }

      // Use the controller's method which handles permission request + picker
      final success = await appController.presentIOSAppPicker();

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Screen Time access is required to block apps')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open app picker')),
        );
      }
    }
  }

  void _showRatingScreen() {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RatingScreen(
          onContinue: () {
            Navigator.of(context).pop();
            // Refresh rating status to hide the section
            _loadRatingStatus();
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

/// Edit Profile Dialog Widget
class EditProfileDialog extends StatefulWidget {
  final AuthUser? currentUser;
  final VoidCallback onProfileUpdated;

  const EditProfileDialog({
    Key? key,
    required this.currentUser,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current user data
    _nameController.text = widget.currentUser?.name ?? '';
    _emailController.text = widget.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Basic validation
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Name is required');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Valid email is required');
      return;
    }

    if (newPassword.isNotEmpty) {
      if (currentPassword.isEmpty) {
        setState(() =>
            _errorMessage = 'Current password is required to change password');
        return;
      }
      if (newPassword.length < 6) {
        setState(
            () => _errorMessage = 'New password must be at least 6 characters');
        return;
      }
      if (newPassword != confirmPassword) {
        setState(() => _errorMessage = 'New passwords do not match');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider =
          Provider.of<AuthStateProvider>(context, listen: false);

      // Prepare update data
      String? updateName;
      String? updateEmail;
      String? updatePassword;

      if (name != widget.currentUser?.name) {
        updateName = name;
      }

      if (email != widget.currentUser?.email) {
        updateEmail = email;
      }

      if (newPassword.isNotEmpty) {
        // Note: In a real implementation, you'd need to verify the current password first
        // For now, we'll assume the user knows their current password
        updatePassword = newPassword;
      }

      final success = await authProvider.updateProfile(
        name: updateName,
        email: updateEmail,
        password: updatePassword,
      );

      if (success) {
        widget.onProfileUpdated();
        Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      } else {
        setState(
            () => _errorMessage = authProvider.errorMessage ?? 'Update failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Update failed: \$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EnhancedSettingsDesignTokens.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Update your account information',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        EnhancedSettingsDesignTokens.dangerRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: EnhancedSettingsDesignTokens.dangerRed
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: EnhancedSettingsDesignTokens.dangerRed,
                      fontSize: 14,
                    ),
                  ),
                ),

              if (_errorMessage != null) const SizedBox(height: 16),

              // Name field
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6060FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
              ),
              const SizedBox(height: 16),

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6060FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                ),
              ),
              const SizedBox(height: 24),

              // Password section header
              Text(
                'Change Password (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),

              // Current password field
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6060FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    onPressed: () => setState(() =>
                        _obscureCurrentPassword = !_obscureCurrentPassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // New password field
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6060FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    onPressed: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm password field
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6060FF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6060FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Update',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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

/// Subscription Badge Widget - Shows current subscription tier
class _SubscriptionBadge extends StatelessWidget {
  const _SubscriptionBadge();

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthStateProvider, PushinAppController>(
      builder: (context, authProvider, pushinController, _) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isGuest = authProvider.isGuestMode;
        final planTier = pushinController.planTier;

        // Show actual subscription tier for paid plans, regardless of auth status
        switch (planTier) {
          case 'pro':
            return _buildBadge('PRO', const Color(0xFF6060FF)); // Purple/Blue
          case 'advanced':
            return _buildBadge('ADVANCED', const Color(0xFFFFB347)); // Orange
          case 'free':
            // Free plan - show FREE for authenticated users, GUEST for guest mode
            if (isAuthenticated && !isGuest) {
              return _buildBadge('FREE', const Color(0xFF10B981)); // Green
            } else {
              return _buildBadge(
                  'GUEST', const Color(0xFF94A3B8)); // Gray for guest
            }
          default:
            // Default to guest for unknown states
            return _buildBadge(
                'GUEST', const Color(0xFF94A3B8)); // Gray for guest
        }
      },
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: color.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Stateful widget that properly listens to blocked apps changes
class _BlockedAppsTile extends StatefulWidget {
  final VoidCallback onTap;

  const _BlockedAppsTile({required this.onTap});

  @override
  State<_BlockedAppsTile> createState() => _BlockedAppsTileState();
}

class _BlockedAppsTileState extends State<_BlockedAppsTile> {
  late PushinAppController _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = Provider.of<PushinAppController>(context, listen: false);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _controller.blockedApps.length;
    return EnhancedSettingsTile(
      icon: Icons.screen_lock_portrait,
      title: 'Distracting Apps',
      subtitle: count > 0
          ? '$count apps blocked'
          : 'Choose distracting apps to block',
      onTap: widget.onTap,
      iconColor: const Color(0xFFEF4444), // dangerRed color
    );
  }
}
