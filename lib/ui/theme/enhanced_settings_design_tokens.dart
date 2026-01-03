import 'package:flutter/material.dart';

class EnhancedSettingsDesignTokens {
  // Premium Color Palette
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color secondaryPurple = Color(0xFFA855F7);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color successMint = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);

  // Backgrounds
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color cardLightDark = Color(0xFF252B42);
  static const Color elevatedCard = Color(0xFF334155);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, secondaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [dangerRed, Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [successMint, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warningAmber, Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [dangerRed, Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Animation Durations
  static const Duration pageLoadDuration = Duration(milliseconds: 600);
  static const Duration cardAnimation = Duration(milliseconds: 600);
  static const Duration toggleAnimation = Duration(milliseconds: 300);
  static const Duration staggerDelay = Duration(milliseconds: 100);

  // Spacing & Radius
  static const double spacingLarge = 20.0;
  static const double spacingMedium = 16.0;
  static const double spacingSmall = 12.0;
  static const double spacingXS = 8.0;
  static const double spacingXL = 32.0;

  static const double borderRadiusLarge = 24.0;
  static const double borderRadiusMedium = 16.0;
  static const double borderRadiusSmall = 12.0;

  // Typography
  static const TextStyle titleLarge = TextStyle(
    color: textPrimary,
    fontSize: 40,
    fontWeight: FontWeight.bold,
    letterSpacing: -1,
  );

  static const TextStyle subtitle = TextStyle(
    color: textSecondary,
    fontSize: 16,
  );

  static const TextStyle tileTitle = TextStyle(
    color: textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle tileSubtitle = TextStyle(
    color: textTertiary,
    fontSize: 14,
  );

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  // Glassmorphism Decoration
  static BoxDecoration glassDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadiusLarge),
      gradient: LinearGradient(
        colors: [
          cardDark.withOpacity(0.8),
          cardLightDark.withOpacity(0.6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, -5),
        ),
      ],
    );
  }

  // Glow Shadow for Colors
  static List<BoxShadow> glowShadow(Color color) {
    return [
      BoxShadow(
        color: color.withOpacity(0.3),
        blurRadius: 20,
        spreadRadius: 2,
      ),
    ];
  }

  // Gradient for Color
  static LinearGradient getGradientForColor(Color color) {
    return LinearGradient(
      colors: [color, color.withOpacity(0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
