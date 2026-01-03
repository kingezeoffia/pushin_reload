import 'package:flutter/material.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../auth/SkipBlockAppsScreen.dart';

/// Skip Onboarding Explainer Screen
///
/// BMAD V6 Spec:
/// - Shown when user explicitly skips onboarding questions
/// - Single clean page explaining why onboarding exists
/// - Explains what Pushin helps with
/// - Same visual system and button style as onboarding
/// - Continue button navigates to app selection/block list screen
class SkipOnboardingExplainerScreen extends StatelessWidget {
  const SkipOnboardingExplainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Column(
            children: [
              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: screenHeight * 0.12),

                      // Back Button
                      _BackButton(onTap: () => Navigator.pop(context)),

                      SizedBox(height: screenHeight * 0.08),

                      // Main content
                      Center(
                        child: Column(
                          children: [
                            // Title
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.white, Color(0xFFB0B8FF)],
                              ).createShader(
                                Rect.fromLTWH(
                                    0, 0, bounds.width, bounds.height * 1.3),
                              ),
                              blendMode: BlendMode.srcIn,
                              child: const Text(
                                'Why We Ask Questions',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.04),

                            // Explanation content
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Icon
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.psychology,
                                      color: Color(0xFF8080FF),
                                      size: 32,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Explanation text
                                  Text(
                                    'Onboarding helps us personalize your Pushin experience to match your fitness level and goals. This ensures you get the right workout challenges and screen time rewards that will actually motivate you.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.9),
                                      letterSpacing: -0.1,
                                      height: 1.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),

                                  const SizedBox(height: 16),

                                  // What Pushin helps with
                                  Text(
                                    'Pushin helps you build discipline by connecting physical effort with digital rewards. The more you work out, the more screen time you earn.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withOpacity(0.7),
                                      letterSpacing: -0.1,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: screenHeight * 0.02),

                            // Optional note
                            Text(
                              'You can always update these preferences later in settings.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.6),
                                letterSpacing: -0.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Fixed bottom CTA button
              Padding(
                padding: const EdgeInsets.all(32),
                child: _ContinueButton(
                  onTap: () => _handleContinue(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleContinue(BuildContext context) {
    // Navigate to app selection/block list screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const SkipBlockAppsScreen(),
      ),
    );
  }
}

/// Back button widget
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

/// Continue button with press animation
class _ContinueButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContinueButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Continue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A2A6A),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}












