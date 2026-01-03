import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/settings/enhanced_settings_section.dart'
    hide EnhancedSettingsTile;
import '../widgets/settings/enhanced_settings_tile.dart';
import '../widgets/GOStepsBackground.dart';
import '../theme/enhanced_settings_design_tokens.dart';
import '../../../state/auth_state_provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../services/platform/ScreenTimeMonitor.dart';
import 'paywall/PaywallScreen.dart';

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

  // Settings State
  bool _isDarkMode = true;
  bool _notificationsEnabled = true;
  double _fontSize = 1.0; // 0.8 = Small, 1.0 = Medium, 1.2 = Large
  Color _accentColor = EnhancedSettingsDesignTokens.primaryPurple;
  bool _isPremium = false;
  String _displayName = 'Your Name';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeAnimations();
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? true;
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _fontSize = prefs.getDouble('font_size') ?? 1.0;
      _isPremium = prefs.getBool('is_premium') ?? false;
      _displayName = prefs.getString('display_name') ?? '';

      // Load accent color
      final colorValue = prefs.getInt('accent_color');
      if (colorValue != null) {
        _accentColor = Color(colorValue);
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _isDarkMode);
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setDouble('font_size', _fontSize);
    await prefs.setInt('accent_color', _accentColor.value);
    await prefs.setString('display_name', _displayName);
  }

  @override
  void dispose() {
    _headerController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          bottom: false, // Don't include bottom safe area - navigation pill handles this
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
                      // Title
                      const Text(
                        'Settings',
                        style: EnhancedSettingsDesignTokens.titleLarge,
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
                      icon: Icons.person_outline,
                      title: 'Edit Name',
                      subtitle: 'Change your display name',
                      onTap: () => _showEditNameDialog(),
                    ),
                    EnhancedSettingsTile(
                      icon: Icons.email_outlined,
                      title: 'Edit E-Mail',
                      subtitle: 'Change your email address',
                      onTap: () => _showEditEmailDialog(),
                    ),
                    EnhancedSettingsTile(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      subtitle: 'Update your password',
                      onTap: () => _showChangePasswordDialog(),
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
                    EnhancedSettingsTile(
                      icon: Icons.screen_lock_portrait,
                      title: 'Distracting Apps',
                      subtitle: 'Choose distracting apps to block',
                      onTap: () => _showFocusSessionsDialog(),
                      iconColor: const Color(0xFFEF4444), // dangerRed color
                    ),
                    EnhancedSettingsTile(
                      icon: Icons.timer,
                      title: 'Emergency Unlock',
                      subtitle: 'Set timer for urgent access',
                      onTap: () => _showEmergencyUnlockDialog(),
                      showDivider: false,
                      iconColor: const Color(0xFFEF4444), // dangerRed color
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
                  delay: 400,
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

            const SliverToBoxAdapter(child: SizedBox(height: 40)),

            // Logout Button
            SliverToBoxAdapter(
              child: _buildLogoutButton(),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),

            // App Version
            SliverToBoxAdapter(
              child: Center(
                child: Text(
                  'PUSHIN v1.0.0',
                  style: EnhancedSettingsDesignTokens.tileSubtitle,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 112)), // Navigation pill (64px) + margin (8px) + extra spacing (40px)
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

    // Don't show banner if user is on advanced plan
    if (planTier == 'advanced') {
      return const SizedBox.shrink();
    }

    // Determine banner text based on plan
    final isOnPro = planTier == 'pro';
    final labelText = isOnPro ? 'UPGRADE TO:' : 'TRY NOW:';
    final titleText = isOnPro ? 'PUSHIN Advanced' : 'PUSHIN Pro';

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
              border: Border.all(
                color: const Color(0xFF4A5FFF),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4FF00).withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFFD4FF00).withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 4),
                ),
              ],
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
                            begin: Alignment(-2.0 + (_shimmerAnimation.value * 2), -0.5),
                            end: Alignment(-1.0 + (_shimmerAnimation.value * 2), 0.5),
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

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: EnhancedSettingsDesignTokens.spacingLarge),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _handleLogout(),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: EnhancedSettingsDesignTokens.dangerRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                EnhancedSettingsDesignTokens.borderRadiusMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Dialog and Navigation Methods

  void _showEditNameDialog() {
    showDialog(
      context: context,
      builder: (context) => EditNameDialog(
        currentName: _displayName,
        onNameUpdated: (newName) async {
          setState(() => _displayName = newName);
          _saveSettings();
          // Also update the backend account name
          await _updateAccountName(newName);
        },
      ),
    );
  }

  void _showEditEmailDialog() {
    showDialog(
      context: context,
      builder: (context) => EditEmailDialog(
        currentEmail: Provider.of<AuthStateProvider>(context, listen: false)
                .currentUser
                ?.email ??
            '',
        onEmailUpdated: (newEmail) {
          // Email update will be handled by the dialog
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(
        onPasswordUpdated: () {
          // Password update will be handled by the dialog
        },
      ),
    );
  }

  Future<void> _updateAccountName(String newName) async {
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    await authProvider.updateProfile(name: newName);
  }

  void _showEmergencyUnlockDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency Unlock - Coming Soon!')),
    );
  }

  Future<void> _launchURL(String url) async {
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

  void _handleUpgrade() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PaywallScreen(),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EnhancedSettingsDesignTokens.cardDark,
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close the dialog first
              Navigator.pop(context);

              // Perform logout and navigate to sign-in screen
              final authProvider =
                  Provider.of<AuthStateProvider>(context, listen: false);
              await authProvider.logout();
              authProvider.triggerSignInFlow();
            },
            style: TextButton.styleFrom(
              foregroundColor: EnhancedSettingsDesignTokens.dangerRed,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showFocusSessionsDialog() async {
    try {
      final appController = context.read<PushinAppController>();
      final focusModeService = appController.focusModeService;

      if (focusModeService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen Time service not available')),
        );
        return;
      }

      // Check authorization first
      if (focusModeService.authorizationStatus !=
          AuthorizationStatus.authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enable Screen Time access first')),
        );
        return;
      }

      // Open the picker directly
      final result = await focusModeService.presentAppPicker();

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Updated blocked apps (${result.totalSelected} selected)'),
            backgroundColor: EnhancedSettingsDesignTokens.primaryPurple,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open app picker')),
        );
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } else {
        setState(
            () => _errorMessage = authProvider.errorMessage ?? 'Update failed');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Update failed: $e');
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

  void _showFocusSessionsDialog() async {
    try {
      final appController = context.read<PushinAppController>();
      final focusModeService = appController.focusModeService;

      if (focusModeService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen Time service not available')),
        );
        return;
      }

      // Check authorization first
      if (focusModeService.authorizationStatus !=
          AuthorizationStatus.authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enable Screen Time access first')),
        );
        return;
      }

      // Open the picker directly
      final result = await focusModeService.presentAppPicker();

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Updated blocked apps (${result.totalSelected} selected)'),
            backgroundColor: EnhancedSettingsDesignTokens.primaryPurple,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open app picker')),
        );
      }
    }
  }
}

