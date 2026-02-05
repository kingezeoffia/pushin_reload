import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/auth_state_provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';

/// Skip Flow: Block Distracting Apps
///
/// Context-free version for users who skip onboarding
/// Uses native Screen Time picker instead of mock app list
class SkipBlockAppsScreen extends StatefulWidget {
  const SkipBlockAppsScreen({super.key});

  @override
  State<SkipBlockAppsScreen> createState() => _SkipBlockAppsScreenState();
}

class _SkipBlockAppsScreenState extends State<SkipBlockAppsScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleAllowAndSelectApps() async {
    if (_isLoading) return; // Prevent multiple rapid taps

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appController = context.read<PushinAppController>();
      try {
        // Use the controller's method which properly saves tokens
        debugPrint('🍎 SkipBlockAppsScreen: Presenting iOS app picker (with 60s timeout)...');
        final success = await appController.presentIOSAppPicker().timeout(
          const Duration(seconds: 60),
          onTimeout: () {
            debugPrint('⏳ SkipBlockAppsScreen: App picker timed out');
            return false;
          },
        );
        
        debugPrint('✅ SkipBlockAppsScreen: App selection result (success: $success)');
      } catch (e) {
        debugPrint('⚠️ SkipBlockAppsScreen: Screen Time setup failed (non-fatal): $e');
        // Proceed anyway
      }

      // Always advance guest setup regardless of app selection
      if (mounted) {
        final authProvider = context.read<AuthStateProvider>();
        
        // Sync blocked apps to AuthStateProvider for router access
        debugPrint('🔄 SkipBlockAppsScreen: Syncing blocked apps to AuthProvider...');
        final currentApps = appController.iosAppTokens;
        authProvider.setBlockedApps(currentApps);
        
        debugPrint('🔄 SkipBlockAppsScreen: Advancing guest setup step...');
        debugPrint('   - Current step: ${authProvider.guestSetupStep}');
        authProvider.advanceGuestSetupStep();
        debugPrint('✅ SkipBlockAppsScreen: Advanced called. New step: ${authProvider.guestSetupStep}');
      }
    } catch (e) {
      // Only critical errors block here
      setState(() {
         // Keep generic error if critical
         _errorMessage = 'Screen Time access is required. Please try again.';
      });
      debugPrint('❌ Critical error in SkipBlockApps: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                        // Block apps icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6060FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.block_rounded,
                            size: 40,
                            color: Color(0xFF9090FF),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Block Your',
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
                            colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            'Apps',
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
                          'Choose which apps to block before workout',
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
                          icon: Icons.lock_rounded,
                          text: 'Block distracting apps',
                        ),
                        SizedBox(height: 16),
                        _ValuePoint(
                          icon: Icons.psychology,
                          text: 'Stay focused on what matters',
                        ),
                        SizedBox(height: 16),
                        _ValuePoint(
                          icon: Icons.phone_android,
                          text: 'Break your scrolling habits',
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
              'Grant Screen Time access and choose apps to block',
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
        _AllowAndSelectButton(
          onTap: _handleAllowAndSelectApps,
          isLoading: _isLoading,
          errorMessage: _errorMessage,
        ),
      ],
    );
  }
}

/// Main CTA Button for Screen Time permission + picker
class _AllowAndSelectButton extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTap;

  const _AllowAndSelectButton({
    required this.onTap,
    required this.isLoading,
    this.errorMessage,
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
                      child: const Text('Allow & Select Apps'),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Value proposition point widget - styled like emergency unlock
class _ValuePoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ValuePoint({
    required this.icon,
    required this.text,
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
              color: const Color(0xFF6060FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF9090FF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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











