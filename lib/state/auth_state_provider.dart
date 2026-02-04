import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/AuthenticationService.dart';
import '../services/PaymentService.dart'; // Import central PaymentService
import '../services/TokenManager.dart';

/// Guest setup steps for state-driven navigation
enum GuestSetupStep {
  notificationPermission,
  appsSelection,
  exerciseSelection,
  pushUpTest,
  workoutSuccess,
  emergencyUnlock,
  completed,
}

/// Onboarding steps for state-driven navigation
enum OnboardingStep {
  fitnessLevel,
  goals,
  otherGoal,
  workoutHistory,
  notificationPermission,
  blockApps,
  exercise,
  pushUpTest,
  workoutSuccess,
  emergencyUnlock,
  paywall,
  completed,
}

/// Minimal auth user model for MVP
class AuthUser {
  final String id;
  final String? email;
  final String? name;
  final String? profileImagePath;

  const AuthUser({
    required this.id,
    this.email,
    this.name,
    this.profileImagePath,
  });

  /// Create AuthUser from JSON
  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      name: json['name'] as String?,
      profileImagePath: json['profile_image_path'] as String?,
    );
  }

  /// Convert AuthUser to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profile_image_path': profileImagePath,
    };
  }
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
  static const String _profileImagePathKey = 'profile_image_path';
  static const String _hasUsedAppBeforeKey = 'has_used_app_before';
  static const String _currentUserKey = 'current_user_data';
  static const String _notificationPermissionRequestedKey = 'notification_permission_requested';

  final SharedPreferences _prefs;
  final AuthenticationService _authService = AuthenticationService();

  // Callback to refresh plan tier after auth state changes
  Future<void> Function()? onAuthStateChanged;

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
  bool _notificationPermissionRequested = false;
  String? _errorMessage;
  AuthUser? _currentUser;

  // Guest mode state

  // Profile image state
  String? _profileImagePath;

  // Returning user state
  bool _hasUsedAppBefore = false;

  // Onboarding data storage
  String? _fitnessLevel;
  List<String> _goals = [];
  String _otherGoal = '';
  String _workoutHistory = '';
  List<String> _blockedApps = [];
  String? _selectedWorkout;
  int? _unlockDuration;

  /// Set blocked apps list (used by guest setup)
  void setBlockedApps(List<String> apps) {
    _blockedApps = apps;
    _prefs.setStringList('blocked_apps', apps);
    debugPrint('📝 AuthStateProvider.setBlockedApps: updated ${apps.length} apps');
    notifyListeners();
  }

  AuthStateProvider(this._prefs) {
    debugPrint('🏗️ AuthStateProvider created');
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isAuthenticated {
    final result = _currentUser != null;
    debugPrint(
        '🔐 AuthStateProvider.isAuthenticated: $result (_currentUser: ${_currentUser?.email ?? 'null'})');
    return result;
  }

  bool get justRegistered => _justRegistered;
  bool get isGuestMode => _isGuestMode;
  bool get guestCompletedSetup => _guestCompletedSetup;
  bool get showSignUpScreen => _showSignUpScreen;
  bool get showSignInScreen => _showSignInScreen;
  bool get showOnboardingWelcomeScreen => _justRegistered;
  GuestSetupStep get guestSetupStep => _guestSetupStep;
  OnboardingStep get onboardingStep => _onboardingStep;
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  bool get notificationPermissionRequested => _notificationPermissionRequested;
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

  // Guest mode getters

  // Profile image getters
  String? get profileImagePath => _profileImagePath;

  // Returning user getter
  bool get hasUsedAppBefore => _hasUsedAppBefore;

  /// Initialize provider and restore persistent state
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🚀 AuthStateProvider.initialize() starting...');

    // FIRST: Restore profile image path before any user authentication logic
    _profileImagePath = _prefs.getString(_profileImagePathKey);
    debugPrint('🖼️ Restored profile image path: $_profileImagePath');

    // Then check if user is authenticated
    bool isUserAuthenticated = false;
    try {
      // STARTUP OPTIMIZATION: Try to load user from local cache first
      final userJson = _prefs.getString(_currentUserKey);
      if (userJson != null) {
        try {
          final Map<String, dynamic> userMap =
              Map<String, dynamic>.from(json.decode(userJson) as Map);
          _currentUser = AuthUser.fromJson(userMap);
          isUserAuthenticated = true;
          debugPrint(
              '🚀 FAST START: Loaded cached user: ${_currentUser?.email}');
        } catch (e) {
          debugPrint('⚠️ Error parsing cached user data: $e');
        }
      }

      // If no cached user, try optimistic auth via JWT token
      if (!isUserAuthenticated) {
        try {
          final tokenManager = TokenManager();
          final payload = await tokenManager.getCurrentTokenPayload();
          
          if (payload != null) {
            // Extract minimal user info we can get from token
            final id = payload['id']?.toString() ?? payload['sub']?.toString() ?? '0';
            final email = payload['email']?.toString();
            final name = payload['name']?.toString();
            
            if (email != null) {
              _currentUser = AuthUser(
                id: id,
                email: email,
                name: name,
                profileImagePath: _profileImagePath,
              );
              isUserAuthenticated = true;
              debugPrint('🚀 OPTIMISTIC START: Restored user from token: $email');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Optimistic auth check failed: $e');
        }
      }

      // If we have a cached/optimistic user, we can consider them authenticated
      // But we still need to verify with the server in the background
      if (isUserAuthenticated && _currentUser != null) {
        // Trigger background refresh but don't await it
        _refreshUserData();
      } else {
        // Fallback to traditional check if no cache/token - with TIMEOUT
        // This prevents the infinite loading screen if network is flaky
        try {
          isUserAuthenticated = await _authService.isAuthenticated().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              debugPrint('⚠️ Auth check timed out - assuming not authenticated');
              return false;
            },
          );
        } catch (e) {
           debugPrint('⚠️ Auth check error: $e');
           isUserAuthenticated = false;
        }
        debugPrint('🔐 Authentication check result: $isUserAuthenticated');
      }
    } catch (e) {
      debugPrint(
          '⚠️ Authentication check failed (likely in test environment): $e');
      isUserAuthenticated = false;
    }

    if (isUserAuthenticated) {
      // User is authenticated - restore their user data and onboarding state
      debugPrint(
          '✅ User is authenticated - restoring user data and onboarding state');
      try {
        // Only fetch from server if we don't have user data yet
        if (_currentUser == null) {
          try {
             // Add timeout to this critical path call too
             final user = await _authService.getCurrentUser().timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint('⚠️ GetCurrentUser timed out during init');
                return null;
              },
            );
            
            if (user != null) {
              _currentUser = AuthUser(
                id: user.id.toString(),
                email: user.email,
                name: user.firstname,
                profileImagePath:
                    _profileImagePath, // Now properly restored before this point
              );
              // Save to cache for next time
              _saveCurrentUser(_currentUser!);
            }
          } catch (e) {
             debugPrint('⚠️ Error fetching user during init: $e');
          }
        }

        if (_currentUser != null) {
          debugPrint('✅ Restored authenticated user: ${_currentUser!.email}');

          // For authenticated users, restore onboarding completion
          _isOnboardingCompleted =
              _prefs.getBool(_onboardingCompletedKey) ?? false;
          _onboardingStep =
              OnboardingStep.values[_prefs.getInt(_onboardingStepKey) ?? 0];
          debugPrint(
              '✅ Restored onboarding state: completed=$_isOnboardingCompleted, step=$_onboardingStep');
        } else {
          // If we still don't have a user after all attempts, fail safe
          debugPrint(
              '⚠️ Failed to restore user data, treating as not authenticated');
          isUserAuthenticated = false;
          _currentUser = null;
          // Don't remove key yet, maybe next time it works
        }
      } catch (e) {
        debugPrint('❌ Error restoring authenticated user: $e');
        // If error, treat as not authenticated
        isUserAuthenticated = false;
        _currentUser = null;
      }
    }

    // 4. Fallback for failed authentication check
    if (!isUserAuthenticated || _currentUser == null) {
      // User appears not to be authenticated confirmed
      debugPrint('👤 State: Not authenticated or failed to restore user');

      // CRITICAL CHANGE: Do NOT aggressively clear user data here
      // Network issues or timeouts shouldn't log the user out
      // Only clear if we explicitly want to (like in logout)

      // If we really definitely KNOW they are not authenticated (e.g. 401 response),
      // that logic should happen in the service layer or logout method.
      // For initialization, if we fail to confirm, we should just NOT set current user
      // but keep the cache in case it was just a network error.

      // However, for the UI state, we still default to the "Safe" unauthenticated state
      // so the app doesn't crash.

      // We still clear guest mode for new sessions
      _isGuestMode = false;
      _guestCompletedSetup = false;
      _guestSetupStep = GuestSetupStep.appsSelection;

      // Note: We do NOT remove _currentUserKey here anymore.
      // This protects against "App opens offline -> Auth check fails -> User data deleted -> Welcome screen"
    }
    final onboardingStepIndex = _prefs.getInt(_onboardingStepKey) ?? 0;
    _onboardingStep = OnboardingStep.values[onboardingStepIndex];

    // Restore guest mode state

    // Restore notification permission state
    _notificationPermissionRequested = _prefs.getBool(_notificationPermissionRequestedKey) ?? false;


    // Restore returning user state
    _hasUsedAppBefore = _prefs.getBool(_hasUsedAppBeforeKey) ?? false;

    // Clean up stale transient navigation flags that should never be persisted
    // These are in-memory only and should always start as false on app launch
    await _prefs.remove(_showSignUpScreenKey);
    await _prefs.remove(_showSignInScreenKey);
    _showSignUpScreen = false;
    _showSignInScreen = false;

    _isInitialized = true;
    _isLoading = false;

    debugPrint('✅ AuthStateProvider initialized:');
    debugPrint('   - isAuthenticated: $isAuthenticated');
    debugPrint('   - currentUser: ${_currentUser?.email ?? 'null'}');
    debugPrint('   - onboardingCompleted: $_isOnboardingCompleted');
    debugPrint('   - guestMode: $_isGuestMode');
    debugPrint('   - guestSetupCompleted: $_guestCompletedSetup');
    debugPrint('   - guestSetupStep: $_guestSetupStep');
    debugPrint('   - onboardingStep: $_onboardingStep');
    debugPrint('   - profileImagePath: $_profileImagePath');
    debugPrint('   - hasUsedAppBefore: $_hasUsedAppBefore');
    debugPrint('   - showSignUpScreen: $_showSignUpScreen (transient)');
    debugPrint('   - showSignInScreen: $_showSignInScreen (transient)');

    notifyListeners();
  }

  /// Background refresh of user data
  Future<void> _refreshUserData() async {
    debugPrint('🔄 Background refreshing user data...');
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        final updatedUser = AuthUser(
          id: user.id.toString(),
          email: user.email,
          name: user.firstname,
          profileImagePath: _profileImagePath,
        );

        // Check if anything changed before notifying
        // Basic check on id/email/name
        bool changed = _currentUser?.id != updatedUser.id ||
            _currentUser?.email != updatedUser.email ||
            _currentUser?.name != updatedUser.name;

        if (changed) {
          _currentUser = updatedUser;
          await _saveCurrentUser(updatedUser);
          debugPrint(
              '✅ User data updated in background: ${_currentUser?.email}');
          notifyListeners();
        } else {
          debugPrint('✓ User data is up to date');
        }
      } else {
        // Token might be invalid if getCurrentUser returns null
        debugPrint('⚠️ Background refresh failed: user is null');
        // Ideally we should maybe logout here?
        // For now, let's just log it to avoid abrupt experience
      }
    } catch (e) {
      debugPrint('❌ Error refreshing user data in background: $e');
    }
  }

  /// Helper to save current user to preferences
  Future<void> _saveCurrentUser(AuthUser user) async {
    try {
      final jsonStr = json.encode(user.toJson());
      await _prefs.setString(_currentUserKey, jsonStr);
    } catch (e) {
      debugPrint('❌ Error saving user to cache: $e');
    }
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

  /// Mark that the user has used the app before
  Future<void> _markAppAsUsed() async {
    if (!_hasUsedAppBefore) {
      _hasUsedAppBefore = true;
      await _prefs.setBool(_hasUsedAppBeforeKey, true);
      debugPrint('✅ Marked app as used - user is now a returning user');
    }
  }

  /// Enter guest mode for current session only
  /// Note: Guest mode does NOT persist across app sessions
  /// Users must authenticate when reopening the app
  Future<void> enterGuestMode() async {
    _isGuestMode = true;
    _guestCompletedSetup = false;
    _guestSetupStep = GuestSetupStep.notificationPermission; // Start from first step
    // Guest mode skips onboarding - guest setup IS the onboarding
    _isOnboardingCompleted = true;

    // Clear any sign up/sign in screens when entering guest mode
    _showSignUpScreen = false;
    _showSignInScreen = false;

    // Note: Guest mode persistence is intentionally disabled
    // Guest mode only lasts for the current app session
    await _prefs.setBool(
        _guestModeKey, false); // Explicitly set to false for clarity
    await _prefs.setBool(_guestSetupCompletedKey, false);
    await _prefs.setInt(_guestSetupStepKey, GuestSetupStep.notificationPermission.index);
    await _prefs.setBool(_onboardingCompletedKey, true);

    // Don't persist transient navigation flags - they should always start as false
    // _showSignUpScreen and _showSignInScreen are transient state for navigation

    // Mark that user has used the app
    await _markAppAsUsed();

    debugPrint(
        '👤 AuthStateProvider.enterGuestMode() - guest mode enabled for current session only (onboarding skipped), step: $_guestSetupStep');
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
        debugPrint(
            '🔄 AuthStateProvider.updateProfile() - updating user data: name=${updatedUser.firstname}');
        _currentUser = AuthUser(
          id: updatedUser.id.toString(),
          email: updatedUser.email,
          name: updatedUser.firstname,
          profileImagePath: _profileImagePath,
        );
        
        // Update cache
        await _saveCurrentUser(_currentUser!);

        _isLoading = false;
        debugPrint(
            '✅ AuthStateProvider.updateProfile() - profile updated successfully, new name: ${_currentUser?.name}');
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        _errorMessage = result.error ?? 'Profile update failed';
        debugPrint(
            '❌ AuthStateProvider.updateProfile() - failed: ${result.error}');
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



  void setSelectedWorkout(String workout) {
    _selectedWorkout = workout;
    debugPrint('📝 Selected workout set: $workout');
    notifyListeners();
  }

  void setUnlockDuration(int newDuration) {
    _unlockDuration = newDuration;
    debugPrint('📝 Unlock duration set: $newDuration');
    notifyListeners();
  }

  /// Mark notification permission as requested (flow completed)
  Future<void> markNotificationPermissionRequested() async {
    if (_notificationPermissionRequested) return;
    
    _notificationPermissionRequested = true;
    await _prefs.setBool(_notificationPermissionRequestedKey, true);
    debugPrint('📝 Notification permission requested marked as true');
    notifyListeners();
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
    debugPrint('🔄 AuthStateProvider.triggerSignUpFlow() CALLED');
    debugPrint(
        '   - Before: showSignUpScreen=$_showSignUpScreen, showSignInScreen=$_showSignInScreen');

    _showSignUpScreen = true;
    _showSignInScreen = false; // Clear sign in screen when showing sign up

    debugPrint(
        '   - After: showSignUpScreen=$_showSignUpScreen, showSignInScreen=$_showSignInScreen');
    debugPrint('   - Calling notifyListeners() to trigger router rebuild...');

    notifyListeners();

    debugPrint(
        '   - ✅ notifyListeners() completed - router should show SignUpScreen');
  }

  /// Trigger sign in flow - shows SignInScreen via state-driven routing
  ///
  /// BMAD v6 State Contract:
  /// State-driven navigation: replaces Navigator.push calls in auth screens
  void triggerSignInFlow() {
    debugPrint('🔄 AuthStateProvider.triggerSignInFlow() CALLED');
    debugPrint(
        '   - Before: showSignUpScreen=$_showSignUpScreen, showSignInScreen=$_showSignInScreen');

    // Always trigger a rebuild by temporarily clearing and re-setting flags
    // This ensures navigation happens even if flags were already set
    final wasSignInScreen = _showSignInScreen;
    final wasSignUpScreen = _showSignUpScreen;

    // Temporarily clear both flags to force a state change
    _showSignInScreen = false;
    _showSignUpScreen = false;

    // Then set the desired state
    _showSignInScreen = true;
    _showSignUpScreen = false; // Clear sign up screen when showing sign in

    debugPrint(
        '   - After: showSignUpScreen=$_showSignUpScreen, showSignInScreen=$_showSignInScreen');
    debugPrint(
        '   - Was already set: signIn=$wasSignInScreen, signUp=$wasSignUpScreen');
    debugPrint('   - Calling notifyListeners() to trigger router rebuild...');

    notifyListeners();

    debugPrint(
        '   - ✅ notifyListeners() completed - router should show SignInScreen');
  }

  /// Clear sign up flow - hides SignUpScreen
  ///
  /// BMAD v6 State Contract:
  /// Called when user navigates away from SignUpScreen or completes flow
  void clearSignUpFlow() {
    debugPrint('🔄 AuthStateProvider.clearSignUpFlow() CALLED');
    _showSignUpScreen = false;
    debugPrint('   - showSignUpScreen set to: $_showSignUpScreen');
    notifyListeners();
  }

  /// Clear sign in flow - hides SignInScreen
  ///
  /// BMAD v6 State Contract:
  /// Called when user navigates away from SignInScreen or completes flow
  void clearSignInFlow() {
    debugPrint('🔄 AuthStateProvider.clearSignInFlow() CALLED');
    _showSignInScreen = false;
    debugPrint('   - showSignInScreen set to: $_showSignInScreen');
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
    debugPrint(
        '🧭 FINAL ONBOARDING COMPLETE STATE: initialized=$isInitialized, authenticated=$isAuthenticated, onboardingCompleted=$isOnboardingCompleted, onboardingStep=$onboardingStep, justRegistered=$justRegistered, guestMode=$isGuestMode, guestCompletedSetup=$guestCompletedSetup');

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
          profileImagePath: _profileImagePath,
        );

        // Save to cache
        await _saveCurrentUser(_currentUser!);

        // Exit guest mode if user was previously a guest
        if (_isGuestMode) {
          exitGuestMode();
        }

        // CRITICAL FIX: Fetch fresh subscription status from server
        // This ensures the new user's actual subscription status is loaded
        await _fetchFreshSubscriptionStatus();

        // Clear sign-in screen flags since login is complete
        _showSignUpScreen = false;
        _showSignInScreen = false;

        // For returning users who sign in, assume onboarding is completed
        // This prevents first-time app downloads from showing onboarding for existing users
        _isOnboardingCompleted = true;
        _onboardingStep = OnboardingStep.completed;
        await _prefs.setBool(_onboardingCompletedKey, true);
        await _prefs.setInt(_onboardingStepKey, OnboardingStep.completed.index);

        debugPrint(
            '✅ AuthStateProvider.login() - login successful, marking onboarding as completed for returning user');

        // Mark that user has used the app
        await _markAppAsUsed();

        _isLoading = false;
        notifyListeners();

        // CRITICAL FIX: Notify that auth state changed so plan tier can be refreshed
        // This must happen after notifyListeners() above to ensure auth state is updated
        try {
          await onAuthStateChanged?.call();
          debugPrint(
              '✅ AuthStateProvider.login() - plan tier refresh callback completed');
        } catch (e) {
          debugPrint(
              '❌ AuthStateProvider.login() - Error in plan tier refresh callback: $e');
        }

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
          profileImagePath: _profileImagePath,
        );

        // Exit guest mode if user was previously a guest
        if (_isGuestMode) {
          exitGuestMode();
        }

        // CRITICAL FIX: Fetch fresh subscription status from server
        // This ensures the new user's actual subscription status is loaded
        await _fetchFreshSubscriptionStatus();

        // BMAD v6: Explicit state transition - ONLY set here
        _justRegistered = true;

        // If user was previously in guest mode, they already completed onboarding
        // Preserve their onboarding completion and current step
        final wasGuestMode = _isGuestMode;
        if (wasGuestMode) {
          debugPrint(
              '🔄 User was previously in guest mode - preserving onboarding completion');
          // Don't reset onboarding state for users who sign up after being guests
          // Keep their current onboarding state (should already be completed)
        } else {
          // Reset onboarding state for completely new users
          _isOnboardingCompleted = false;
          _onboardingStep = OnboardingStep.fitnessLevel;
          // Clear any persisted onboarding state that might interfere
          await _prefs.remove(_onboardingStepKey);
          await _prefs.remove(_onboardingCompletedKey);
        }
        // Clear auth screen flags since user completed registration
        _showSignUpScreen = false;
        _showSignInScreen = false;

        // Mark that user has used the app
        await _markAppAsUsed();

        _isLoading = false;
        debugPrint(
            '✅ AuthStateProvider.register() - registration successful, justRegistered=true, onboarding reset');
        notifyListeners();

        // Notify that auth state changed so plan tier can be refreshed
        await onAuthStateChanged?.call();

        return true;
      } else {
        _isLoading = false;
        _errorMessage = result.error ?? 'Registration failed';
        _justRegistered = false;
        debugPrint('❌ AuthStateProvider.register() - failed: ${result.error}');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Registration failed: ${e.toString()}';
      // Ensure clean failure state
      _justRegistered = false;
      debugPrint('❌ AuthStateProvider.register() - exception: $e');
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
          profileImagePath: _profileImagePath,
        );

        // Exit guest mode if user was previously a guest
        if (_isGuestMode) {
          exitGuestMode();
        }

        // CRITICAL FIX: Fetch fresh subscription status from server
        // This ensures the user's actual subscription status is loaded
        await _fetchFreshSubscriptionStatus();

        if (result.data!.isNewUser) {
          // New user - show welcome screen and start onboarding
          _justRegistered = true;
          _isOnboardingCompleted = false;
          _onboardingStep = OnboardingStep.fitnessLevel;
          debugPrint(
              '✅ AuthStateProvider.signInWithGoogle() - new user, justRegistered=true, starting onboarding');
        } else {
          // Returning user - don't show welcome screen, mark onboarding as completed
          _justRegistered = false;
          _isOnboardingCompleted = true;
          _onboardingStep = OnboardingStep.completed;
          await _prefs.setBool(_onboardingCompletedKey, true);
          await _prefs.setInt(
              _onboardingStepKey, OnboardingStep.completed.index);
          debugPrint(
              '✅ AuthStateProvider.signInWithGoogle() - returning user, onboarding marked as completed');
        }

        // Clear auth screen flags since sign-in is complete
        _showSignUpScreen = false;
        _showSignInScreen = false;

        // Mark that user has used the app
        await _markAppAsUsed();

        _isLoading = false;
        notifyListeners();

        // Notify that auth state changed so plan tier can be refreshed
        await onAuthStateChanged?.call();

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
      debugPrint('❌ AuthStateProvider.signInWithGoogle() - exception: $e');
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
          profileImagePath: _profileImagePath,
        );

        // Exit guest mode if user was previously a guest
        if (_isGuestMode) {
          exitGuestMode();
        }

        // CRITICAL FIX: Fetch fresh subscription status from server
        // This ensures the user's actual subscription status is loaded
        await _fetchFreshSubscriptionStatus();

        if (result.data!.isNewUser) {
          // New user - show welcome screen and start onboarding
          _justRegistered = true;
          _isOnboardingCompleted = false;
          _onboardingStep = OnboardingStep.fitnessLevel;
          debugPrint(
              '✅ AuthStateProvider.signInWithApple() - new user, justRegistered=true, starting onboarding');
        } else {
          // Returning user - don't show welcome screen, mark onboarding as completed
          _justRegistered = false;
          _isOnboardingCompleted = true;
          _onboardingStep = OnboardingStep.completed;
          await _prefs.setBool(_onboardingCompletedKey, true);
          await _prefs.setInt(
              _onboardingStepKey, OnboardingStep.completed.index);
          debugPrint(
              '✅ AuthStateProvider.signInWithApple() - returning user, onboarding marked as completed');
        }

        // Clear auth screen flags since sign-in is complete
        _showSignUpScreen = false;
        _showSignInScreen = false;

        // Mark that user has used the app
        await _markAppAsUsed();

        _isLoading = false;
        notifyListeners();

        // Notify that auth state changed so plan tier can be refreshed
        await onAuthStateChanged?.call();

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
      debugPrint('❌ AuthStateProvider.signInWithApple() - exception: $e');
      notifyListeners();
      return false;
    }
  }

  /// MVP logout implementation - replace with real auth service
  Future<void> logout() async {
    debugPrint('🧹🧹🧹 ═══════════════════════════════════════════════');
    debugPrint('🧹🧹🧹 AuthStateProvider.logout() CALLED');
    debugPrint('🧹 Current state BEFORE logout:');
    debugPrint('   - isAuthenticated: $isAuthenticated');
    debugPrint('   - currentUser: ${_currentUser?.email ?? 'null'}');
    debugPrint('   - isGuestMode: $isGuestMode');
    debugPrint('   - isOnboardingCompleted: $isOnboardingCompleted');
    debugPrint('🧹 ═══════════════════════════════════════════════');

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🧹 Calling _authService.logout()...');
      final success = await _authService.logout();
      debugPrint('🧹 _authService.logout() returned: $success');

      // Clear user state
      debugPrint('🧹 Clearing user state...');
      _currentUser = null;
      _justRegistered = false;
      _errorMessage = null;
      _isLoading = false;
      debugPrint('🧹 User state cleared: _currentUser = $_currentUser');

      // CRITICAL: Clear all subscription-related cached data
      // This prevents subscription data from persisting across different user accounts

      // 1. Clear subscription cache completely using the service
      // This removes ID, plan, status - everything.
      // 1. Clear subscription cache manually
      // This removes ID, plan, status - everything.
      await _prefs.remove('cached_subscription_status');
      if (_currentUser?.id != null) {
          await _prefs.remove('cached_subscription_status_${_currentUser!.id}');
      }

      // 3. Clear profile image
      await removeProfileImage();

      // 4. CRITICAL FIX: Reset onboarding state to force user back to auth screens
      // This ensures the router shows WelcomeScreen instead of MainTabNavigation
      _isOnboardingCompleted = false;
      _onboardingStep = OnboardingStep.fitnessLevel;
      await _prefs.setBool(_onboardingCompletedKey, false);
      await _prefs.setInt(
          _onboardingStepKey, OnboardingStep.fitnessLevel.index);

      // 5. Clear guest mode state
      _isGuestMode = false;
      _guestCompletedSetup = false;
      _guestSetupStep = GuestSetupStep.appsSelection;
      await _prefs.setBool(_guestModeKey, false);
      await _prefs.setBool(_guestSetupCompletedKey, false);
      await _prefs.setInt(
          _guestSetupStepKey, GuestSetupStep.appsSelection.index);

      // 6. Clear any sign-up/sign-in screen flags
      _showSignUpScreen = false;
      _showSignInScreen = false;

      debugPrint(
          '🧹 AuthStateProvider.logout() - cleared all subscription, profile, onboarding, and guest mode data');
      debugPrint('🧹 Logout state check:');
      debugPrint('   - isAuthenticated: $isAuthenticated');
      debugPrint('   - isGuestMode: $isGuestMode');
      debugPrint('   - isOnboardingCompleted: $isOnboardingCompleted');
      debugPrint('   - guestCompletedSetup: $guestCompletedSetup');
      debugPrint('   - showSignUpScreen: $showSignUpScreen');
      debugPrint('   - showSignInScreen: $showSignInScreen');
      debugPrint('   - justRegistered: $justRegistered');

      // Verify state is correct for showing WelcomeScreen
      assert(!isAuthenticated, 'After logout, isAuthenticated should be false');
      assert(!isGuestMode, 'After logout, isGuestMode should be false');
      assert(!isOnboardingCompleted,
          'After logout, isOnboardingCompleted should be false');
      assert(
          !showSignUpScreen, 'After logout, showSignUpScreen should be false');
      assert(
          !showSignInScreen, 'After logout, showSignInScreen should be false');

      if (success) {
        debugPrint('✅ AuthStateProvider.logout() - logout successful');
      } else {
        debugPrint(
            '⚠️ AuthStateProvider.logout() - logout completed with warnings');
      }

      debugPrint(
          '🔔 Calling notifyListeners() to trigger router rebuild to WelcomeScreen...');
      notifyListeners();

      // 7. Notify that auth state changed so plan tier can be refreshed to 'free'
      // This is called ONCE after all state is cleared
      debugPrint(
          '🔄 Notifying PushinAppController to refresh plan tier to free...');
      try {
        await onAuthStateChanged?.call();
        debugPrint('✅ Plan tier refresh callback completed');
      } catch (e) {
        debugPrint('❌ Error in plan tier refresh callback: $e');
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Logout failed';
      debugPrint('❌ AuthStateProvider.logout() - exception: $e');
      notifyListeners();
    }
  }

  /// Forgot password - send reset email
  Future<bool> forgotPassword({required String email}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.forgotPassword(email: email);

      if (result.success) {
        debugPrint('✅ Forgot password email sent to: $email');
        return true;
      } else {
        _errorMessage = result.error ?? 'Failed to send reset email';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('💥 Forgot password error: $e');
      _errorMessage = 'Network error occurred';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset password using token
  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.resetPassword(
        token: token,
        newPassword: newPassword,
      );

      if (result.success) {
        debugPrint('✅ Password reset successful');
        return true;
      } else {
        _errorMessage = result.error ?? 'Failed to reset password';
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('💥 Reset password error: $e');
      _errorMessage = 'Network error occurred';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch fresh subscription status from server and update cache
  Future<void> _fetchFreshSubscriptionStatus() async {
    if (_currentUser == null) {
      debugPrint('⚠️ _fetchFreshSubscriptionStatus called but no current user');
      return;
    }

    debugPrint('🔄 ═══════════════════════════════════════════════');
    debugPrint('🔄 _fetchFreshSubscriptionStatus() called');
    debugPrint('   - User ID: ${_currentUser!.id}');
    debugPrint('   - User Email: ${_currentUser!.email}');
    debugPrint('🔄 ═══════════════════════════════════════════════');

    try {
      final paymentService = PaymentConfig.createService();

      // Fetch fresh subscription status from server
      final subscriptionStatus = await paymentService.checkSubscriptionStatus(
        userId: _currentUser!.id,
      );

      if (subscriptionStatus != null && subscriptionStatus.isActive) {
        debugPrint('✅ Fresh subscription status fetched:');
        debugPrint('   - planId: ${subscriptionStatus.planId}');
        debugPrint('   - isActive: ${subscriptionStatus.isActive}');
        debugPrint('   - customerId: ${subscriptionStatus.customerId}');
        debugPrint('   - subscriptionId: ${subscriptionStatus.subscriptionId}');
        debugPrint(
            '   - currentPeriodEnd: ${subscriptionStatus.currentPeriodEnd}');

        // CRITICAL: Save with the correct user ID to ensure persistence
        final statusWithUserId = SubscriptionStatus(
          isActive: subscriptionStatus.isActive,
          planId: subscriptionStatus.planId,
          customerId: subscriptionStatus.customerId,
          subscriptionId: subscriptionStatus.subscriptionId,
          currentPeriodEnd: subscriptionStatus.currentPeriodEnd,
          cachedUserId: _currentUser!.id, // Associate with authenticated user
        );
        await paymentService.saveSubscriptionStatus(statusWithUserId);
        debugPrint(
            '✅ Subscription cache updated with userId: ${_currentUser!.id}');
      } else {
        debugPrint(
            'ℹ️ No active subscription found on server for user: ${_currentUser!.id}');
        // Don't cache 'free' status here - let refreshPlanTier handle it
        // This prevents race conditions between different caching points
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching fresh subscription status: $e');
      debugPrint('   Stack trace: $stackTrace');
    }
  }

  /// Crop selected image
  Future<File?> cropImage(File imageFile) async {
    try {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(
            ratioX: 1, ratioY: 1), // Square aspect ratio for profile pictures
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Profile Picture',
            toolbarColor: const Color(0xFF1A1A1A),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Adjust Profile Picture',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateClockwiseButtonHidden: false,
            rotateButtonsHidden: false,
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error cropping image: $e');
      return null;
    }
  }

  /// Pick profile image from gallery or camera with cropping
  Future<bool> pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024, // Higher resolution for better cropping
        maxHeight: 1024,
        imageQuality: 90, // Better quality for cropping
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);

        // Allow user to crop the image
        File? croppedImage = await cropImage(imageFile);

        if (croppedImage != null) {
          // Get app documents directory
          final directory = await getApplicationDocumentsDirectory();
          final imageName =
              'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedImage = File('${directory.path}/$imageName');

          // Copy the cropped file to app directory
          await croppedImage.copy(savedImage.path);

          // Store the path
          await setProfileImagePath(savedImage.path);

          debugPrint('✅ Profile image cropped and saved: ${savedImage.path}');
          return true;
        } else {
          // User cancelled cropping
          debugPrint('ℹ️ User cancelled image cropping');
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error picking/cropping profile image: $e');
      return false;
    }
  }

  /// Set profile image path and persist
  Future<void> setProfileImagePath(String? path) async {
    _profileImagePath = path;
    if (path != null) {
      await _prefs.setString(_profileImagePathKey, path);
    } else {
      await _prefs.remove(_profileImagePathKey);
    }

    // Update current user with new profile image path
    if (_currentUser != null) {
      _currentUser = AuthUser(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        profileImagePath: path,
      );
      await _saveCurrentUser(_currentUser!);
    }

    debugPrint('🔄 Profile image path updated: $path');
    notifyListeners();
  }

  /// Remove profile image
  Future<void> removeProfileImage() async {
    if (_profileImagePath != null) {
      try {
        final imageFile = File(_profileImagePath!);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (e) {
        debugPrint('⚠️ Error deleting profile image file: $e');
      }
    }
    await setProfileImagePath(null);
  }

  @override
  void dispose() {
    debugPrint('🗑️ AuthStateProvider disposed');
    super.dispose();
  }
}
