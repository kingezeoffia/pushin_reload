import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/PressAnimationButton.dart';

class LogoutPopup extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onLogout;
  final String? title;
  final String? message;
  final String? cancelButtonText;
  final String? confirmButtonText;
  final IconData? icon;
  final Color? iconColor;
  final Color? confirmButtonColor;

  const LogoutPopup({
    super.key,
    required this.onCancel,
    required this.onLogout,
    this.title,
    this.message,
    this.cancelButtonText,
    this.confirmButtonText,
    this.icon,
    this.iconColor,
    this.confirmButtonColor,
  });

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
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: const Color(
                    0x99000000), // Same glass color as positioning overlay
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // Custom Icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: (iconColor ?? const Color(0xFFEF4444))
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          icon ?? Icons.logout,
                          color: iconColor ?? const Color(0xFFEF4444),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title with improved typography
                      Text(
                        title ?? 'Logout',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      // Subtitle with improved styling
                      Text(
                        message ?? 'Are you sure you want to logout?',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.4,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      // Buttons with enhanced styling
                      Row(
                        children: [
                          Expanded(
                            child: PressAnimationButton(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onCancel();
                              },
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
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
                                  child: Text(
                                    cancelButtonText ?? 'Cancel',
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
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: PressAnimationButton(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                onLogout();
                              },
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: confirmButtonColor ??
                                      const Color(
                                          0xFFEF4444), // Custom color or red for logout
                                  borderRadius: BorderRadius.circular(100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (confirmButtonColor ??
                                              const Color(0xFFEF4444))
                                          .withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    confirmButtonText ?? 'Logout',
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
