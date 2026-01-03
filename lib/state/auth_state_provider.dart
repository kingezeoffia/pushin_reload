import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/AuthenticationService.dart';

/// Guest setup steps for state-driven navigation
enum GuestSetupStep {
  appsSelection,
  exerciseSelection,
  pushUpTest,
  emergencyUnlock,
  completed,
}

/// Onboarding steps for state-driven navigation
enum OnboardingStep {
  fitnessLevel,
  goals,
  otherGoal,
  workoutHistory,
  blockApps,
  exercise,
  pushUpTest,
  emergencyUnlock,
  completed,
}

/// Minimal auth user model for MVP
class AuthUser {
  final String id;
  final String? email;
  final String? name;

  const AuthUser({
    required this.id,
    this.email,
    this.name,
  });
}

/// Production-ready authentication state provider
///
/// Manages app-wide auth state with SharedPreferences persistence:
/// - Onboarding completion status
/// - Guest mode flag
/// - Guest setup completion
/// - Authentication state
///
/// Key Features:
/// ✅ SharedPreferences persistence
/// ✅ State restoration on app launch
/// ✅ Debug logging for all state changes
/// ✅ Null-safety throughout
/// ✅ Clean architecture patterns
class AuthStateProvider extends ChangeNotifier {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _guestModeKey = 'guest_mode';
  static const String _guestSetupCompletedKey = 'guest_setup_completed';
  static const String _guestSetupStepKey = 'guest_setup_step';
  static const String _onboardingStepKey = 'onboarding_step';
  static const String _showSignUpScreenKey = 'show_sign_up_screen';
  static const String _showSignInScreenKey = 'show_sign_in_screen';

  final SharedPreferences _prefs;
  final AuthenticationService _authService = AuthenticationService();

  // State
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _justRegistered = false;
  bool _isGuestMode = false;
  bool _guestCompletedSetup = false;
  bool _showSignUpScreen = false;
  bool _showSignInScreen = false;
  GuestSetupStep _guestSetupStep = GuestSetupStep.appsSelection;
  OnboardingStep _onboardingStep = OnboardingStep.fitnessLevel;
  bool _isOnboardingCompleted = false;
  String? _errorMessage;
  AuthUser? _currentUser;

  // Onboarding data storage
  String? _fitnessLevel;
  List<String> _goals = [];
  String _otherGoal = '';
  String _workoutHistory = '';
  List<String> _blockedApps = [];
  String? _selectedWorkout;
  int? _unlockDuration;

  AuthStateProvider(this._prefs) {
    debugPrint('🏗️ AuthStateProvider created');
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get justRegistered => _justRegistered;
  bool get isGuestMode => _isGuestMode;
  bool get guestCompletedSetup => _guestCompletedSetup;
  bool get showSignUpScreen => _showSignUpScreen;
  bool get showSignInScreen => _showSignInScreen;
  bool get showOnboardingWelcomeScreen => _justRegistered;
  GuestSetupStep get guestSetupStep => _guestSetupStep;
  OnboardingStep get onboardingStep => _onboardingStep;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  String? get errorMessage => _errorMessage;
  AuthUser? get currentUser => _currentUser;

  // Onboarding data getters
  String? get fitnessLevel => _fitnessLevel;
  List<String> get goals => _goals;
  String get otherGoal => _otherGoal;
  String get workoutHistory => _workoutHistory;
  List<String> get blockedApps => _blockedApps;
  String? get selectedWorkout => _selectedWorkout;
  int? get unlockDuration => _unlockDuration;

  /// Initialize provider and restore persistent state
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🚀 AuthStateProvider.initialize() starting...');

    // Restore persistent state
    _isOnboardingCompleted = _prefs.getBool(_onboardingCompletedKey) ?? false;
    _isGuestMode = _prefs.getBool(_guestModeKey) ?? false;
    _guestCompletedSetup = _prefs.getBool(_guestSetupCompletedKey) ?? false;
    final guestStepIndex = _prefs.getInt(_guestSetupStepKey) ?? 0;
    _guestSetupStep = GuestSetupStep.values[guestStepIndex];
    final onboardingStepIndex = _prefs.getInt(_onboardingStepKey) ?? 0;
    _onboardingStep = OnboardingStep.values[onboardingStepIndex];

    _isInitialized = true;
    _isLoading = false;

    debugPrint('✅ AuthStateProvider initialized:');
    debugPrint('   - onboardingCompleted: $_isOnboardingCompleted');
    debugPrint('   - guestMode: $_isGuestMode');
    debugPrint('   - guestSetupCompleted: $_guestCompletedSetup');
    debugPrint('   - guestSetupStep: $_guestSetupStep');
    debugPrint('   - onboardingStep: $_onboardingStep');

    notifyListeners();
  }

