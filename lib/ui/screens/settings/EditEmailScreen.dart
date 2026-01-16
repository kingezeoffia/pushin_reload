import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../state/auth_state_provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';

/// Action Button styled like the "LET'S GO!" button from workout selection
/// - Pill-shaped button that activates when input is valid
/// - White background when enabled, gray when disabled
/// - Smooth animation when enabling/disabling
class _OnboardingStyleButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isEnabled;

  const _OnboardingStyleButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.isEnabled = true,
  });

  @override
  State<_OnboardingStyleButton> createState() => _OnboardingStyleButtonState();
}

class _OnboardingStyleButtonState extends State<_OnboardingStyleButton> {
  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: (widget.isLoading || !widget.isEnabled) ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color:
              widget.isEnabled ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(100), // Pill shape
          boxShadow: widget.isEnabled
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
          child: widget.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF2A2A6A),
                    strokeWidth: 2,
                  ),
                )
              : AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: widget.isEnabled
                        ? const Color(0xFF2A2A6A)
                        : Colors.white.withOpacity(0.4),
                    letterSpacing: -0.3,
                  ),
                  child: Text(widget.label),
                ),
        ),
      ),
    );
  }
}

/// Edit E-Mail Screen
///
/// Full-screen design following EmergencyUnlockSettingsScreen pattern:
/// - GOStepsBackground with animated gradient
/// - Clean, minimal settings layout
/// - Purple gradient text and icons (updated from blue)
/// - Single text field for email editing
class EditEmailScreen extends StatefulWidget {
  const EditEmailScreen({super.key});

  @override
  State<EditEmailScreen> createState() => _EditEmailScreenState();
}

class _EditEmailScreenState extends State<EditEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isValid = false;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only initialize once
    if (!_isInitialized) {
      // Pre-fill with current email
      final authState = Provider.of<AuthStateProvider>(context, listen: false);
      _emailController.text = authState.currentUser?.email ?? '';
      _validateInput();
      _isInitialized = true;
    }
  }

  void _validateInput() {
    final email = _emailController.text.trim();
    final isValid = email.isNotEmpty && _isValidEmail(email);
    if (_isValid != isValid) {
      setState(() => _isValid = isValid);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _updateEmail() async {
    final email = _emailController.text.trim();

    // Check authentication first
    final authState = Provider.of<AuthStateProvider>(context, listen: false);
    if (authState.currentUser == null) {
      setState(
          () => _errorMessage = 'You must be logged in to update your email');
      return;
    }

    // Basic validation
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Email cannot be empty');
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await authState.updateProfile(email: email);

      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email address updated successfully')),
          );
        }
      } else {
        setState(() {
          _errorMessage = authState.errorMessage ?? 'Failed to update email';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update email: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 22,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Heading section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(
                              Rect.fromLTWH(
                                  0, 0, bounds.width, bounds.height * 1.3),
                            ),
                            blendMode: BlendMode.srcIn,
                            child: const Text(
                              'Email',
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
                            'Update your email address',
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

                    const Spacer(),

                    // Email input section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email input field
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.06),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        Icons.email_outlined,
                                        color: Color(0xFF8B5CF6),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Email Address',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                              letterSpacing: -0.1,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Used for account recovery and notifications',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  Colors.white.withOpacity(0.5),
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _emailController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your email address',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 16,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.06),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  onChanged: (_) {
                                    _validateInput();
                                    if (_errorMessage != null) {
                                      setState(() => _errorMessage = null);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 32),

                          // Save button
                          _OnboardingStyleButton(
                            label: 'Save Changes',
                            isLoading: _isLoading,
                            isEnabled: _isValid,
                            onTap: _updateEmail,
                          ),

                          SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
