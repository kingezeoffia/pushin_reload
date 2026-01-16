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

/// Change Password Screen
///
/// Full-screen design following EmergencyUnlockSettingsScreen pattern:
/// - GOStepsBackground with animated gradient
/// - Clean, minimal settings layout
/// - Purple gradient text and icons (updated from blue)
/// - Multiple text fields for password change
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _validateInput();
  }

  void _validateInput() {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final isValid = currentPassword.isNotEmpty &&
        newPassword.isNotEmpty &&
        newPassword.length >= 6 &&
        newPassword == confirmPassword &&
        currentPassword != newPassword;

    if (_isValid != isValid) {
      setState(() => _isValid = isValid);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Check authentication first
    final authState = Provider.of<AuthStateProvider>(context, listen: false);
    if (authState.currentUser == null) {
      setState(() =>
          _errorMessage = 'You must be logged in to change your password');
      return;
    }

    // Basic validation
    if (currentPassword.isEmpty) {
      setState(() => _errorMessage = 'Current password is required');
      return;
    }

    if (newPassword.isEmpty) {
      setState(() => _errorMessage = 'New password is required');
      return;
    }

    if (newPassword.length < 6) {
      setState(
          () => _errorMessage = 'New password must be at least 6 characters');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'New passwords do not match');
      return;
    }

    if (currentPassword == newPassword) {
      setState(() => _errorMessage =
          'New password must be different from current password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await authState.updateProfile(password: newPassword);

      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password updated successfully')),
          );
        }
      } else {
        setState(() {
          _errorMessage = authState.errorMessage ?? 'Failed to update password';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update password: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: SingleChildScrollView(
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
                        'Change',
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
                          'Password',
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
                        'Update your account password',
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

                const SizedBox(height: 24),

                // Password input section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current password field
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
                                    Icons.lock_outline,
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
                                        'Current Password',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Enter your current password',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.5),
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
                              controller: _currentPasswordController,
                              obscureText: _obscureCurrentPassword,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter current password',
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
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureCurrentPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureCurrentPassword =
                                          !_obscureCurrentPassword;
                                    });
                                  },
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

                      const SizedBox(height: 16),

                      // New password field
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
                                    Icons.lock_reset,
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
                                        'New Password',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'At least 6 characters',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.5),
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
                              controller: _newPasswordController,
                              obscureText: _obscureNewPassword,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter new password',
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
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureNewPassword =
                                          !_obscureNewPassword;
                                    });
                                  },
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

                      const SizedBox(height: 16),

                      // Confirm password field
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
                                    Icons.lock_person,
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
                                        'Confirm Password',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Re-enter your new password',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.5),
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
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Confirm new password',
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
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.white.withOpacity(0.5),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    });
                                  },
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
                        const SizedBox(height: 20),
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
                        label: 'Update Password',
                        isLoading: _isLoading,
                        isEnabled: _isValid,
                        onTap: _updatePassword,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
