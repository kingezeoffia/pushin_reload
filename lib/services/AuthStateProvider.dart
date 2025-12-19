import 'package:flutter/foundation.dart';
import 'AuthenticationService.dart';
import 'TokenManager.dart';

/// Authentication state provider for managing app-wide auth state
class AuthStateProvider extends ChangeNotifier {
  final AuthenticationService _authService;
  final TokenManager _tokenManager;

  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;

  AuthStateProvider({
    AuthenticationService? authService,
    TokenManager? tokenManager,
  })  : _authService = authService ?? AuthenticationService(),
        _tokenManager = tokenManager ?? TokenManager();

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  /// Initialize auth state on app startup
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasValidTokens = await _tokenManager.hasValidTokens();

      if (hasValidTokens) {
        // Try to get current user profile
        _currentUser = await _authService.getCurrentUser();

        if (_currentUser == null) {
          // Tokens exist but user fetch failed, clear tokens
          await _tokenManager.clearTokens();
        }
      }
    } catch (e) {
      // If initialization fails, clear any invalid state
      await _tokenManager.clearTokens();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register with email and password
  Future<bool> register({
    required String email,
    required String password,
    String? name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        email: email,
        password: password,
        name: name,
      );

      if (result.success && result.data != null) {
        _currentUser = result.data!.user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Registration failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        email: email,
        password: password,
      );

      if (result.success && result.data != null) {
        _currentUser = result.data!.user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();

      if (result.success && result.data != null) {
        _currentUser = result.data!.user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Google sign in failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Apple
  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithApple();

      if (result.success && result.data != null) {
        _currentUser = result.data!.user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Apple sign in failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _currentUser = null;
      _errorMessage = null;
    } catch (e) {
      // Even if logout API fails, clear local state
      _currentUser = null;
      _errorMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refresh user data from server
  Future<void> refreshUser() async {
    if (!isAuthenticated) return;

    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      // If refresh fails, user might be logged out
      await logout();
    }
  }
}


