import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'TokenManager.dart';

/// Authentication service for handling login, signup, and OAuth flows
class AuthenticationService {
  static final AuthenticationService _instance =
      AuthenticationService._internal();

  factory AuthenticationService() => _instance;

  late final String baseUrl;
  final TokenManager _tokenManager = TokenManager();
  late final http.Client _httpClient;

  AuthenticationService._internal({
    this.baseUrl = 'http://192.168.1.89:3000/api', // Local development server
  }) {
    _httpClient = _createHttpClient();
  }

  /// Create HTTP client that handles SSL certificate issues for Railway
  http.Client _createHttpClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Trust Railway certificates specifically
        return host.contains('railway.app') || host.contains('up.railway.app');
      };

    return IOClient(ioClient);
  }

  // Google Sign In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    signInOption: SignInOption.standard, // Use standard sign in
  );

  /// Register with email and password
  Future<AuthResult> register({
    required String email,
    required String password,
    String? name,
  }) async {
    // Log request details for debugging
    final requestUrl = '$baseUrl/auth/register';
    final requestBody = jsonEncode({
      'email': email,
      'password': password,
      if (name != null) 'name': name,
    });

    print('📝 REGISTER REQUEST:');
    print('  URL: $requestUrl');
    print('  Method: POST');
    print('  Body: $requestBody');

    try {
      final response = await _httpClient.post(
        Uri.parse(requestUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('📡 REGISTER RESPONSE:');
      print('  Status Code: ${response.statusCode}');
      print('  Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final authData = AuthData.fromJson(data['data']);
        await _tokenManager.saveTokens(
          accessToken: authData.accessToken,
          refreshToken: authData.refreshToken,
        );
        print('✅ REGISTRATION SUCCESSFUL: User ${authData.user.email}');
        return AuthResult.success(authData);
      } else {
        final errorMessage = data['error'] ?? 'Registration failed';
        print(
            '❌ REGISTRATION FAILED: $errorMessage (Status: ${response.statusCode})');
        return AuthResult.failure(errorMessage);
      }
    } catch (e) {
      print('💥 REGISTRATION NETWORK ERROR: $e');
      return AuthResult.failure(
          'Network error during registration: ${e.toString()}');
    }
  }

  /// Login with email and password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    // Log request details
    final requestUrl = '$baseUrl/auth/login';
    final requestHeaders = {'Content-Type': 'application/json'};
    final requestBody = jsonEncode({
      'email': email,
      'password': password,
    });

    print('🔍 EMAIL LOGIN REQUEST:');
    print('  URL: $requestUrl');
    print('  Method: POST');
    print('  Headers: $requestHeaders');
    print('  Body: $requestBody');

    try {
      final response = await _httpClient.post(
        Uri.parse(requestUrl),
        headers: requestHeaders,
        body: requestBody,
      );

      print('📡 EMAIL LOGIN RESPONSE:');
      print('  Status Code: ${response.statusCode}');
      print('  Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final authData = AuthData.fromJson(data['data']);
        await _tokenManager.saveTokens(
          accessToken: authData.accessToken,
          refreshToken: authData.refreshToken,
        );
        return AuthResult.success(authData);
      } else {
        final errorMessage = data['error'] ?? 'Login failed';
        print(
            '❌ EMAIL LOGIN FAILED: $errorMessage (Status: ${response.statusCode})');
        return AuthResult.failure(errorMessage);
      }
    } catch (e) {
      print('💥 EMAIL LOGIN NETWORK ERROR: $e');
      return AuthResult.failure(e.toString());
    }
  }

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    print('🔵 GOOGLE SIGN IN: Starting Google authentication flow');

    try {
      // Check if Google Sign In is available on this platform
      final bool isAvailable = await _googleSignIn.isSignedIn();
      print('🔵 GOOGLE SIGN IN: isSignedIn check: $isAvailable');

      // Try to silently sign in first (if user was previously signed in)
      try {
        final GoogleSignInAccount? silentSignIn =
            await _googleSignIn.signInSilently();
        if (silentSignIn != null) {
          print(
              '✅ GOOGLE SIGN IN: Silent sign in successful: ${silentSignIn.email}');
          // Get tokens and proceed with backend authentication
          final GoogleSignInAuthentication googleAuth =
              await silentSignIn.authentication;
          if (googleAuth.idToken != null) {
            return await _authenticateWithGoogleBackend(googleAuth.idToken!);
          }
        }
      } catch (silentError) {
        print('⚠️ GOOGLE SIGN IN: Silent sign in failed: $silentError');
      }
      // Start Google Sign In flow
      print('🔵 GOOGLE SIGN IN: Calling _googleSignIn.signIn()...');
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏰ GOOGLE SIGN IN: Timeout after 30 seconds');
          throw Exception(
              'Google Sign In timed out. Please check your device settings and try again.');
        },
      ).catchError((error) {
        print('💥 GOOGLE SIGN IN: Platform-specific error: $error');
        if (error.toString().contains('URL scheme')) {
          throw Exception(
              'Google Sign In configuration error. Please contact support.');
        }
        if (error.toString().contains('cancelled')) {
          throw Exception('Google Sign In was cancelled');
        }
        throw error;
      });

      if (googleUser == null) {
        print('❌ GOOGLE SIGN IN: User cancelled sign in');
        return AuthResult.failure('Google sign in cancelled');
      }

      print('✅ GOOGLE SIGN IN: Got Google user: ${googleUser.email}');

      // Get authentication tokens
      print('🔵 GOOGLE SIGN IN: Getting authentication tokens...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.idToken == null) {
        print('❌ GOOGLE SIGN IN: Failed to get Google ID token');
        return AuthResult.failure('Failed to get Google ID token');
      }

      return await _authenticateWithGoogleBackend(googleAuth.idToken!);
    } catch (e) {
      print('💥 GOOGLE SIGN IN ERROR: $e');
      return AuthResult.failure('Google sign in error: ${e.toString()}');
    }
  }

  /// Helper method to authenticate Google ID token with backend
  Future<AuthResult> _authenticateWithGoogleBackend(String idToken) async {
    print('✅ GOOGLE SIGN IN: Got ID token, sending to backend...');

    // Send to backend
    final requestUrl = '$baseUrl/auth/google';
    final requestBody = jsonEncode({
      'idToken': idToken,
    });

    print('🔍 GOOGLE SIGN IN REQUEST:');
    print('  URL: $requestUrl');
    print('  Method: POST');
    print('  Body: $requestBody');

    final response = await _httpClient.post(
      Uri.parse(requestUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    print('📡 GOOGLE SIGN IN RESPONSE:');
    print('  Status Code: ${response.statusCode}');
    print('  Response Body: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final authData = AuthData.fromJson(data['data']);
      await _tokenManager.saveTokens(
        accessToken: authData.accessToken,
        refreshToken: authData.refreshToken,
      );
      print('✅ GOOGLE SIGN IN SUCCESSFUL: User ${authData.user.email}');
      return AuthResult.success(authData);
    } else {
      final errorMessage = data['error'] ?? 'Google authentication failed';
      print(
          '❌ GOOGLE SIGN IN FAILED: $errorMessage (Status: ${response.statusCode})');
      return AuthResult.failure(errorMessage);
    }
  }

  /// Sign in with Apple
  Future<AuthResult> signInWithApple() async {
    try {
      // Start Apple Sign In flow
      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (credential.identityToken == null) {
        return AuthResult.failure('Failed to get Apple identity token');
      }

      // Send to backend
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/auth/apple'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identityToken': credential.identityToken,
          'authorizationCode': credential.authorizationCode,
          'user': {
            'email': credential.email,
            'name': {
              'firstName': credential.givenName,
              'lastName': credential.familyName,
            },
          },
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final authData = AuthData.fromJson(data['data']);
        await _tokenManager.saveTokens(
          accessToken: authData.accessToken,
          refreshToken: authData.refreshToken,
        );
        return AuthResult.success(authData);
      } else {
        return AuthResult.failure(
            data['error'] ?? 'Apple authentication failed');
      }
    } catch (e) {
      return AuthResult.failure('Apple sign in error: ${e.toString()}');
    }
  }

  /// Logout user
  Future<bool> logout() async {
    try {
      // Get current access token
      final accessToken = await _tokenManager.getAccessToken();
      if (accessToken != null) {
        // Call logout endpoint
        await _httpClient.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        );
      }

      // Clear local tokens regardless of API call result
      await _tokenManager.clearTokens();
      await _googleSignIn.signOut();

      return true;
    } catch (e) {
      // Even if logout API call fails, clear local tokens
      await _tokenManager.clearTokens();
      await _googleSignIn.signOut();
      return true;
    }
  }

  /// Get current user profile
  Future<User?> getCurrentUser() async {
    try {
      final accessToken = await _tokenManager.getAccessToken();
      if (accessToken == null) return null;

      final response = await _httpClient.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return User.fromJson(data['data']['user']);
      } else if (response.statusCode == 403) {
        // Token expired, try to refresh
        final refreshed = await _tokenManager.refreshToken();
        if (refreshed) {
          return getCurrentUser(); // Retry with new token
        }
        return null;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Update current user profile
  Future<AuthResult> updateProfile({
    String? email,
    String? name,
    String? password,
  }) async {
    try {
      final accessToken = await _tokenManager.getAccessToken();
      if (accessToken == null) {
        return AuthResult.failure('Not authenticated');
      }

      final requestBody = <String, dynamic>{};
      if (email != null) requestBody['email'] = email;
      if (name != null) requestBody['name'] = name;
      if (password != null) requestBody['password'] = password;

      debugPrint(
          '🔄 AuthenticationService.updateProfile() - sending request: $requestBody');

      final response = await _httpClient.put(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint(
          '🔄 AuthenticationService.updateProfile() - response status: ${response.statusCode}');
      final data = jsonDecode(response.body);
      debugPrint(
          '🔄 AuthenticationService.updateProfile() - response data: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        try {
          // For profile updates, we only get user data back, not full AuthData with tokens
          final userData = data['data']['user'];
          if (userData == null) {
            return AuthResult.failure('Invalid response: missing user data');
          }

          final user = User.fromJson(userData);
          // Create a minimal AuthData with the updated user (tokens are not needed for profile updates)
          final authData = AuthData(
            user: user,
            isNewUser: false, // Not relevant for profile updates
            accessToken: '', // Will be ignored by the caller
            refreshToken: '', // Will be ignored by the caller
          );
          return AuthResult.success(authData);
        } catch (parseError) {
          return AuthResult.failure(
              'Failed to parse profile update response: ${parseError.toString()}');
        }
      } else {
        final errorMessage = data['error'] ?? 'Profile update failed';
        return AuthResult.failure(errorMessage);
      }
    } catch (e) {
      return AuthResult.failure(
          'Network error during profile update: ${e.toString()}');
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final accessToken = await _tokenManager.getAccessToken();
    return accessToken != null;
  }
}

/// Authentication result wrapper
class AuthResult {
  final bool success;
  final AuthData? data;
  final String? error;

  AuthResult._({required this.success, this.data, this.error});

  factory AuthResult.success(AuthData data) {
    return AuthResult._(success: true, data: data);
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(success: false, error: error);
  }
}

/// Authentication data returned from API
class AuthData {
  final User user;
  final bool isNewUser;
  final String accessToken;
  final String refreshToken;

  AuthData({
    required this.user,
    required this.isNewUser,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      user: User.fromJson(json['user']),
      isNewUser: json['isNewUser'] ??
          false, // Default to false for backward compatibility
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
    );
  }
}

/// User model
class User {
  final int id;
  final String email;
  final String? firstname;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.firstname,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      firstname: json['firstname'] as String?, // Explicitly cast to handle null
      createdAt:
          DateTime.parse((json['createdAt'] ?? json['created_at']) as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstname': firstname,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
