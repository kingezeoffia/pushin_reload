import 'package:flutter/material.dart';

class WorkoutsDesignTokens {
  // Mode Colors
  static const Color cozyGreen = Color(0xFF10B981);
  static const Color normalBlue = Color(0xFF4F46E5);
  static const Color tuffOrange = Color(0xFFF59E0B);

  // Status Colors
  static const Color lockedRed = Color(0xFFEF4444);
  static const Color earningOrange = Color(0xFFF59E0B);
  static const Color unlockedGreen = Color(0xFF10B981);
  static const Color expiredGray = Color(0xFF6B7280);

  // Widget Colors
  static const Color stepsBlue = Color(0xFF6B8AFF);
  static const Color caloriesOrange = Color(0xFFFF6B6B);
  static const Color distanceRed = Color(0xFFFF8566);
  static const Color waterCyan = Color(0xFF66D9EF);

  // Backgrounds
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color cardDark = Color(0xFF1A1D2E);
  static const Color cardLightDark = Color(0xFF252B42);

  // Gradients
  static LinearGradient cozyGradient = LinearGradient(
    colors: [cozyGreen, cozyGreen.withOpacity(0.7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient normalGradient = LinearGradient(
    colors: [normalBlue, Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient tuffGradient = LinearGradient(
    colors: [tuffOrange, Color(0xFFFB923C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Animation Durations
  static const Duration cardAnimation = Duration(milliseconds: 800);
  static const Duration modeSwitch = Duration(milliseconds: 400);
  static const Duration progressAnimation = Duration(milliseconds: 1200);
}






