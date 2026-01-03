import 'package:flutter/material.dart';

class DashboardDesignTokens {
  // Colors - iOS Style
  static const Color primaryBlue = Color(0xFF4A5FFF);
  static const Color accentGreen = Color(0xFF7FFF9E);
  static const Color accentLightBlue = Color(0xFF8FA8FF);
  static const Color backgroundDark = Color(0xFF1A1D3D);
  static const Color cardBackground = Color(0xFF252B5C);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B3C7);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A5FFF), Color(0xFF3D4FCC)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A3166), Color(0xFF1F2547)],
  );

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  // Border Radius
  static const double cardRadius = 32.0;
  static const double smallRadius = 16.0;

  // Animation Durations
  static const Duration modeSwitch = Duration(milliseconds: 400);
}






