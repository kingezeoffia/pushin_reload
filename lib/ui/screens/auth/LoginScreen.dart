import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../../state/auth_state_provider.dart';
import 'SignInScreen.dart';
import 'SignUpScreen.dart';
import 'SkipBlockAppsScreen.dart';

/// Login Choice Screen - Choose between Sign In and Sign Up
///
/// BMAD V6 Spec:
/// - Gate screen between Welcome and personalized onboarding
/// - Two main options: Sign In (existing users) or Sign Up (new users)
/// - Third-party quick login buttons below
/// - Consistent UI with onboarding screens (typography, spacing, buttons)
/// - Back button to return to Welcome screen
/// - No step indicator (pre-onboarding)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Future<void> _handleThirdPartySignIn(String provider) async {
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

    bool success = false;
    if (provider == 'google') {
      success = await authProvider.signInWithGoogle();
    } else if (provider == 'apple') {
      success = await authProvider.signInWithApple();
    }

    if (success && mounted) {
      // Navigation is handled automatically by AppRouter when auth state changes
      // The auth provider will update state and the router will handle navigation
    }
    // Error is handled by the provider and displayed in UI
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
              SizedBox(height: screenHeight * 0.08),

              // Heading
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Get started with:',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        'PUSHIN\'',
                        style: TextStyle(
                          fontSize: 38,
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
                      'Choose how you\'d like to sign in or create your account',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: -0.2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.08),

              // Main Auth Choice Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // Sign In Button
                    _AuthButton(
                      label: 'Sign In',
                      backgroundColor: const Color(0xFF6060FF),
                      textColor: Colors.white,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignInScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Sign Up Button
                    _AuthButton(
                      label: 'Sign Up',
                      backgroundColor: Colors.white.withOpacity(0.1),
                      textColor: Colors.white,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpScreen(),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 24),

                    // Quick third-party options section
                    Text(
                      'Or continue with',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Quick third-party buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Apple Quick Sign In Button
                        _RoundQuickAuthButton(
                          icon: Icons.apple,
                          onTap: () => _handleThirdPartySignIn('apple'),
                        ),

                        const SizedBox(width: 20),

                        // Google Quick Sign In Button
                        _RoundQuickAuthButton(
                          icon: Icons
                              .g_mobiledata, // Placeholder - will be replaced with Google logo
                          onTap: () => _handleThirdPartySignIn('google'),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Skip Login (minimal, non-prominent)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const SkipBlockAppsScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Skip Login',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.4),
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Footer text
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                      letterSpacing: -0.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Main Auth Button Widget (for Sign In/Sign Up choices)
class _AuthButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _AuthButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
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
          color: backgroundColor,
          borderRadius: BorderRadius.circular(26),
          boxShadow: backgroundColor == Colors.white
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
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Round Quick Third-party Auth Button Widget (compact, circular design)
class _RoundQuickAuthButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundQuickAuthButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: Container(
        width: 50, // Smaller circular button
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: const Color(0xFF2A2A6A),
          size: 24,
        ),
      ),
    );
  }
}
