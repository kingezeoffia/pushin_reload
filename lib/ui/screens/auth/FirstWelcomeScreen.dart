import 'package:flutter/material.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';
import 'SignUpScreen.dart';
import 'SignInScreen.dart';

/// First Welcome Screen - For users accessing from settings (sign up/logout)
///
/// Shows Sign Up and Sign In buttons (no Continue as Guest option)
/// Used when:
/// - User presses green sign up button in settings
/// - User presses red logout button in settings
class FirstWelcomeScreen extends StatelessWidget {
  const FirstWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Stack(
            children: [
              // Scrollable content area
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo Space - PNG logo (approximately 1/2 of screen)
                    SizedBox(
                      height: screenHeight * 0.5,
                      child: Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFB0B8FF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: Image.asset(
                            'assets/icons/pushin_logo_2.png',
                            width: 320,
                            height: 320,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // Spacer to push title down towards buttons
                    SizedBox(height: screenHeight * 0.15),

                    // Welcome Title (left-aligned)
                    const Text(
                      'Welcome to',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                        letterSpacing: -0.5,
                      ),
                    ),

                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, Color(0xFFB0B8FF)],
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        "PUSHIN'",
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                    ),

                    // Add spacing at bottom to prevent content from being hidden by buttons
                    const SizedBox(height: 200),
                  ],
                ),
              ),

              // Fixed bottom buttons - Sign Up and Sign In (no Continue as Guest)
              BottomActionContainer(
                child: Column(
                  children: [
                    // Sign Up Button
                    _PrimaryButton(
                      label: 'Sign Up',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Sign In Button
                    _SecondaryButton(
                      label: 'Sign In',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignInScreen(),
                          ),
                        );
                      },
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

/// Primary action button with press animation
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
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
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
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

/// Secondary button for sign in
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
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
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}
