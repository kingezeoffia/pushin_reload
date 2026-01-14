import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';
import '../../../state/auth_state_provider.dart';

/// Sign Up Screen - New user registration
///
/// BMAD V6 Spec:
/// - Title: "Get started free. Free forever. No credit card needed."
/// - Email, Name, Password input fields with password strength indicator
/// - Sign Up button with gradient, positioned closer to bottom for thumb access
/// - Third-party sign-up buttons (Google, Facebook) below
/// - Top navigation to toggle to Sign In screen
/// - Maintains existing gradient background and button styles
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => _scrollToFocusedField(_emailFocus));
    _passwordFocus.addListener(() => _scrollToFocusedField(_passwordFocus));
    _confirmPasswordFocus
        .addListener(() => _scrollToFocusedField(_confirmPasswordFocus));

    // Add listeners for real-time form validation
    _emailController.addListener(_onFormChanged);
    _passwordController.addListener(_onFormChanged);
    _confirmPasswordController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  void _navigateToSignIn() {
    // BMAD v6: State-driven navigation - no Navigator.pushReplacement
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    authProvider.triggerSignInFlow();
  }

  void _navigateAfterAuth() {
    // Navigation is handled automatically by AppRouter when auth state changes
    // AppRouter listens to AuthStateProvider and will route appropriately
  }

  bool _isFormValid() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final passwordStrength = _calculatePasswordStrength(password);

    return email.isNotEmpty &&
        email.contains('@') &&
        password.isNotEmpty &&
        confirmPassword.isNotEmpty &&
        password == confirmPassword &&
        (passwordStrength == PasswordStrength.medium ||
            passwordStrength == PasswordStrength.strong);
  }

  Future<void> _handleSignUp() async {
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      // register() already set justRegistered = true, router will handle navigation to NewUserWelcomeScreen
      // BMAD v6: No direct navigation - router reacts to state changes
    }
    // Error is handled by the provider and displayed in UI
  }

  Future<void> _handleThirdPartySignUp(String provider) async {
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

  /// Calculate password strength based on common criteria
  PasswordStrength _calculatePasswordStrength(String password) {
    if (password.isEmpty) return PasswordStrength.none;

    int score = 0;

    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Character variety checks
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return const Color(0xFFEF4444); // Red
      case PasswordStrength.medium:
        return const Color(0xFFF59E0B); // Yellow
      case PasswordStrength.strong:
        return const Color(0xFF10B981); // Green
      case PasswordStrength.none:
        return Colors.white.withOpacity(0.3);
    }
  }

  String _getStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.none:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final passwordStrength =
        _calculatePasswordStrength(_passwordController.text);
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
                      // Top navigation bar with sign in button
                      Padding(
                        padding: const EdgeInsets.only(top: 16, right: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: _navigateToSignIn,
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
                                      'Sign In',
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
                              200), // Large spacing between title and content

                      // Input Fields Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            // Third-party signup section (above input fields)
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
                                // Apple Sign Up Button
                                _RoundThirdPartyButton(
                                  imageAsset: 'assets/images/apple_logo.png',
                                  backgroundColor: Colors.white,
                                  iconColor: Colors.white,
                                  onTap: () => _handleThirdPartySignUp('apple'),
                                ),

                                const SizedBox(width: 20),

                                // Google Sign Up Button
                                _RoundThirdPartyButton(
                                  imageAsset: 'assets/images/google_logo.png',
                                  backgroundColor: Colors.white,
                                  iconColor: const Color(0xFF2A2A6A),
                                  onTap: () =>
                                      _handleThirdPartySignUp('google'),
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

                            // Password Field with Strength Indicator
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                  onChanged: (value) => setState(() {}),
                                ),

                                // Password Strength Indicator
                                if (_passwordController.text.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: _getStrengthColor(
                                              passwordStrength),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _getStrengthText(passwordStrength),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getStrengthColor(
                                              passwordStrength),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Confirm Password Field
                            TextField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Repeat Password',
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
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                              onChanged: (value) => setState(() {}),
                            ),

                            // Password Match Indicator
                            if (_confirmPasswordController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    _passwordController.text ==
                                            _confirmPasswordController.text
                                        ? Icons.check_circle
                                        : Icons.error,
                                    size: 16,
                                    color: _passwordController.text ==
                                            _confirmPasswordController.text
                                        ? const Color(0xFF10B981) // Green
                                        : const Color(0xFFEF4444), // Red
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _passwordController.text ==
                                            _confirmPasswordController.text
                                        ? 'Passwords match'
                                        : 'Passwords do not match',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _passwordController.text ==
                                              _confirmPasswordController.text
                                          ? const Color(0xFF10B981) // Green
                                          : const Color(0xFFEF4444), // Red
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],

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
                child: _SignUpButton(
                  enabled: _isFormValid() && !authProvider.isLoading,
                  loading: authProvider.isLoading,
                  onTap: _handleSignUp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Password strength enum
enum PasswordStrength {
  none,
  weak,
  medium,
  strong,
}

/// Animated Sign Up button widget - only enabled when form is valid
class _SignUpButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _SignUpButton({
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
                  child: const Text('Sign Up'),
                ),
        ),
      ),
    );
  }
}

/// Round third-party signup button widget (compact, circular design)
class _RoundThirdPartyButton extends StatelessWidget {
  final IconData? icon;
  final String? imageAsset;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _RoundThirdPartyButton({
    this.icon,
    this.imageAsset,
    required this.backgroundColor,
    required this.iconColor,
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
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor == Colors.white
                  ? Colors.white.withOpacity(0.2)
                  : backgroundColor.withOpacity(0.3),
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
                color: iconColor,
                size: 24,
              ),
      ),
    );
  }
}
