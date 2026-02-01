import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'AuthenticationService.dart';

/// Service for handling password reset operations
/// Extracts validation and API logic from UI screens
class PasswordResetService {
  static final PasswordResetService _instance = PasswordResetService._internal();
  factory PasswordResetService() => _instance;

  final AuthenticationService _authService = AuthenticationService();

  PasswordResetService._internal();

  /// Validate email format
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate password strength
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Validate password confirmation
  static bool doPasswordsMatch(String password, String confirmPassword) {
    return password == confirmPassword && password.isNotEmpty;
  }

  /// Validate reset token format
  static bool isValidResetToken(String token) {
    if (token.isEmpty) return false;
    // Should be 64 hex characters
    final tokenRegex = RegExp(r'^[a-f0-9]{64}$', caseSensitive: false);
    return tokenRegex.hasMatch(token);
  }

  /// Request password reset
  Future<PasswordResetResult> requestPasswordReset(String email) async {
    try {
      if (!isValidEmail(email)) {
        return PasswordResetResult.failure('Please enter a valid email address');
      }

      final result = await _authService.forgotPassword(email: email.trim());

      if (result.success) {
        return PasswordResetResult.success('Password reset email sent');
      } else {
        // Handle rate limiting specifically
        if (result.error?.contains('Too many') ?? false) {
          return PasswordResetResult.failure(
            'Too many reset attempts. Please wait 15 minutes before trying again.'
          );
        }
        return PasswordResetResult.failure(
          result.error ?? 'Failed to send reset email'
        );
      }
    } catch (e) {
      debugPrint('Password reset request error: $e');
      return PasswordResetResult.failure(
        'Network error. Please check your connection and try again.'
      );
    }
  }

  /// Reset password with token
  Future<PasswordResetResult> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      if (!isValidResetToken(token)) {
        return PasswordResetResult.failure('Invalid reset link');
      }

      if (!isValidPassword(newPassword)) {
        return PasswordResetResult.failure('Password must be at least 6 characters');
      }

      if (!doPasswordsMatch(newPassword, confirmPassword)) {
        return PasswordResetResult.failure('Passwords do not match');
      }

      final result = await _authService.resetPassword(
        token: token,
        newPassword: newPassword,
      );

      if (result.success) {
        return PasswordResetResult.success('Password reset successfully');
      } else {
        return PasswordResetResult.failure(
          result.error ?? 'Failed to reset password'
        );
      }
    } catch (e) {
      debugPrint('Password reset error: $e');
      return PasswordResetResult.failure(
        'Network error. Please check your connection and try again.'
      );
    }
  }

  /// Validate reset token with backend
  Future<TokenValidationResult> validateResetToken(String token) async {
    try {
      if (!isValidResetToken(token)) {
        return TokenValidationResult.invalid('Invalid token format');
      }

      // In a real implementation, this would call the backend validation endpoint
      // For now, we'll assume it's valid (implement HTTP call in production)
      return TokenValidationResult.valid();

    } catch (e) {
      debugPrint('Token validation error: $e');
      return TokenValidationResult.error('Unable to validate token');
    }
  }
}

/// Result wrapper for password reset operations
class PasswordResetResult {
  final bool success;
  final String? message;
  final String? error;

  PasswordResetResult._({
    required this.success,
    this.message,
    this.error,
  });

  factory PasswordResetResult.success(String message) {
    return PasswordResetResult._(success: true, message: message);
  }

  factory PasswordResetResult.failure(String error) {
    return PasswordResetResult._(success: false, error: error);
  }
}

/// Result wrapper for token validation
class TokenValidationResult {
  final bool isValid;
  final String? error;
  final DateTime? expiresAt;

  TokenValidationResult._({
    required this.isValid,
    this.error,
    this.expiresAt,
  });

  factory TokenValidationResult.valid({DateTime? expiresAt}) {
    return TokenValidationResult._(isValid: true, expiresAt: expiresAt);
  }

  factory TokenValidationResult.invalid(String error) {
    return TokenValidationResult._(isValid: false, error: error);
  }

  factory TokenValidationResult.error(String error) {
    return TokenValidationResult._(isValid: false, error: error);
  }
}