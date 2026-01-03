import 'package:flutter/material.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'SignUpScreen.dart';
import 'package:provider/provider.dart';
import '../../../state/auth_state_provider.dart';

/// First Welcome Screen - Initial app introduction for brand new users
///
/// BMAD V6 Spec:
/// - App logo at top
/// - "Welcome to PUSHIN'" title
/// - Three value proposition points
/// - Two choice buttons: Sign Up / Continue as Guest
/// - Purely informational + choice-based, no complex logic
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
          child: Column(
            children: [
              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: screenHeight * 0.08),

                      // App Logo
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF4040C0),
                                Color(0xFF3535A0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4040C0).withOpacity(0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.06),

                      // Welcome Title
                      const Text(
                        'Welcome to',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Color(0xFFB0B8FF)],
                        ).createShader(
                          Rect.fromLTWH(
                              0, 0, bounds.width, bounds.height * 1.3),
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

                      SizedBox(height: screenHeight * 0.06),

                      // Value Proposition Points
                      _ValuePoint(
                        icon: Icons.lock_open,
                        text: 'Complete workouts to unlock apps',
                      ),

                      const SizedBox(height: 20),

                      _ValuePoint(
                        icon: Icons.timer,
                        text: 'Earn screen time based on effort',
                      ),

                      const SizedBox(height: 20),

                      _ValuePoint(
                        icon: Icons.favorite,
                        text: 'Build healthy digital habits',
                      ),
                    ],
                  ),
                ),
              ),

              // Fixed bottom buttons - choice-based
              Padding(
                padding: const EdgeInsets.all(32),
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

                    // Continue as Guest Button
                    _SecondaryButton(
                      label: 'Continue as Guest',
                      onTap: () async {
                        // Set guest mode and navigate to main app
                        final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
                        authProvider.enterGuestMode();

                        // Navigation handled by AppRouter state change
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

/// Value proposition point widget
class _ValuePoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ValuePoint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF8080FF),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
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

/// Secondary button for guest mode
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