/// Edit Name Dialog Widget
class EditNameDialog extends StatefulWidget {
  final String currentName;
  final Future<void> Function(String) onNameUpdated;

  const EditNameDialog({
    Key? key,
    required this.currentName,
    required this.onNameUpdated,
  }) : super(key: key);

  @override
  State<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<EditNameDialog> {
  late TextEditingController _nameController;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateName() async {
    final name = _nameController.text.trim();

    // Basic validation
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Name cannot be empty');
      return;
    }

    if (name.length > 50) {
      setState(() => _errorMessage = 'Name must be less than 50 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onNameUpdated(name);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated successfully')),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Failed to update name: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
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
                'Edit Display Name',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to be addressed',
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
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                      onPressed: _isLoading ? null : _updateName,
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
      ),
    );
  }

  void _showFocusSessionsDialog() async {
    try {
      final appController = context.read<PushinAppController>();
      final focusModeService = appController.focusModeService;

      if (focusModeService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen Time service not available')),
        );
        return;
      }

      // Check authorization first
      if (focusModeService.authorizationStatus !=
          AuthorizationStatus.authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enable Screen Time access first')),
        );
        return;
      }

      // Open the picker directly
      final result = await focusModeService.presentAppPicker();

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Updated blocked apps (${result.totalSelected} selected)'),
            backgroundColor: EnhancedSettingsDesignTokens.primaryPurple,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open app picker')),
        );
      }
    }
  }
}

