import 'package:flutter/foundation.dart';
import 'AuthenticationService.dart';
import 'OnboardingService.dart';

/// Authentication state provider for managing app-wide auth state
/// Simplified version with only the three core flags plus basic auth state
class AuthStateProvider extends ChangeNotifier {
  final AuthenticationService _authService = AuthenticationService();

  User? _currentUser;
  bool _isLoading = false;
  bool _justRegistered = false;
  bool _isGuestMode = false;
  bool _guestCompletedSetup = false;
  bool _isOnboardingCompleted = false;
  bool _showSignUpScreen = false;
  bool _showSignInScreen = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get justRegistered => _justRegistered;
  bool get isGuestMode => _isGuestMode;
  bool get guestCompletedSetup => _guestCompletedSetup;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get showSignUpScreen => _showSignUpScreen;
  bool get showSignInScreen => _showSignInScreen;
  String? get errorMessage => _errorMessage;

  /// Initialize auth state (minimal version for simplified provider)
  Future<void> initialize() async {
    // Load onboarding completion status from persistent storage
    await loadOnboardingStatus();

    // Minimal initialization - no complex auth logic
    _isLoading = false;

    debugPrint('🔄 AuthStateProvider initialized:');
    debugPrint('   - justRegistered: $_justRegistered');
    debugPrint('   - isGuestMode: $_isGuestMode');
    debugPrint('   - guestCompletedSetup: $_guestCompletedSetup');
    debugPrint('   - isOnboardingCompleted: $_isOnboardingCompleted');

    notifyListeners();
  }

  /// Load onboarding completion status from SharedPreferences
  Future<void> loadOnboardingStatus() async {
    _isOnboardingCompleted = await OnboardingService.isOnboardingCompleted();
    debugPrint(
        '📋 AuthStateProvider.loadOnboardingStatus(): loaded $_isOnboardingCompleted');
  }

  /// Mark onboarding as completed and persist the status
  Future<void> markOnboardingCompleted() async {
    await OnboardingService.markOnboardingCompleted();
    _isOnboardingCompleted = true;
    debugPrint('✅ AuthStateProvider.markOnboardingCompleted(): set to true');
    notifyListeners();
  }

  // State management methods
  void setJustRegisteredFlag(bool value) {
    _justRegistered = value;
    debugPrint('🔄 AuthStateProvider.setJustRegisteredFlag(): $value');
    notifyListeners();
  }

  void clearJustRegisteredFlag() {
    _justRegistered = false;
    debugPrint('🔄 AuthStateProvider.clearJustRegisteredFlag(): false');
    notifyListeners();
  }

  void enterGuestMode() {
    _isGuestMode = true;
    _guestCompletedSetup = false;
    debugPrint(
        '🔄 AuthStateProvider.enterGuestMode(): guest mode enabled, setup reset');
    notifyListeners();
  }

  void setGuestCompletedSetup() {
    _guestCompletedSetup = true;
    debugPrint('🔄 AuthStateProvider.setGuestCompletedSetup(): true');
    notifyListeners();
  }

  void exitGuestMode() {
    _isGuestMode = false;
    _guestCompletedSetup = false;
    debugPrint(
        '🔄 AuthStateProvider.exitGuestMode(): guest mode disabled, setup reset');
    notifyListeners();
  }

  /// Trigger sign up flow - shows SignUpScreen via state-driven routing
  void triggerSignUpFlow() {
    _showSignUpScreen = true;
    _showSignInScreen = false; // Clear sign in screen when showing sign up
    debugPrint(
        '🔄 AuthStateProvider.triggerSignUpFlow(): true - showing SignUpScreen');
    notifyListeners();
  }

  /// Trigger sign in flow - shows SignInScreen via state-driven routing
  void triggerSignInFlow() {
    _showSignInScreen = true;
    _showSignUpScreen = false; // Clear sign up screen when showing sign in
    debugPrint(
        '🔄 AuthStateProvider.triggerSignInFlow(): true - showing SignInScreen');
    notifyListeners();
  }

  /// Clear sign up flow - hides SignUpScreen
  void clearSignUpFlow() {
    _showSignUpScreen = false;
    debugPrint(
        '🔄 AuthStateProvider.clearSignUpFlow(): false - hiding SignUpScreen');
    notifyListeners();
  }

  /// Clear sign in flow - hides SignInScreen
  void clearSignInFlow() {
    _showSignInScreen = false;
    debugPrint(
        '🔄 AuthStateProvider.clearSignInFlow(): false - hiding SignInScreen');
    notifyListeners();
  }

  // Authentication methods
  Future<bool> register({
    required String email,
    required String password,
    String? name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.register(
      email: email,
      password: password,
      name: name,
    );

    _isLoading = false;

    if (result.success) {
      _currentUser = result.data!.user;
      _justRegistered = true;
      _errorMessage = null;
    } else {
      _errorMessage = result.error;
    }

    notifyListeners();
    return result.success;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _authService.login(
      email: email,
      password: password,
    );

    _isLoading = false;

    if (result.success) {
      _currentUser = result.data!.user;
      _errorMessage = null;
    } else {
      _errorMessage = result.error;
    }

    notifyListeners();
    return result.success;
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    _justRegistered = false;
    notifyListeners();

    final result = await _authService.signInWithGoogle();

    _isLoading = false;

    if (result.success) {
      _currentUser = result.data!.user;
      _justRegistered = true;
      _errorMessage = null;
      // Clear auth screen flags since sign-in is complete
      _showSignUpScreen = false;
      _showSignInScreen = false;
    } else {
      _errorMessage = result.error;
    }

    notifyListeners();
    return result.success;
  }

  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    _justRegistered = false;
    notifyListeners();

    final result = await _authService.signInWithApple();

    _isLoading = false;

    if (result.success) {
      _currentUser = result.data!.user;
      _justRegistered = true;
      _errorMessage = null;
      // Clear auth screen flags since sign-in is complete
      _showSignUpScreen = false;
      _showSignInScreen = false;
    } else {
      _errorMessage = result.error;
    }

    notifyListeners();
    return result.success;
  }

  Future<bool> logout() async {
    _isLoading = true;
    notifyListeners();

    final success = await _authService.logout();

    _isLoading = false;
    _currentUser = null;
    _justRegistered = false;
    _errorMessage = null;

    notifyListeners();
    return success;
  }
}
