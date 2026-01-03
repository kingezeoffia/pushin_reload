import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../theme/pushin_theme.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../state/auth_state_provider.dart';
import 'HowItWorksExerciseScreen.dart';

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

      // Request permission and immediately show picker
      await focusModeService.requestScreenTimePermission();

      // Present native FamilyActivityPicker
      final selectionResult = await focusModeService.presentAppPicker();

      if (selectionResult != null && selectionResult.totalSelected > 0) {
        // Permission granted and apps selected - advance onboarding
        final authProvider = context.read<AuthStateProvider>();
        authProvider.advanceOnboardingStep();

        // Navigate to next screen
        if (mounted) {
          Navigator.push(
            context,
            _NoSwipeBackRoute(
              builder: (context) => HowItWorksExerciseScreen(
                fitnessLevel: widget.fitnessLevel,
                goals: widget.goals,
                otherGoal: widget.otherGoal,
                workoutHistory: widget.workoutHistory,
                blockedApps: [], // No longer needed - tokens are persisted in service
              ),
            ),
          );
        }
      } else {
        // User cancelled or no apps selected
        setState(() {
          _errorMessage = 'Please select at least one app to continue';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Screen Time access is required. Please try again.';
      });
      debugPrint('❌ Screen Time setup failed: $e');
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
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Indicator
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: Row(
                  children: [
                    const Spacer(),
                    _StepIndicator(currentStep: 1, totalSteps: 5),
                  ],
                ),
              ),

              // Consistent spacing with other screens
              SizedBox(height: MediaQuery.of(context).size.height * 0.04),

              // Heading - consistent positioning
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Block',
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
                        'Distracting Apps',
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

              // Spacer to center the button
              const Spacer(),

              // Main CTA Button
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                child: _AllowAndSelectButton(
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  onTap: _handleAllowAndSelectApps,
                ),
              ),
            ],
          ),
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

        // Subtitle
        const SizedBox(height: 16),
        Text(
          'Grant Screen Time access and choose which apps to block',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.6),
            letterSpacing: -0.1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Step indicator widget
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'Step $currentStep of $totalSteps',
        style: PushinTheme.stepIndicatorText.copyWith(
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }
}


