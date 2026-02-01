import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../theme/pushin_theme.dart';

/// Manage Apps Screen - Select which apps to block
///
/// Design:
/// - iOS: Uses Apple's Family Activity Picker for app selection
/// - Android: Shows toggle list of common distracting apps
/// - Visual indication of selected apps
/// - Platform-specific permission handling
///
/// Integrates with PushinAppController to persist blocked apps
class ManageAppsScreen extends StatefulWidget {
  const ManageAppsScreen({super.key});

  @override
  State<ManageAppsScreen> createState() => _ManageAppsScreenState();
}

class _ManageAppsScreenState extends State<ManageAppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRequestingPermission = false;
  bool _isOpeningPicker = false;
  bool _hasOverlayPermission = false;
  bool _isCheckingPermission = true;

  // Available apps to block (common distracting apps) - Android only
  late List<AppItem> _apps;

  @override
  void initState() {
    super.initState();
    if (!_isIOS) {
      _initializeApps();
      _checkOverlayPermission();
    } else {
      _isCheckingPermission = false;
    }
  }

  Future<void> _checkOverlayPermission() async {
    final controller = context.read<PushinAppController>();
    final hasPermission = await controller.hasOverlayPermission();
    if (mounted) {
      setState(() {
        _hasOverlayPermission = hasPermission;
        _isCheckingPermission = false;
      });
    }
  }

  Future<void> _requestOverlayPermission() async {
    final controller = context.read<PushinAppController>();
    await controller.requestOverlayPermission();

    // Show a snackbar explaining next steps
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Enable "Display over other apps" for PUSHIN, then return here'),
          backgroundColor: PushinTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  void _initializeApps() {
    final controller = context.read<PushinAppController>();
    final blockedApps = controller.blockedApps;

    // Initialize with common distracting apps
    _apps = [
      AppItem(
          name: 'Instagram',
          packageName: 'com.instagram.android',
          icon: Icons.photo_camera,
          isBlocked: blockedApps.contains('com.instagram.android'),
          category: 'Social'),
      AppItem(
          name: 'TikTok',
          packageName: 'com.zhiliaoapp.musically',
          icon: Icons.music_note,
          isBlocked: blockedApps.contains('com.zhiliaoapp.musically'),
          category: 'Social'),
      AppItem(
          name: 'Twitter',
          packageName: 'com.twitter.android',
          icon: Icons.tag,
          isBlocked: blockedApps.contains('com.twitter.android'),
          category: 'Social'),
      AppItem(
          name: 'Facebook',
          packageName: 'com.facebook.katana',
          icon: Icons.facebook,
          isBlocked: blockedApps.contains('com.facebook.katana'),
          category: 'Social'),
      AppItem(
          name: 'YouTube',
          packageName: 'com.google.android.youtube',
          icon: Icons.play_circle,
          isBlocked: blockedApps.contains('com.google.android.youtube'),
          category: 'Entertainment'),
      AppItem(
          name: 'Figma',
          packageName: 'com.figma.mirror',
          icon: Icons.design_services,
          isBlocked: blockedApps.contains('com.figma.mirror'),
          category: 'Productivity'),
      AppItem(
          name: 'Reddit',
          packageName: 'com.reddit.frontpage',
          icon: Icons.forum,
          isBlocked: blockedApps.contains('com.reddit.frontpage'),
          category: 'Social'),
      AppItem(
          name: 'Snapchat',
          packageName: 'com.snapchat.android',
          icon: Icons.chat,
          isBlocked: blockedApps.contains('com.snapchat.android'),
          category: 'Social'),
      AppItem(
          name: 'WhatsApp',
          packageName: 'com.whatsapp',
          icon: Icons.message,
          isBlocked: blockedApps.contains('com.whatsapp'),
          category: 'Communication'),
      AppItem(
          name: 'Telegram',
          packageName: 'org.telegram.messenger',
          icon: Icons.send,
          isBlocked: blockedApps.contains('org.telegram.messenger'),
          category: 'Communication'),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppItem> get _filteredApps {
    if (_searchQuery.isEmpty) {
      return _apps;
    }
    return _apps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<AppItem> get _blockedApps {
    return _apps.where((app) => app.isBlocked).toList();
  }

  Future<void> _toggleApp(AppItem app, bool value) async {
    HapticFeedback.lightImpact();
    setState(() {
      app.isBlocked = value;
    });

    // Update the controller with the new blocked apps list
    final controller = context.read<PushinAppController>();
    final blockedPackageNames =
        _apps.where((a) => a.isBlocked).map((a) => a.packageName).toList();

    await controller.updateBlockedApps(blockedPackageNames);
  }

  /// Request Screen Time permission (iOS only)
  Future<void> _requestScreenTimePermission() async {
    if (!_isIOS) return;

    setState(() => _isRequestingPermission = true);

    try {
      final controller = context.read<PushinAppController>();
      await controller.requestPlatformPermissions();
    } finally {
      if (mounted) {
        setState(() => _isRequestingPermission = false);
      }
    }
  }

  /// Open iOS Family Activity Picker
  Future<void> _openIOSAppPicker() async {
    if (!_isIOS) return;

    setState(() => _isOpeningPicker = true);

    try {
      final controller = context.read<PushinAppController>();
      final success = await controller.presentIOSAppPicker();

      if (success && mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Apps selected for blocking'),
            backgroundColor: PushinTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else if (mounted) {
        // Show error message if permission was denied or picker failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Screen Time access is required to block apps'),
            backgroundColor: PushinTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningPicker = false);
      }
    }
  }

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
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Manage Blocked Apps',
                        style: PushinTheme.appsText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance back button
                  ],
                ),
              ),

              // Platform-specific content
              Expanded(
                child: _isIOS ? _buildIOSContent() : _buildAndroidContent(),
              ),

              // Bottom Info
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: PushinTheme.surfaceDark.withValues(alpha: 0.6),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: PushinTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isIOS
                            ? 'Complete a workout to unblock apps'
                            : 'Blocked apps require a workout to access',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build iOS-specific content with Screen Time integration
  Widget _buildIOSContent() {
    return Consumer<PushinAppController>(
      builder: (context, controller, _) {
        final hasTokens = controller.hasIOSBlockingConfigured;
        final focusService = controller.focusModeService;
        final isAuthorized = focusService?.isAuthorized ?? false;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: hasTokens
                      ? PushinTheme.primaryGradient
                      : LinearGradient(
                          colors: [
                            Colors.orange.withValues(alpha: 0.3),
                            Colors.orange.withValues(alpha: 0.1),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasTokens ? Icons.check_circle : Icons.warning_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasTokens ? 'Apps configured' : 'Setup required',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasTokens
                                ? 'Screen Time blocking is ready'
                                : 'Select apps to block via Screen Time',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Screen Time Permission Section
              if (!isAuthorized) ...[
                _buildSectionTitle('Step 1: Grant Permission'),
                const SizedBox(height: 12),
                _buildActionCard(
                  icon: Icons.security,
                  title: 'Screen Time Access',
                  description: 'Allow PUSHIN to manage app restrictions',
                  buttonText: _isRequestingPermission
                      ? 'Requesting...'
                      : 'Grant Access',
                  onPressed: _isRequestingPermission
                      ? null
                      : _requestScreenTimePermission,
                  isLoading: _isRequestingPermission,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('Step 2: Select Apps'),
              ] else ...[
                _buildSectionTitle('Select Apps to Block'),
              ],

              const SizedBox(height: 12),

              // Family Activity Picker Button
              _buildActionCard(
                icon: Icons.apps,
                title: 'Choose Apps',
                description:
                    'Open Apple\'s app picker to select which apps to block',
                buttonText: _isOpeningPicker ? 'Opening...' : 'Select Apps',
                onPressed: !_isOpeningPicker ? _openIOSAppPicker : null,
                isLoading: _isOpeningPicker,
                isPrimary: true,
              ),

              const SizedBox(height: 32),

              // How it works section
              _buildSectionTitle('How it works'),
              const SizedBox(height: 16),
              _RuleItem(
                icon: Icons.fitness_center,
                title: 'Complete workout',
                description: 'Do your required push-ups or exercises',
              ),
              const SizedBox(height: 16),
              _RuleItem(
                icon: Icons.lock_open,
                title: 'Apps unblock',
                description: 'Selected apps become accessible for earned time',
              ),
              const SizedBox(height: 16),
              _RuleItem(
                icon: Icons.timer,
                title: 'Time expires',
                description: 'Apps automatically re-block when time runs out',
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.9),
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool isPrimary = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PushinTheme.surfaceDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PushinTheme.primaryBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: PushinTheme.primaryBlue,
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
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPrimary
                    ? PushinTheme.primaryBlue
                    : Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _RuleItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: PushinTheme.primaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: PushinTheme.primaryBlue,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build Android-specific content with toggle list
  Widget _buildAndroidContent() {
    // Show loading while checking permission
    if (_isCheckingPermission) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Column(
      children: [
        // Overlay Permission Card (if not granted)
        if (!_hasOverlayPermission) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.4),
                    Colors.orange.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.orange.shade300,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Permission Required',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'To block apps when you exit PUSHIN, we need permission to display over other apps.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _requestOverlayPermission,
                      icon: const Icon(Icons.settings),
                      label: const Text('Grant Permission'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _checkOverlayPermission,
                    child: Text(
                      'I already enabled it - check again',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Summary Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: _hasOverlayPermission
                  ? PushinTheme.primaryGradient
                  : LinearGradient(
                      colors: [
                        Colors.grey.withValues(alpha: 0.3),
                        Colors.grey.withValues(alpha: 0.1),
                      ],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _hasOverlayPermission
                  ? [
                      BoxShadow(
                        color: PushinTheme.primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  _hasOverlayPermission ? Icons.block : Icons.block_outlined,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_blockedApps.length} apps blocked',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _hasOverlayPermission
                            ? 'Blocking active - requires workout to access'
                            : 'Grant permission above to enable blocking',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search apps...',
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: PushinTheme.surfaceDark.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Apps List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _filteredApps.length,
            itemBuilder: (context, index) {
              final app = _filteredApps[index];
              return _AppTile(
                app: app,
                onToggle: (value) => _toggleApp(app, value),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// App Tile Widget
class _AppTile extends StatelessWidget {
  final AppItem app;
  final ValueChanged<bool> onToggle;

  const _AppTile({
    required this.app,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: app.isBlocked
            ? PushinTheme.primaryBlue.withOpacity(0.1)
            : PushinTheme.surfaceDark.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: app.isBlocked
            ? Border.all(
                color: PushinTheme.primaryBlue.withOpacity(0.3),
                width: 1.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onToggle(!app.isBlocked),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // App Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    app.icon,
                    color: _getCategoryColor(),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // App Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.category,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Toggle Switch
                Switch(
                  value: app.isBlocked,
                  onChanged: onToggle,
                  activeColor: PushinTheme.primaryBlue,
                  activeTrackColor: PushinTheme.primaryBlue.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (app.category) {
      case 'Social':
        return PushinTheme.primaryBlue;
      case 'Entertainment':
        return PushinTheme.errorRed;
      case 'Communication':
        return PushinTheme.successGreen;
      default:
        return PushinTheme.textSecondary;
    }
  }
}

/// App Item Model
class AppItem {
  final String name;
  final String packageName;
  final IconData icon;
  final String category;
  bool isBlocked;

  AppItem({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.category,
    required this.isBlocked,
  });
}