/// Edit Email Dialog Widget
class EditEmailDialog extends StatefulWidget {
  final String currentEmail;
  final Function(String) onEmailUpdated;

  const EditEmailDialog({
    Key? key,
    required this.currentEmail,
    required this.onEmailUpdated,
  }) : super(key: key);

  @override
  State<EditEmailDialog> createState() => _EditEmailDialogState();
}

class _EditEmailDialogState extends State<EditEmailDialog> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.currentEmail);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updateEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Basic validation
    if (email.isEmpty || !email.contains("@")) {
      setState(() => _errorMessage = "Please enter a valid email address");
      return;
    }

    if (password.isEmpty) {
      setState(
          () => _errorMessage = "Current password is required to change email");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider =
          Provider.of<AuthStateProvider>(context, listen: false);
      final success = await authProvider.updateProfile(email: email);

      if (success) {
        widget.onEmailUpdated(email);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email updated successfully")),
        );
      } else {
        setState(() => _errorMessage =
            authProvider.errorMessage ?? "Failed to update email");
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to update email: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
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
                  "Edit Email",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                "Enter your new email address",
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

              // Email field
              TextField(
                controller: _emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "New Email",
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

              // Current password field
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Current Password",
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
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
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
                        "Cancel",
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
                      onPressed: _isLoading ? null : _updateEmail,
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
                              "Update",
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
      ),
    );
  }

  void _showFocusSessionsDialog() async {
    try {
      final appController = context.read<PushinAppController>();
      final focusModeService = appController.focusModeService;

      if (focusModeService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen Time service not available')),
        );
        return;
      }

      // Check authorization first
      if (focusModeService.authorizationStatus !=
          AuthorizationStatus.authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enable Screen Time access first')),
        );
        return;
      }

      // Open the picker directly
      final result = await focusModeService.presentAppPicker();

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Updated blocked apps (${result.totalSelected} selected)'),
            backgroundColor: EnhancedSettingsDesignTokens.primaryPurple,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open app picker')),
        );
      }
    }
  }
}

/// Change Password Dialog Widget
class ChangePasswordDialog extends StatefulWidget {
  final VoidCallback onPasswordUpdated;

  const ChangePasswordDialog({
    Key? key,
    required this.onPasswordUpdated,
  }) : super(key: key);

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Basic validation
    if (currentPassword.isEmpty) {
      setState(() => _errorMessage = "Current password is required");
      return;
    }

    if (newPassword.isEmpty) {
      setState(() => _errorMessage = "New password is required");
      return;
    }

    if (newPassword.length < 6) {
      setState(
          () => _errorMessage = "New password must be at least 6 characters");
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = "New passwords do not match");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider =
          Provider.of<AuthStateProvider>(context, listen: false);
      final success = await authProvider.updateProfile(password: newPassword);

      if (success) {
        widget.onPasswordUpdated();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated successfully")),
        );
      } else {
        setState(() => _errorMessage =
            authProvider.errorMessage ?? "Failed to update password");
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to update password: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
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
                  "Change Password",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                "Enter your new password",
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

              // Current password field
              TextField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Current Password",
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
                      _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // New password field
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "New Password",
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
                      _obscureNew ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm password field
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Confirm New Password",
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
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
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
                        "Cancel",
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
                      onPressed: _isLoading ? null : _updatePassword,
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
                              "Update",
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
      ),
    );
  }

  void _showFocusSessionsDialog() async {
    try {
      final appController = context.read<PushinAppController>();
      final focusModeService = appController.focusModeService;

      if (focusModeService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Screen Time service not available')),
        );
        return;
      }

      // Check authorization first
      if (focusModeService.authorizationStatus !=
          AuthorizationStatus.authorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enable Screen Time access first')),
        );
        return;
      }

      // Open the picker directly
      final result = await focusModeService.presentAppPicker();

      if (result != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Updated blocked apps (${result.totalSelected} selected)'),
            backgroundColor: EnhancedSettingsDesignTokens.primaryPurple,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open app picker')),
        );
      }
    }
  }
}