  /// Mark onboarding as completed and persist
  Future<void> markOnboardingCompleted() async {
    if (_isOnboardingCompleted) return;

    _isOnboardingCompleted = true;
    _onboardingStep = OnboardingStep.completed;
    await _prefs.setBool(_onboardingCompletedKey, true);
    await _prefs.setInt(_onboardingStepKey, OnboardingStep.completed.index);

    debugPrint(
        '✅ AuthStateProvider.markOnboardingCompleted() - persisted: true');
    notifyListeners();
  }

  /// Reset onboarding status (for development/testing)
  Future<void> resetOnboarding() async {
    _isOnboardingCompleted = false;
    await _prefs.setBool(_onboardingCompletedKey, false);

    debugPrint('🔄 AuthStateProvider.resetOnboarding() - persisted: false');
    notifyListeners();
  }

  /// Set onboarding step (for testing)
  void setOnboardingStep(OnboardingStep step) {
    _onboardingStep = step;
    debugPrint('🔄 AuthStateProvider.setOnboardingStep() - step: $step');
    notifyListeners();
  }

  /// Enter guest mode and persist
  void enterGuestMode() {
    _isGuestMode = true;
    _guestCompletedSetup = false;
    _guestSetupStep = GuestSetupStep.appsSelection; // Start from first step
    // Guest mode skips onboarding - guest setup IS the onboarding
    _isOnboardingCompleted = true;

    // Clear any sign up/sign in screens when entering guest mode
    _showSignUpScreen = false;
    _showSignInScreen = false;

    _prefs.setBool(_guestModeKey, true);
    _prefs.setBool(_guestSetupCompletedKey, false);
    _prefs.setInt(_guestSetupStepKey, GuestSetupStep.appsSelection.index);
    _prefs.setBool(_onboardingCompletedKey, true);
    _prefs.setBool(_showSignUpScreenKey, false);
    _prefs.setBool(_showSignInScreenKey, false);

    debugPrint(
        '👤 AuthStateProvider.enterGuestMode() - guest mode enabled (onboarding skipped), step: $_guestSetupStep');
    notifyListeners();
  }

  /// Advance to next guest setup step
  void advanceGuestSetupStep() {
    if (!_isGuestMode) return;

    final currentIndex = _guestSetupStep.index;
    if (currentIndex < GuestSetupStep.values.length - 1) {
      _guestSetupStep = GuestSetupStep.values[currentIndex + 1];
      _prefs.setInt(_guestSetupStepKey, _guestSetupStep.index);

      debugPrint('📈 Guest setup advanced to step: $_guestSetupStep');
      notifyListeners();
    }
  }

