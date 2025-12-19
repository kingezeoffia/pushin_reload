import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing onboarding completion state
///
/// Tracks whether user has completed onboarding and prevents re-entry
class OnboardingService {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingDataKey = 'onboarding_data';
  static const String _forceOnboardingKey = 'force_onboarding_show';
  static const String _introShownKey = 'intro_screen_shown';

  // Static callback for when onboarding completes
  static VoidCallback? _onOnboardingCompleted;

  // Static callback for development refresh
  static VoidCallback? _onDevRefresh;

  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if force onboarding is enabled (for development)
    final forceOnboarding = prefs.getBool(_forceOnboardingKey) ?? false;
    if (forceOnboarding) {
      return false; // Force show onboarding
    }

    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  /// Check if intro screen has been shown (for first-time users)
  static Future<bool> hasSeenIntroScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_introShownKey) ?? false;
  }

  /// Mark intro screen as shown
  static Future<void> markIntroScreenShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introShownKey, true);
  }

  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
    await prefs
        .remove(_forceOnboardingKey); // Clear force flag on real completion

    // Call the completion callback if set
    _onOnboardingCompleted?.call();
  }

  static void setOnboardingCompletedCallback(VoidCallback callback) {
    _onOnboardingCompleted = callback;
  }

  static void setDevRefreshCallback(VoidCallback callback) {
    _onDevRefresh = callback;
  }

  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompletedKey);
    await prefs.remove(_onboardingDataKey);
    await prefs.remove(_forceOnboardingKey);
    await prefs.remove(_introShownKey);
    print('🔄 Onboarding state reset - you can now access onboarding again');
  }

  /// Development helper: Force show onboarding immediately
  /// This sets a flag that makes isOnboardingCompleted() return false
  static Future<void> devForceShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_forceOnboardingKey, true);
    // Trigger immediate refresh
    _onDevRefresh?.call();
  }

  /// Development helper: Reset onboarding and restart app
  /// Call this from anywhere during development to test onboarding flow
  static Future<void> devResetAndRestart() async {
    await resetOnboarding();
    // This will trigger a hot restart in development
    // ignore: avoid_print
    print(
        '🔄 Onboarding reset complete. Hot restart the app to see onboarding again.');
  }

  static Future<void> saveOnboardingData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert to JSON-compatible format
    final jsonData = data.map((key, value) {
      if (value is List<String>) {
        return MapEntry(key, value);
      }
      return MapEntry(key, value.toString());
    });
    await prefs.setString(_onboardingDataKey, jsonData.toString());
  }

  static Future<Map<String, dynamic>?> getOnboardingData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_onboardingDataKey);
    if (dataString == null) return null;

    // Simple parsing - in production you'd want proper JSON
    try {
      // For MVP, we'll just store the completion flag
      // Full data storage can be implemented later if needed
      return {};
    } catch (e) {
      return {};
    }
  }
}










