import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/PressAnimationButton.dart';
import '../../services/PaymentService.dart';

/// Restore Purchases Popup with Email Verification
///
/// Allows users to restore their subscription by entering email address.
/// Handles loading states, success, and error scenarios.
class RestorePurchasesPopup extends StatefulWidget {
  final PaymentService paymentService;
  final VoidCallback onDismiss;
  final Function(RestorePurchaseResult) onRestoreComplete;

  const RestorePurchasesPopup({
    super.key,
    required this.paymentService,
    required this.onDismiss,
    required this.onRestoreComplete,
  });

  @override
  State<RestorePurchasesPopup> createState() => _RestorePurchasesPopupState();
}

class _RestorePurchasesPopupState extends State<RestorePurchasesPopup> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;
  RestorePurchaseResult? _result;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRestore() async {
    // Clear previous error
    setState(() {
      _errorMessage = null;
      _result = null;
    });

    // Validate email input
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address';
      });
      return;
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    // Unfocus keyboard
    _emailFocusNode.unfocus();

    // Show loading
    setState(() {
      _isLoading = true;
    });

    try {
      // Call restore API
      final result = await widget.paymentService.restoreSubscriptionByEmail(
        email: email,
      );

      if (!mounted) return;

      setState(() {
        _result = result;
        _isLoading = false;
      });

      // If successful, notify parent and close after delay
      if (result.hasActiveSubscription) {
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          widget.onRestoreComplete(result);
        }
      } else {
        // Show error message
        setState(() {
          _errorMessage =
              result.errorMessage ?? 'Unable to restore subscription';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    constraints: const BoxConstraints(maxHeight: 500),
                    decoration: BoxDecoration(
                      color: const Color(0x99000000),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _result?.hasActiveSubscription == true
                                    ? const Color(0xFF10B981).withOpacity(0.2)
                                    : const Color(0xFF6060FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Icon(
                                _result?.hasActiveSubscription == true
                                    ? Icons.check_circle
                                    : Icons.refresh,
                                color: _result?.hasActiveSubscription == true
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF6060FF),
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Title
                            Text(
                              _result?.hasActiveSubscription == true
                                  ? 'Subscription Restored!'
                                  : 'Restore Purchases',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                decoration: TextDecoration.none,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),

                            // Description or Success Message
                            if (_result?.hasActiveSubscription == true) ...[
                              Text(
                                'Your ${_result!.subscription!.displayName} has been restored.',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.7),
                                  height: 1.4,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ] else ...[
                              Text(
                                'Enter the email address you used for your subscription',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.7),
                                  height: 1.4,
                                  decoration: TextDecoration.none,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),

                              // Email Input Field
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _errorMessage != null
                                        ? Colors.red.withOpacity(0.5)
                                        : Colors.white.withOpacity(0.15),
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  enabled: !_isLoading,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _handleRestore(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'your@email.com',
                                    hintStyle: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white.withOpacity(0.3),
                                      decoration: TextDecoration.none,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),

                              // Error Message
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red.withOpacity(0.8),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.red.withOpacity(0.9),
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Expired Subscriptions Info
                              if (_result?.hasExpiredSubscriptions == true) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Found expired subscription:',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange.withOpacity(0.9),
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ...(_result!.expiredSubscriptions!.map(
                                        (exp) => Text(
                                          '${exp.planId.toUpperCase()} - Expired ${_formatDate(exp.expiredOn)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            color:
                                                Colors.orange.withOpacity(0.8),
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      )),
                                    ],
                                  ),
                                ),
                              ],
                            ],

                            const SizedBox(height: 24),

                            // Action Buttons
                            if (_result?.hasActiveSubscription != true) ...[
                              // Check Purchases Button
                              PressAnimationButton(
                                onTap: _isLoading ? null : _handleRestore,
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: _isLoading
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.white.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.2),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF2A2A6A),
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            'Check Purchases',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF2A2A6A),
                                              letterSpacing: 0.3,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Close Button (after success)
                              PressAnimationButton(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onRestoreComplete(_result!);
                                },
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(100),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Continue',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // X button in top right corner (only show when not in success state)
                  if (_result == null || !_result!.hasActiveSubscription) ...[
                    Positioned(
                      top: 10,
                      right: 50,
                      child: GestureDetector(
                        onTap: _isLoading ? null : widget.onDismiss,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.7),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
}
