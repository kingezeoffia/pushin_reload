import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../state/auth_state_provider.dart';
import '../../../services/NotificationService.dart';
import 'HowItWorksBlockAppsScreen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/pill_navigation_bar.dart';


/// Custom route that disables swipe back gesture on iOS
class _NoSwipeBackRoute<T> extends MaterialPageRoute<T> {
  _NoSwipeBackRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(builder: builder, settings: settings);

  @override
  bool get hasScopedWillPopCallback => true;

  @override
  bool get canPop => false;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // Disable the default iOS swipe back transition
    return child;
  }
}

/// Step: Allow Notifications
///
/// Onboarding step that requests notification permissions.
/// Positioned before "Block Your Apps" to educate users about
/// the critical role of notifications in the app unlocking mechanism.
class HowItWorksNotificationPermissionScreen extends StatefulWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;
  final String workoutHistory;
  final bool isReturningUser;

  const HowItWorksNotificationPermissionScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
    required this.workoutHistory,
    this.isReturningUser = false,
  });

  @override
  State<HowItWorksNotificationPermissionScreen> createState() =>
      _HowItWorksNotificationPermissionScreenState();
}

class _HowItWorksNotificationPermissionScreenState
    extends State<HowItWorksNotificationPermissionScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  String? _errorMessage;
  bool _showSettingsPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-check permissions when user comes back to the app
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - checking notification permissions automatically');
      _checkAndProceedIfGranted();
    }
  }

  /// Checks if permission is granted and proceeds if so.
  /// Returns true if granted, false otherwise.
  Future<bool> _checkAndProceedIfGranted() async {
    final notificationService = NotificationService();
    final bool isGranted = await notificationService.areNotificationsEnabled();

    if (isGranted) {
      if (mounted) {
        // Proceed silently if already granted
        _proceedToNextStep();
      }
      return true;
    }
    return false;
  }

  Future<void> _proceedToNextStep() async {
    // Mark permission requested (flow complete)
    final authProvider = context.read<AuthStateProvider>();
    await authProvider.markNotificationPermissionRequested();

    // If returning user, we don't advance onboarding step or push new route
    // The state update above will trigger the router to show the home screen
    if (widget.isReturningUser) {
      debugPrint('🔄 Returning user granted permissions - Router will update to Home');
      return;
    }

    // Normal onboarding flow
    debugPrint('🔄 HowItWorksNotificationPermissionScreen: Advancing step...');
    authProvider.advanceOnboardingStep();
  }

  Future<void> _handleAllowNotifications() async {
    if (_isLoading) return; // Prevent multiple rapid taps

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notificationService = NotificationService();
      
      // First check if already granted
      final bool alreadyGranted = await notificationService.areNotificationsEnabled();
      if (alreadyGranted) {
        await _proceedToNextStep();
        return;
      }

      // Request notification permissions
      // We use requestPermissions from NotificationService which handles platform specifics
      final bool granted = await notificationService.requestPermissions();
      
      debugPrint('📱 Notification permissions result: $granted');

      if (granted) {
        await _proceedToNextStep();
      } else {
        // Permission denied (possibly permanently)
        // Check if we should guide to settings
        // If requestPermissions returns false, it might mean user denied it previously
        
        setState(() {
          _errorMessage = 'Notifications are required to continue.';
          _showSettingsPrompt = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to request permissions. Please try again.';
      });
      debugPrint('❌ Notification permission request failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _openAppSettings() async {
    await openAppSettings();
    // The didChangeAppLifecycleState will handle checking when they return
  }

  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Subtitle text - above button
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              _showSettingsPrompt 
                  ? 'Please enable notifications in settings to continue'
                  : 'Required for automatic app unlocking before workouts',
              style: TextStyle(
                fontSize: 12,
                color: _showSettingsPrompt ? Colors.orangeAccent : Colors.white.withOpacity(0.6),
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Main CTA Button
        _AllowNotificationsButton(
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          onTap: _showSettingsPrompt ? _openAppSettings : _handleAllowNotifications,
          label: _showSettingsPrompt ? 'Open Settings' : 'Allow Notifications',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Consistent spacing with other screens
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),

                  // Heading - consistent positioning
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bell icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB800).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            size: 40,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Allow',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.05,
                            letterSpacing: -1,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFFB800), Color(0xFFFFD700)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                              decoration: TextDecoration.none,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Critical for automatic app unlocking',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.6),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),

                  // Value Proposition Points
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        _ValuePoint(
                          icon: Icons.vpn_key_rounded,
                          title: 'Automatic Unlocking',
                          description: 'Apps unlock automatically after you complete your workout',
                        ),
                        SizedBox(height: 16),
                        _ValuePoint(
                          icon: Icons.notifications_rounded,
                          title: 'Workout Reminders',
                          description: 'Get notified when it\'s time to unlock your apps',
                        ),
                        SizedBox(height: 16),
                        _ValuePoint(
                          icon: Icons.shield_rounded,
                          title: 'Stay Accountable',
                          description: 'Notifications keep you on track with your fitness goals',
                        ),
                      ],
                    ),
                  ),

                  // Spacer to push content up (button will be positioned at bottom)
                  const Spacer(),
                ],
              ),
            ),

            // Bottom section with button and subtitle
            BottomActionContainer(
              child: _buildBottomSection(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main CTA Button for notification permissions
class _AllowNotificationsButton extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTap;
  final String label;

  const _AllowNotificationsButton({
    required this.onTap,
    required this.isLoading,
    this.errorMessage,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Error message if present
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        // Main CTA Button
        PressAnimationButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: isLoading
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(100),
              boxShadow: isLoading
                  ? null
                  : [
                      BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                    ],
            ),
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isLoading
                            ? Colors.white.withOpacity(0.4)
                            : const Color(0xFF2A2A6A),
                        letterSpacing: -0.3,
                      ),
                      child: Text(label),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Value proposition point widget with title and description
class _ValuePoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ValuePoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFFFFB800).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFD700),
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
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
