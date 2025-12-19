import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../../services/AuthStateProvider.dart';

/// New User Welcome Screen - Personalized welcome for newly registered users
///
/// BMAD V6 Spec:
/// - ONLY shown after successful registration (not login)
/// - NEVER shown more than once per user
/// - Personalized with user's firstname
/// - Same visual system as onboarding screens
/// - Clean, premium, minimal design
class NewUserWelcomeScreen extends StatelessWidget {
  final VoidCallback? onWelcomeCompleted;

  const NewUserWelcomeScreen({
    super.key,
    this.onWelcomeCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final authProvider = Provider.of<AuthStateProvider>(context);
    final user = authProvider.currentUser;

    // Get user's firstname or use fallback
    final firstname = user?.firstname?.trim();
    final displayName = (firstname != null && firstname.isNotEmpty)
        ? firstname
        : null; // Will show fallback message

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
                      SizedBox(height: screenHeight * 0.15),

                      // Personalized welcome message
                      Center(
                        child: Column(
                          children: [
                            // Main headline
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.white, Color(0xFFB0B8FF)],
                              ).createShader(
                                Rect.fromLTWH(
                                    0, 0, bounds.width, bounds.height * 1.3),
                              ),
                              blendMode: BlendMode.srcIn,
                              child: const Text(
                                'Welcome to the Family,',
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

                            SizedBox(height: screenHeight * 0.03),

                            // User's firstname (only show if exists)
                            displayName != null
                                ? ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [
                                        Color(0xFF6060FF),
                                        Color(0xFF9090FF)
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ).createShader(
                                      Rect.fromLTWH(0, 0, bounds.width,
                                          bounds.height * 1.3),
                                    ),
                                    blendMode: BlendMode.srcIn,
                                    child: Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                        height: 1.1,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : const SizedBox.shrink(),

                            SizedBox(height: screenHeight * 0.04),

                            // Warm intro text
                            Text(
                              'You\'re now part of a community committed to building healthier digital habits. Let\'s get you set up!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: -0.2,
                                height: 1.4,
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
    // Call completion callback (clears justRegistered flag and triggers AppRouter rebuild)
    onWelcomeCompleted?.call();
    // Navigation is handled automatically by AppRouter when justRegistered flag is cleared
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
