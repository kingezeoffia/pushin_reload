import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Manages JWT tokens securely using encrypted storage
class TokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _guestModeKey = 'is_guest_mode';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final String _baseUrl;

  TokenManager({
    String baseUrl = 'https://pushin-production.up.railway.app/api',
  }) : _baseUrl = baseUrl;

  /// Save access and refresh tokens securely
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Get access token from secure storage
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  /// Get refresh token from secure storage
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Check if access token is expired
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = json
          .decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));

      final exp = payload['exp'];
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();

      // Consider token expired if it expires within next 5 minutes
      return expiryDate.isBefore(now.add(const Duration(minutes: 5)));
    } catch (e) {
      return true; // If we can't parse, assume expired
    }
  }

  /// Refresh access token using refresh token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final newAccessToken = data['data']['accessToken'];
        final newRefreshToken = data['data']['refreshToken'];

        await saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get valid access token (refresh if needed)
  Future<String?> getValidAccessToken() async {
    String? accessToken = await getAccessToken();

    if (accessToken == null) return null;

    if (_isTokenExpired(accessToken)) {
      final refreshed = await refreshToken();
      if (refreshed) {
        accessToken = await getAccessToken();
      } else {
        // Refresh failed, clear tokens
        await clearTokens();
        return null;
      }
    }

    return accessToken;
  }

  /// Clear all tokens from secure storage
  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  /// Check if user has valid tokens
  Future<bool> hasValidTokens() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();

    return accessToken != null &&
        refreshToken != null &&
        !_isTokenExpired(accessToken);
  }

  /// Get authorization header with valid access token
  Future<Map<String, String>?> getAuthHeaders() async {
    final accessToken = await getValidAccessToken();
    if (accessToken == null) return null;

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  /// Set guest mode flag
  Future<void> setGuestMode(bool isGuest) async {
    await _storage.write(key: _guestModeKey, value: isGuest.toString());
  }

  /// Get guest mode flag
  Future<bool> isGuestMode() async {
    final value = await _storage.read(key: _guestModeKey);
    return value == 'true';
  }

  /// Clear guest mode flag
  Future<void> clearGuestMode() async {
    await _storage.delete(key: _guestModeKey);
  }
}