  /// Advance to next onboarding step
  void advanceOnboardingStep() {
    if (_isGuestMode) return; // Only for authenticated users

    final currentIndex = _onboardingStep.index;
    if (currentIndex < OnboardingStep.values.length - 1) {
      _onboardingStep = OnboardingStep.values[currentIndex + 1];
      _prefs.setInt(_onboardingStepKey, _onboardingStep.index);

      debugPrint('📈 Onboarding advanced to step: $_onboardingStep');
      notifyListeners();
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? email,
    String? name,
    String? password,
  }) async {
    if (_currentUser == null) {
      _errorMessage = 'Not authenticated';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('🔄 AuthStateProvider.updateProfile() - updating profile');

      final result = await _authService.updateProfile(
        email: email,
        name: name,
        password: password,
      );

      if (result.success && result.data != null) {
        // Update local user data
        final updatedUser = result.data!.user;
        _currentUser = AuthUser(
          id: updatedUser.id.toString(),
          email: updatedUser.email,
          name: updatedUser.firstname,
        );

        _isLoading = false;
        debugPrint('✅ AuthStateProvider.updateProfile() - profile updated successfully');
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = result.error ?? 'Profile update failed';
        debugPrint('❌ AuthStateProvider.updateProfile() - failed: ${result.error}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Profile update failed: ${e.toString()}';
      debugPrint('❌ AuthStateProvider.updateProfile() - exception: $e');
      notifyListeners();
      return false;
    }
  }

  /// Set onboarding data
  void setFitnessLevel(String level) {
    _fitnessLevel = level;
    debugPrint('📝 Fitness level set: $level');
  }

  void setGoals(List<String> goals) {
    _goals = goals;
    debugPrint('📝 Goals set: $goals');
  }

  void setOtherGoal(String goal) {
    _otherGoal = goal;
    debugPrint('📝 Other goal set: $goal');
  }

  void setWorkoutHistory(String history) {
    _workoutHistory = history;
    debugPrint('📝 Workout history set: $history');
  }

  void setBlockedApps(List<String> apps) {
    _blockedApps = apps;
    debugPrint('📝 Blocked apps set: $apps');
  }

  void setSelectedWorkout(String workout) {
    _selectedWorkout = workout;
    debugPrint('📝 Selected workout set: $workout');
  }

  void setUnlockDuration(int duration) {
    _unlockDuration = duration;
    debugPrint('📝 Unlock duration set: $duration');
  }

  /// Mark guest setup as completed and persist
  void setGuestCompletedSetup() {
    if (!_isGuestMode) return;

    _guestCompletedSetup = true;
    _guestSetupStep = GuestSetupStep.completed;
    _prefs.setBool(_guestSetupCompletedKey, true);
    _prefs.setInt(_guestSetupStepKey, GuestSetupStep.completed.index);

    // Guest setup = onboarding complete
    _isOnboardingCompleted = true;
    _prefs.setBool(_onboardingCompletedKey, true);

    debugPrint(
      '✅ Guest setup completed (guest remains in guest mode)',
    );
    notifyListeners();
  }

  /// Exit guest mode and persist
  void exitGuestMode() {
    _isGuestMode = false;
    _guestCompletedSetup = false;

    _prefs.setBool(_guestModeKey, false);
    _prefs.setBool(_guestSetupCompletedKey, false);

    debugPrint('👤 AuthStateProvider.exitGuestMode() - guest mode disabled');
    notifyListeners();
  }

  /// Clear just registered flag - called ONLY by NewUserWelcomeScreen
  ///
  /// BMAD v6 State Contract:
  /// ONLY called when user explicitly continues from welcome screen
  /// Transitions: justRegistered = true → justRegistered = false
  void clearJustRegisteredFlag() {
    if (!_justRegistered) return; // Idempotent - no effect if already cleared

    _justRegistered = false;
    debugPrint(
        '🔄 AuthStateProvider.clearJustRegisteredFlag(): false - user continued from welcome screen');
    notifyListeners();
  }

  /// Trigger sign up flow - shows SignUpScreen via state-driven routing
  ///
  /// BMAD v6 State Contract:
  /// State-driven navigation: replaces Navigator.push calls in auth screens
  void triggerSignUpFlow() {
    _showSignUpScreen = true;
    _showSignInScreen = false; // Clear sign in screen when showing sign up
    debugPrint(
        '🔄 AuthStateProvider.triggerSignUpFlow(): true - showing SignUpScreen');
    notifyListeners();
  }

  /// Trigger sign in flow - shows SignInScreen via state-driven routing
  ///
  /// BMAD v6 State Contract:
  /// State-driven navigation: replaces Navigator.push calls in auth screens
  void triggerSignInFlow() {
    _showSignInScreen = true;
    _showSignUpScreen = false; // Clear sign up screen when showing sign in
    debugPrint(
        '🔄 AuthStateProvider.triggerSignInFlow(): true - showing SignInScreen');
    notifyListeners();
  }

  /// Clear sign up flow - hides SignUpScreen
  ///
  /// BMAD v6 State Contract:
  /// Called when user navigates away from SignUpScreen or completes flow
  void clearSignUpFlow() {
    _showSignUpScreen = false;
    debugPrint(
        '🔄 AuthStateProvider.clearSignUpFlow(): false - hiding SignUpScreen');
    notifyListeners();
  }

  /// Clear sign in flow - hides SignInScreen
  ///
  /// BMAD v6 State Contract:
  /// Called when user navigates away from SignInScreen or completes flow
  void clearSignInFlow() {
    _showSignInScreen = false;
    debugPrint(
        '🔄 AuthStateProvider.clearSignInFlow(): false - hiding SignInScreen');
    notifyListeners();
  }

  /// Show onboarding welcome screen
  ///
  /// BMAD v6 State Contract:
  /// Called after NewUserWelcomeScreen to show the onboarding welcome screen

  /// Clear onboarding welcome screen
  ///
  /// BMAD v6 State Contract:
  /// Called when user continues from OnboardingWelcomeScreen to actual onboarding

  /// Complete onboarding flow - canonical method for Emergency Unlock completion
  ///
  /// BMAD v6 State Contract:
  /// Sets all required flags for onboarding completion in correct order
  /// Calls notifyListeners() exactly once to ensure consistent state
  /// ONLY method called by Emergency Unlock screen
  Future<void> completeOnboardingFlow() async {
    // Clear registration and onboarding flags first
    _justRegistered = false;

    // Exit guest mode if currently in it
    _isGuestMode = false;
    _guestCompletedSetup = false;

    // Mark onboarding as completed
    _isOnboardingCompleted = true;
    _onboardingStep = OnboardingStep.completed;

    // Persist onboarding completion
    await _prefs.setBool(_onboardingCompletedKey, true);
    await _prefs.setInt(_onboardingStepKey, OnboardingStep.completed.index);

    // Persist guest mode exit
    await _prefs.setBool(_guestModeKey, false);
    await _prefs.setBool(_guestSetupCompletedKey, false);

    // Required debug print for state tracking
    debugPrint('🧭 FINAL ONBOARDING COMPLETE STATE: initialized=$isInitialized, authenticated=$isAuthenticated, onboardingCompleted=$isOnboardingCompleted, onboardingStep=$onboardingStep, justRegistered=$justRegistered, guestMode=$isGuestMode, guestCompletedSetup=$guestCompletedSetup');

    // Single notifyListeners call for consistent state transition
    notifyListeners();
  }

  /// Complete onboarding flow for tests - sets all flags correctly
  ///
  /// BMAD v6 Test Helper:
  /// Ensures consistent state transitions for test scenarios
  void completeOnboardingFlowForTest() {
    exitGuestMode();
    clearJustRegisteredFlag();
    markOnboardingCompleted();
    notifyListeners();
  }

  /// Set just registered flag - for testing purposes only
  ///
  /// BMAD v6 State Contract:
  /// ONLY used in tests to simulate registration state
  void setJustRegisteredFlag(bool value) {
    _justRegistered = value;
    debugPrint(
        '🔄 AuthStateProvider.setJustRegisteredFlag(): $value - TEST ONLY');
    notifyListeners();
  }

  /// Set onboarding completed flag - for testing purposes only
  ///
  /// BMAD v6 State Contract:
  /// ONLY used in tests to simulate onboarding state
  void setOnboardingCompleted(bool value) {
    _isOnboardingCompleted = value;
    debugPrint(
        '🔄 AuthStateProvider.setOnboardingCompleted(): $value - TEST ONLY');
    notifyListeners();
  }

  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    debugPrint('🔄 AuthStateProvider.setLoading(): $loading');
    notifyListeners();
  }

  /// Set error message
  void setError(String? error) {
    _errorMessage = error;
    debugPrint('❌ AuthStateProvider.setError(): $error');
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    debugPrint('🧹 AuthStateProvider.clearError()');
    notifyListeners();
  }

  /// MVP login implementation - replace with real auth service
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
        // Convert User to AuthUser
        final user = result.data!.user;
        _currentUser = AuthUser(
          id: user.id.toString(),
          email: user.email,
          name: user.firstname,
        );

        // Clear sign-in screen flags since login is complete
        _showSignUpScreen = false;
        _showSignInScreen = false;

        // For sign-in users who haven't completed onboarding, proceed to onboarding flow
        if (!_isOnboardingCompleted) {
          debugPrint(
              '✅ AuthStateProvider.login() - login successful, proceeding to onboarding flow');
        } else {
          debugPrint(
              '✅ AuthStateProvider.login() - login successful, onboarding already completed');
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = result.error ?? 'Login failed';
        debugPrint('❌ AuthStateProvider.login() - failed: ${result.error}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Login failed: ${e.toString()}';
      debugPrint('❌ AuthStateProvider.login() - exception: $e');
      notifyListeners();
      return false;
    }
  }

  /// MVP register implementation - replace with real auth service
  ///
  /// BMAD v6 State Contract:
  /// Success: isAuthenticated = true, justRegistered = true, notifyListeners()
  /// Failure: isAuthenticated = false, justRegistered = false
  Future<bool> register({
    required String email,
    required String password,
    String? name,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    // Explicitly clear any previous state
    _justRegistered = false;
    notifyListeners();

    try {
      final result = await _authService.register(
        email: email,
        password: password,
        name: name,
      );

      if (result.success && result.data != null) {
        // Convert User to AuthUser
        final user = result.data!.user;
        _currentUser = AuthUser(
          id: user.id.toString(),
          email: user.email,
          name: user.firstname,
        );

        // BMAD v6: Explicit state transition - ONLY set here
        _justRegistered = true;
        // CRITICAL FIX: Reset onboarding state for new users
        _isOnboardingCompleted = false;
        _onboardingStep = OnboardingStep.fitnessLevel;
        // Clear any persisted onboarding state that might interfere
        await _prefs.remove(_onboardingStepKey);
        await _prefs.remove(_onboardingCompletedKey);
        // Clear auth screen flags since user completed registration
        _showSignUpScreen = false;
        _showSignInScreen = false;
        _isLoading = false;
        debugPrint(
            '✅ AuthStateProvider.register() - registration successful, justRegistered=true, onboarding reset');
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = result.error ?? 'Registration failed';
        _justRegistered = false;
        debugPrint(
            '❌ AuthStateProvider.register() - failed: ${result.error}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Registration failed: ${e.toString()}';
      // Ensure clean failure state
      _justRegistered = false;
      debugPrint(
          '❌ AuthStateProvider.register() - exception: $e');
      notifyListeners();
      return false;
    }
  }

  /// MVP Google sign-in implementation - replace with real auth service
  ///
  /// BMAD v6 State Contract:
  /// Success: isAuthenticated = true, justRegistered = true, notifyListeners()
  /// Failure: isAuthenticated = false, justRegistered = false
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    _justRegistered = false;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();

      if (result.success && result.data != null) {
        // Convert User to AuthUser
        final user = result.data!.user;
        _currentUser = AuthUser(
          id: user.id.toString(),
          email: user.email,
          name: user.firstname,
        );

        if (result.data!.isNewUser) {
          // New user - show welcome screen and start onboarding
          _justRegistered = true;
          _isOnboardingCompleted = false;
          _onboardingStep = OnboardingStep.fitnessLevel;
          debugPrint(
              '✅ AuthStateProvider.signInWithGoogle() - new user, justRegistered=true, starting onboarding');
        } else {
          // Returning user - don't show welcome screen, respect existing onboarding status
          _justRegistered = false;
          debugPrint(
              '✅ AuthStateProvider.signInWithGoogle() - returning user, onboarding status preserved');
        }

        // Clear auth screen flags since sign-in is complete
        _showSignUpScreen = false;
        _showSignInScreen = false;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = result.error ?? 'Google sign-in failed';
        _justRegistered = false;
        debugPrint(
            '❌ AuthStateProvider.signInWithGoogle() - failed: ${result.error}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Google sign-in failed: ${e.toString()}';
      _justRegistered = false;
      debugPrint(
          '❌ AuthStateProvider.signInWithGoogle() - exception: $e');
      notifyListeners();
      return false;
    }
  }

  /// MVP Apple sign-in implementation - replace with real auth service
  ///
  /// BMAD v6 State Contract:
  /// Success: isAuthenticated = true, justRegistered = true, notifyListeners()
  /// Failure: isAuthenticated = false, justRegistered = false
  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    _justRegistered = false;
    notifyListeners();

    try {
      final result = await _authService.signInWithApple();

      if (result.success && result.data != null) {
        // Convert User to AuthUser
        final user = result.data!.user;
        _currentUser = AuthUser(
          id: user.id.toString(),
          email: user.email,
          name: user.firstname,
        );

        if (result.data!.isNewUser) {
          // New user - show welcome screen and start onboarding
          _justRegistered = true;
          _isOnboardingCompleted = false;
          _onboardingStep = OnboardingStep.fitnessLevel;
          debugPrint(
              '✅ AuthStateProvider.signInWithApple() - new user, justRegistered=true, starting onboarding');
        } else {
          // Returning user - don't show welcome screen, respect existing onboarding status
          _justRegistered = false;
          debugPrint(
              '✅ AuthStateProvider.signInWithApple() - returning user, onboarding status preserved');
        }

        // Clear auth screen flags since sign-in is complete
        _showSignUpScreen = false;
        _showSignInScreen = false;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = result.error ?? 'Apple sign-in failed';
        _justRegistered = false;
        debugPrint(
            '❌ AuthStateProvider.signInWithApple() - failed: ${result.error}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Apple sign-in failed: ${e.toString()}';
      _justRegistered = false;
      debugPrint(
          '❌ AuthStateProvider.signInWithApple() - exception: $e');
      notifyListeners();
      return false;
    }
  }

  /// MVP logout implementation - replace with real auth service
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _authService.logout();

      _currentUser = null;
      _justRegistered = false;
      _errorMessage = null;
      _isLoading = false;

      if (success) {
        debugPrint('✅ AuthStateProvider.logout() - logout successful');
      } else {
        debugPrint('⚠️ AuthStateProvider.logout() - logout completed with warnings');
      }

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Logout failed';
      debugPrint('❌ AuthStateProvider.logout() - exception: $e');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ AuthStateProvider disposed');
    super.dispose();
  }
}
