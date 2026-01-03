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

    test('should restore persisted onboarding status', () async {
      // Set persisted values
      await prefs.setBool('onboarding_completed', true);
      await prefs.setBool('guest_mode', true);
      await prefs.setBool('guest_setup_completed', true);

      // Reinitialize provider
      final newProvider = AuthStateProvider(prefs);
      await newProvider.initialize();

      expect(newProvider.isOnboardingCompleted, true);
      expect(newProvider.isGuestMode, true);
      expect(newProvider.guestCompletedSetup, true);
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
    test('should enter guest mode and persist', () async {
      await authProvider.initialize();
      authProvider.enterGuestMode();

      expect(authProvider.isGuestMode, true);
      expect(authProvider.guestCompletedSetup, false);
      expect(prefs.getBool('guest_mode'), true);
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
        password: 'password123',
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
      expect(testProvider.isOnboardingCompleted, true); // Guests skip onboarding
      expect(testProvider.isGuestMode, true);
      expect(testProvider.guestCompletedSetup, false);

      // Complete guest setup
      testProvider.setGuestCompletedSetup();

      // Should mark both guest completion AND onboarding completion
      expect(testProvider.guestCompletedSetup, true);
      expect(testProvider.isOnboardingCompleted, true); // Still true
      expect(testProvider.isGuestMode, true);
    });

    test('Guest completion should persist onboarding status', () async {
      await testProvider.initialize();

      // Enter guest mode
      testProvider.enterGuestMode();

      // Complete guest setup
      testProvider.setGuestCompletedSetup();

      // Create new provider to test persistence
      final provider2 = AuthStateProvider(testPrefs);
      await provider2.initialize();

      // Should restore both guest and onboarding completion
      expect(provider2.guestCompletedSetup, true);
      expect(provider2.isOnboardingCompleted, true);
      expect(provider2.isGuestMode, true);

      provider2.dispose();
    });
  });
}
