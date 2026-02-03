import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../state/auth_state_provider.dart';
import 'HowItWorksChooseWorkoutScreen.dart';

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

/// Step: Block Distracting Apps
///
/// Onboarding step that requests Screen Time permission and
/// immediately presents FamilyActivityPicker for app selection.
/// No UI lists or previews - pure native iOS experience.
class HowItWorksBlockAppsScreen extends StatefulWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;
  final String workoutHistory;

  const HowItWorksBlockAppsScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
    required this.workoutHistory,
  });

  @override
  State<HowItWorksBlockAppsScreen> createState() =>
      _HowItWorksBlockAppsScreenState();
}

class _HowItWorksBlockAppsScreenState extends State<HowItWorksBlockAppsScreen> {
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
      final focusModeService = appController.focusModeService;

      if (focusModeService == null) {
        throw Exception('Focus mode service not available');
      }

      // Present native FamilyActivityPicker
        try {
          await focusModeService.requestScreenTimePermission().timeout(const Duration(seconds: 5));
          
          debugPrint('🍎 HowItWorksBlockAppsScreen: Presenting app picker (with 60s timeout)...');
          final selectionResult = await focusModeService.presentAppPicker().timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              debugPrint('⏳ HowItWorksBlockAppsScreen: App picker timed out');
              return null; // Return null so we can proceed
            },
          );
          
          // Save the selected apps to the controller
          final appTokens = selectionResult?.appTokens ?? [];
          debugPrint('✅ HowItWorksBlockAppsScreen: Selection result: ${appTokens.length} apps');
          await appController.updateBlockedApps(appTokens);
          
          // Also update auth provider for navigation state
          final authProvider = context.read<AuthStateProvider>();
          authProvider.setBlockedApps(appTokens);
        } catch (e) {
          debugPrint('⚠️ HowItWorksBlockAppsScreen: Screen Time setup failed (non-fatal): $e');
          // Proceed even if picker fails (e.g. on Simulator or due to XPC crash)
        }

      // Always advance onboarding regardless of app selection success
      if (mounted) {
        final authProvider = context.read<AuthStateProvider>();
        debugPrint('🚀 HowItWorksBlockAppsScreen: Advancing onboarding step...');
        authProvider.advanceOnboardingStep();
        debugPrint('✅ HowItWorksBlockAppsScreen: Onboarding step advanced to: ${authProvider.onboardingStep}');
      }
    } catch (e) {
      // Only critical errors that prevent proceeding block here
      // But we try to proceed as much as possible above
      setState(() {
        _errorMessage = 'Screen Time access is required. Please try again.';
      });
      debugPrint('❌ HowItWorksBlockAppsScreen: Screen Time setup critical error: $e');
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
          isLoading: _isLoading,
          errorMessage: _errorMessage,
          onTap: _handleAllowAndSelectApps,
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
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
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
                              fontFamily: 'Inter', // Explicit font family
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
                          icon: Icons.block,
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
