import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';
import '../../../state/auth_state_provider.dart';

/// Sign In Screen - Email/Password authentication
///
/// BMAD V6 Spec:
/// - Email and password input fields at top
/// - Sign In button with gradient, positioned closer to bottom for thumb access
/// - "Forgot your password?" link under Sign In button
/// - Third-party login buttons (Apple, Google) below in smaller section
/// - Maintains existing gradient background and button styles
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Add listeners for real-time form validation
    _emailController.addListener(_onFormChanged);
    _passwordController.addListener(_onFormChanged);

    // Add focus listeners for automatic scrolling
    _emailFocus.addListener(() => _scrollToFocusedField(_emailFocus));
    _passwordFocus.addListener(() => _scrollToFocusedField(_passwordFocus));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _scrollToFocusedField(FocusNode focusNode) {
    if (focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && focusNode.context != null) {
          Scrollable.ensureVisible(
            focusNode.context!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.2,
          );
        }
      });
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _onFormChanged() {
    setState(() {});
  }

  bool _isFormValid() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    return email.isNotEmpty && email.contains('@') && password.isNotEmpty;
  }

  Future<void> _handleSignIn() async {
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      // Navigate based on user state
      _navigateAfterAuth();
    }
    // Error is handled by the provider and displayed in UI
  }

  void _handleForgotPassword() {
    // TODO: Implement forgot password functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Forgot password functionality coming soon')),
    );
  }

  void _navigateToSignUp() {
    // BMAD v6: State-driven navigation - no Navigator.push
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    authProvider.triggerSignUpFlow();
  }

  void _navigateAfterAuth() {
    // Navigation is handled automatically by AppRouter when auth state changes
    // AppRouter listens to AuthStateProvider and will route appropriately
  }

  Future<void> _handleThirdPartySignIn(String provider) async {
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

    bool success = false;
    if (provider == 'google') {
      success = await authProvider.signInWithGoogle();
    } else if (provider == 'apple') {
      success = await authProvider.signInWithApple();
    }

    if (success && mounted) {
      // Navigate based on user state
      _navigateAfterAuth();
    }
    // Error is handled by the provider and displayed in UI
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final authProvider = Provider.of<AuthStateProvider>(context);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SizedBox.expand(
          child: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top navigation bar with sign up button
                      Padding(
                        padding: const EdgeInsets.only(top: 16, right: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: _navigateToSignUp,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF2A2A6A),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: const Color(0xFF2A2A6A)
                                          .withOpacity(0.7),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome Back!',
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
                                Rect.fromLTWH(
                                    0, 0, bounds.width, bounds.height * 1.3),
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
                          ],
                        ),
                      ),

                      const SizedBox(
                          height:
                              250), // Large spacing between title and content

                      // Input Fields Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            // Third-party login section
                            Text(
                              'Continue with',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Third-party buttons row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Apple Sign In Button
                                _RoundThirdPartyButton(
                                  imageAsset: 'assets/images/apple_logo.png',
                                  backgroundColor: Colors.white,
                                  iconColor: Colors.white,
                                  onTap: () => _handleThirdPartySignIn('apple'),
                                ),

                                const SizedBox(width: 20),

                                // Google Sign In Button
                                _RoundThirdPartyButton(
                                  imageAsset: 'assets/images/google_logo.png',
                                  backgroundColor: Colors.white,
                                  onTap: () =>
                                      _handleThirdPartySignIn('google'),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Divider line
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withOpacity(0.2),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'or',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withOpacity(0.2),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Email Field
                            TextField(
                              controller: _emailController,
                              focusNode: _emailFocus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Email',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),

                            const SizedBox(height: 16),

                            // Password Field
                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Password',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 16,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  onPressed: _togglePasswordVisibility,
                                ),
                              ),
                              obscureText: _obscurePassword,
                            ),

                            const SizedBox(height: 12),

                            // Forgot Password Link
                            GestureDetector(
                              onTap: _handleForgotPassword,
                              child: Text(
                                'Forgot your password?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            // Error message display
                            if (authProvider.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Text(
                                  authProvider.errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],

                            // Bottom padding - only add extra space when keyboard is open
                            SizedBox(height: 90 + keyboardHeight),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom button container
              BottomActionContainer(
                child: _SignInButton(
                  enabled: _isFormValid() && !authProvider.isLoading,
                  loading: authProvider.isLoading,
                  onTap: _handleSignIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated Sign In button widget - only enabled when form is valid
class _SignInButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _SignInButton({
    required this.enabled,
    this.loading = false,
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
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF2A2A6A)),
                  ),
                )
              : AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? const Color(0xFF2A2A6A)
                        : Colors.white.withOpacity(0.4),
                    letterSpacing: -0.3,
                  ),
                  child: const Text('Sign In'),
                ),
        ),
      ),
    );
  }
}

/// Round third-party login button widget (compact, circular design)
class _RoundThirdPartyButton extends StatelessWidget {
  final IconData? icon;
  final String? imageAsset;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _RoundThirdPartyButton({
    this.icon,
    this.imageAsset,
    this.backgroundColor,
    this.iconColor,
    required this.onTap,
  }) : assert(icon != null || imageAsset != null,
            'Either icon or imageAsset must be provided');

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: Container(
        width: 50, // Smaller circular button
        height: 50,
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (backgroundColor ?? Colors.white).withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: imageAsset != null
            ? Padding(
                padding: imageAsset!.contains('apple')
                    ? const EdgeInsets.only(
                        top: 10,
                        bottom: 14,
                        left: 12,
                        right: 12) // Apple logo smaller
                    : const EdgeInsets.all(10), // Google logo stays centered
                child: Image.asset(
                  imageAsset!,
                  fit: BoxFit.contain,
                ),
              )
            : Icon(
                icon,
                color: iconColor ?? const Color(0xFF2A2A6A),
                size: 24,
              ),
      ),
    );
  }
}
