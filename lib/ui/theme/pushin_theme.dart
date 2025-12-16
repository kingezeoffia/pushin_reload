import 'package:flutter/material.dart';

/// PUSHIN' App Theme - GO Club inspired design system
///
/// Color Palette:
/// - Primary Blue: #4F46E5 (Indigo 600)
/// - Secondary Blue: #3B82F6 (Blue 500)
/// - Success Green: #10B981 (Emerald 500)
/// - Warning Yellow: #F59E0B (Amber 500)
/// - Error Red: #EF4444 (Red 500)
///
/// Design Principles:
/// - Dark mode first (matches GO Club screenshots)
/// - High contrast for accessibility
/// - Smooth animations (300ms ease-in-out)
/// - Pill-shaped buttons with full rounded corners
class PushinTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF4F46E5);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  // Neutral Colors (Dark Theme)
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color textTertiary = Color(0xFF64748B); // Slate 500

  // Gradient (for hero sections, cards, buttons)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryBlue, secondaryBlue],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  // Typography Scale (1.25 ratio) - Using basic web-safe fonts for maximum compatibility
  static const String fontFamily = 'sans-serif';
  static const String accentFontFamily = 'sans-serif';

  static const TextStyle headline1 = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.2,
  );

  static const TextStyle headline3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );

  static const TextStyle body1 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textTertiary,
    height: 1.4,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.5,
  );

  // Enhanced typography for Apps and Step Count text
  static const TextStyle appsText = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.3,
  );

  static const TextStyle stepCountText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.2,
  );

  static const TextStyle stepIndicatorText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 0.1,
  );

  // Spacing System (8px base)
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusPill = 100.0; // Fully rounded

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: primaryBlue.withOpacity(0.3),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationMedium = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Dark Theme Configuration
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: fontFamily,

        // Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: primaryBlue,
          secondary: secondaryBlue,
          surface: surfaceDark,
          background: backgroundDark,
          error: errorRed,
          onPrimary: textPrimary,
          onSecondary: textPrimary,
          onSurface: textPrimary,
          onBackground: textPrimary,
        ),

        // Scaffold
        scaffoldBackgroundColor: backgroundDark,

        // App Bar
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: headline3,
          iconTheme: IconThemeData(color: textPrimary),
        ),

        // Card
        cardTheme: CardThemeData(
          color: surfaceDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),

        // Text Theme
        textTheme: const TextTheme(
          displayLarge: headline1,
          displayMedium: headline2,
          headlineMedium: headline3,
          bodyLarge: body1,
          bodyMedium: body2,
          bodySmall: caption,
          labelLarge: buttonText,
        ),

        // Button Themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: textPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
              horizontal: spacingXl,
              vertical: spacingMd,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusPill),
            ),
            textStyle: buttonText,
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            side: const BorderSide(color: primaryBlue, width: 2),
            padding: const EdgeInsets.symmetric(
              horizontal: spacingXl,
              vertical: spacingMd,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusPill),
            ),
            textStyle: buttonText,
          ),
        ),

        // Input Decoration
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: spacingMd,
            vertical: spacingMd,
          ),
        ),
      );
}

/// Gradient Text Widget (for "plan is ready" style headings)
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GradientText(
    this.text, {
    super.key,
    required this.style,
    this.gradient = PushinTheme.primaryGradient,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width,
            bounds.height * 1.3), // Add 30% extra height for descenders
      ),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
