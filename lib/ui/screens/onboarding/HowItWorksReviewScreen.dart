import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../paywall/PaywallScreen.dart';

/// Step 5: Reviews
///
/// BMAD V6 Spec:
/// - Simple review UI
/// - Star rating (1-5)
/// - Optional text field below for written feedback
class HowItWorksReviewScreen extends StatefulWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;
  final String workoutHistory;
  final List<String> blockedApps;
  final String selectedWorkout;
  final int unlockDuration;

  const HowItWorksReviewScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
    required this.workoutHistory,
    required this.blockedApps,
    required this.selectedWorkout,
    required this.unlockDuration,
  });

  @override
  State<HowItWorksReviewScreen> createState() => _HowItWorksReviewScreenState();
}

class _HowItWorksReviewScreenState extends State<HowItWorksReviewScreen> {
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button & Step Indicator
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16, top: 8),
                child: Row(
                  children: [
                    _BackButton(onTap: () => Navigator.pop(context)),
                    const Spacer(),
                    _StepIndicator(currentStep: 6, totalSteps: 6),
                  ],
                ),
              ),

              // Consistent spacing with other screens
              SizedBox(height: screenHeight * 0.08),

              // Heading - consistent positioning
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How was',
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
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'your experience?',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Help us improve PUSHIN' with your feedback",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.04),

              // Star Rating
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate your setup experience',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(5, (index) {
                        final starNumber = index + 1;
                        final isSelected = starNumber <= _rating;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _rating = starNumber);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AnimatedScale(
                              scale: isSelected ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                isSelected ? Icons.star : Icons.star_border,
                                size: 48,
                                color: isSelected
                                    ? const Color(0xFFFFD700)
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.04),

              // Feedback Text Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Additional feedback (optional)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        // NO border - flat modern design
                      ),
                      child: TextField(
                        controller: _feedbackController,
                        maxLines: 4,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tell us what you think...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Continue Button
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    _ContinueButton(
                      enabled: _rating > 0,
                      onTap: () {
                        // TODO: Save feedback
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaywallScreen(
                              onboardingData: {
                                'fitnessLevel': widget.fitnessLevel,
                                'goals': widget.goals,
                                'otherGoal': widget.otherGoal,
                                'workoutHistory': widget.workoutHistory,
                                'blockedApps': widget.blockedApps,
                                'selectedWorkout': widget.selectedWorkout,
                                'unlockDuration': widget.unlockDuration,
                                'rating': _rating,
                                'feedback': _feedbackController.text,
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        // Skip feedback
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaywallScreen(
                              onboardingData: {
                                'fitnessLevel': widget.fitnessLevel,
                                'goals': widget.goals,
                                'otherGoal': widget.otherGoal,
                                'workoutHistory': widget.workoutHistory,
                                'blockedApps': widget.blockedApps,
                                'selectedWorkout': widget.selectedWorkout,
                                'unlockDuration': widget.unlockDuration,
                              },
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Continue with the free plan',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
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
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }
}

/// Back Button Widget
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

/// Continue Button Widget
class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.95)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(100),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? const Color(0xFF2A2A6A)
                  : Colors.white.withOpacity(0.4),
              letterSpacing: -0.3,
            ),
            child: const Text('Submit & Continue'),
          ),
        ),
      ),
    );
  }
}
