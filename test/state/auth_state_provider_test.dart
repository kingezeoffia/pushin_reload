import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushin_reload/state/auth_state_provider.dart';

void main() {
  late AuthStateProvider authProvider;
  late SharedPreferences prefs;

  setUp(() async {
    // Setup SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    authProvider = AuthStateProvider(prefs);
  });

  tearDown(() {
    authProvider.dispose();
  });

  group('AuthStateProvider Initialization', () {
    test('should initialize with default values', () async {
      await authProvider.initialize();

      expect(authProvider.isInitialized, true);
      expect(authProvider.isLoading, false);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.justRegistered, false);
      expect(authProvider.isGuestMode, false);
      expect(authProvider.guestCompletedSetup, false);
      expect(authProvider.isOnboardingCompleted, false);
      expect(authProvider.errorMessage, null);
    });

    test(
        'should NOT restore guest mode or onboarding on app restart (forces authentication)',
        () async {
      // Set persisted values as if user was previously in guest mode
      await prefs.setBool('onboarding_completed', true);
      await prefs.setBool('guest_mode', true);
      await prefs.setBool('guest_setup_completed', true);

      // Reinitialize provider (simulates app restart)
      final newProvider = AuthStateProvider(prefs);
      await newProvider.initialize();

      // Guest mode should be cleared on app restart to force authentication
      expect(newProvider.isOnboardingCompleted, false);
      expect(newProvider.isGuestMode, false);
      expect(newProvider.guestCompletedSetup, false);
    });
  });

  group('Onboarding Management', () {
    test('should mark onboarding as completed and persist', () async {
      await authProvider.initialize();
      await authProvider.markOnboardingCompleted();

      expect(authProvider.isOnboardingCompleted, true);
      expect(prefs.getBool('onboarding_completed'), true);
    });

    test('should reset onboarding and persist', () async {
      await authProvider.initialize();
      await authProvider.markOnboardingCompleted();
      await authProvider.resetOnboarding();

      expect(authProvider.isOnboardingCompleted, false);
      expect(prefs.getBool('onboarding_completed'), false);
    });
  });

  group('Guest Mode Management', () {
    test('should enter guest mode for current session only (no persistence)',
        () async {
      await authProvider.initialize();
      authProvider.enterGuestMode();

      expect(authProvider.isGuestMode, true);
      expect(authProvider.guestCompletedSetup, false);
      // Guest mode should NOT persist across app sessions
      expect(prefs.getBool('guest_mode'), false);
      expect(prefs.getBool('guest_setup_completed'), false);
    });

    test('should complete guest setup and persist', () async {
      await authProvider.initialize();
      authProvider.enterGuestMode();
      authProvider.setGuestCompletedSetup();

      expect(authProvider.guestCompletedSetup, true);
      expect(prefs.getBool('guest_setup_completed'), true);
    });

    test('should exit guest mode and persist', () async {
      await authProvider.initialize();
      authProvider.enterGuestMode();
      authProvider.setGuestCompletedSetup();
      authProvider.exitGuestMode();

      expect(authProvider.isGuestMode, false);
      expect(authProvider.guestCompletedSetup, false);
      expect(prefs.getBool('guest_mode'), false);
      expect(prefs.getBool('guest_setup_completed'), false);
    });
  });

  group('Just Registered Flag', () {
    test('should set flag on registration and clear manually', () async {
      await authProvider.initialize();

      // register() should set justRegistered = true
      final success = await authProvider.register(
        email: 'test@example.com',
        password: 'Password123!',
        name: 'Test User',
      );
      expect(success, true);
      expect(authProvider.justRegistered, true);

      // clearJustRegisteredFlag() should clear the flag
      authProvider.clearJustRegisteredFlag();
      expect(authProvider.justRegistered, false);
    });
  });

  group('Loading and Error States', () {
    test('should set and clear loading state', () async {
      await authProvider.initialize();

      authProvider.setLoading(true);
      expect(authProvider.isLoading, true);

      authProvider.setLoading(false);
      expect(authProvider.isLoading, false);
    });

    test('should set and clear error message', () async {
      await authProvider.initialize();

      authProvider.setError('Test error');
      expect(authProvider.errorMessage, 'Test error');

      authProvider.clearError();
      expect(authProvider.errorMessage, null);
    });
  });

  group('Auth Screen Navigation', () {
    test(
        'triggerSignUpFlow should set showSignUpScreen to true and clear showSignInScreen',
        () async {
      await authProvider.initialize();

      // Initially both should be false
      expect(authProvider.showSignUpScreen, false);
      expect(authProvider.showSignInScreen, false);

      // Trigger sign up flow
      authProvider.triggerSignUpFlow();

      // Should set showSignUpScreen to true and showSignInScreen to false
      expect(authProvider.showSignUpScreen, true);
      expect(authProvider.showSignInScreen, false);
    });

    test(
        'triggerSignInFlow should set showSignInScreen to true and clear showSignUpScreen',
        () async {
      await authProvider.initialize();

      // Initially both should be false
      expect(authProvider.showSignUpScreen, false);
      expect(authProvider.showSignInScreen, false);

      // Trigger sign in flow
      authProvider.triggerSignInFlow();

      // Should set showSignInScreen to true and showSignUpScreen to false
      expect(authProvider.showSignInScreen, true);
      expect(authProvider.showSignUpScreen, false);
    });

    test('triggerSignInFlow should force state change even when already set',
        () async {
      await authProvider.initialize();

      // First trigger
      authProvider.triggerSignInFlow();
      expect(authProvider.showSignInScreen, true);
      expect(authProvider.showSignUpScreen, false);

      // Trigger again (should still work)
      authProvider.triggerSignInFlow();
      expect(authProvider.showSignInScreen, true);
      expect(authProvider.showSignUpScreen, false);
    });

    test('clearSignUpFlow should set showSignUpScreen to false', () async {
      await authProvider.initialize();

      // Set sign up screen
      authProvider.triggerSignUpFlow();
      expect(authProvider.showSignUpScreen, true);

      // Clear sign up flow
      authProvider.clearSignUpFlow();
      expect(authProvider.showSignUpScreen, false);
    });

    test('clearSignInFlow should set showSignInScreen to false', () async {
      await authProvider.initialize();

      // Set sign in screen
      authProvider.triggerSignInFlow();
      expect(authProvider.showSignInScreen, true);

      // Clear sign in flow
      authProvider.clearSignInFlow();
      expect(authProvider.showSignInScreen, false);
    });
  });

  group('Guest Completion Flow - Onboarding Integration', () {
    late AuthStateProvider testProvider;
    late SharedPreferences testPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      testPrefs = await SharedPreferences.getInstance();
      testProvider = AuthStateProvider(testPrefs);
    });

    tearDown(() {
      testProvider.dispose();
    });

    test('Guest completion should mark onboarding as completed', () {
      // Enter guest mode (should skip onboarding)
      testProvider.enterGuestMode();
      expect(
          testProvider.isOnboardingCompleted, true); // Guests skip onboarding
      expect(testProvider.isGuestMode, true);
      expect(testProvider.guestCompletedSetup, false);

      // Complete guest setup
      testProvider.setGuestCompletedSetup();

      // Should mark both guest completion AND onboarding completion
      expect(testProvider.guestCompletedSetup, true);
      expect(testProvider.isOnboardingCompleted, true); // Still true
      expect(testProvider.isGuestMode, true);
    });

    test(
        'Guest completion should NOT persist across app sessions (forces authentication)',
        () async {
      await testProvider.initialize();

      // Enter guest mode
      testProvider.enterGuestMode();

      // Complete guest setup
      testProvider.setGuestCompletedSetup();

      // Create new provider to test app restart behavior
      final provider2 = AuthStateProvider(testPrefs);
      await provider2.initialize();

      // Guest state should be cleared on app restart to force authentication
      expect(provider2.guestCompletedSetup, false);
      expect(provider2.isOnboardingCompleted, false);
      expect(provider2.isGuestMode, false);

      provider2.dispose();
    });
  });
}
