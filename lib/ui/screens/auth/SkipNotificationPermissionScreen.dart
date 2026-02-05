import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';
import '../../../state/auth_state_provider.dart';
import '../../../services/NotificationService.dart';
import 'SkipBlockAppsScreen.dart';

/// Skip Flow: Allow Notifications
///
/// Context-free version for users who skip onboarding (Guest Mode)
/// Requests notification permissions before app blocking setup.
class SkipNotificationPermissionScreen extends StatefulWidget {
  const SkipNotificationPermissionScreen({super.key});

  @override
  State<SkipNotificationPermissionScreen> createState() =>
      _SkipNotificationPermissionScreenState();
}

class _SkipNotificationPermissionScreenState
    extends State<SkipNotificationPermissionScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleAllowNotifications() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notificationService = NotificationService();
      
      // Request notification permissions
      final granted = await notificationService.requestPermissions();
      
      debugPrint('📱 Guest Notification permissions granted: $granted');

      // Save permission status (even for guest)
      final authProvider = context.read<AuthStateProvider>();
      await authProvider.markNotificationPermissionRequested();

      // Advance guest setup - AppRouter will detect this and show next screen
      authProvider.advanceGuestSetupStep();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to request permissions. Please try again.';
      });
      debugPrint('❌ Guest notification permission request failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
              'Required for automatic app unlocking before workouts',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
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
          onTap: _handleAllowNotifications,
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
                  SizedBox(height: MediaQuery.of(context).size.height * 0.04),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

                  const Spacer(),
                ],
              ),
            ),

            BottomActionContainer(
              child: _buildBottomSection(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllowNotificationsButton extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTap;

  const _AllowNotificationsButton({
    required this.onTap,
    required this.isLoading,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                      child: const Text('Allow Notifications'),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

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
