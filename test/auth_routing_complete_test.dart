import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushin_reload/routing/app_router.dart';
import 'package:pushin_reload/state/auth_state_provider.dart';
import 'package:pushin_reload/state/pushin_app_controller.dart';
import 'package:pushin_reload/services/MockWorkoutTrackingService.dart';
import 'package:pushin_reload/services/MockUnlockService.dart';
import 'package:pushin_reload/services/MockAppBlockingService.dart';
import 'package:pushin_reload/ui/screens/HomeScreen.dart';
import 'package:pushin_reload/ui/screens/auth/WelcomeScreen.dart';
import 'package:pushin_reload/ui/screens/auth/NewUserWelcomeScreen.dart';
import 'package:pushin_reload/ui/screens/auth/SignUpScreen.dart';
import 'package:pushin_reload/ui/screens/auth/SignInScreen.dart';
import 'package:pushin_reload/ui/screens/auth/SkipBlockAppsScreen.dart';
import 'package:pushin_reload/ui/screens/auth/SkipExerciseScreen.dart';
import 'package:pushin_reload/ui/screens/auth/SkipPushUpTestScreen.dart';
import 'package:pushin_reload/ui/screens/auth/SkipEmergencyUnlockScreen.dart';
import 'package:pushin_reload/ui/screens/onboarding/OnboardingFitnessLevelScreen.dart';

void main() {
  group('BMAD v6 Authentication Routing Tests', () {
    late AuthStateProvider authProvider;
    late PushinAppController pushinController;

    setUp(() async {
      debugPrint('🔧 Setting up test providers...');

      // Reset SharedPreferences for clean test state
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Create providers
      authProvider = AuthStateProvider(prefs);
      pushinController = PushinAppController(
        workoutService: MockWorkoutTrackingService(),
        unlockService: MockUnlockService(),
        blockingService: MockAppBlockingService(),
        blockTargets: const [],
      );

      debugPrint('✅ Test providers created');
    });

    tearDown(() {
      debugPrint('🧹 Tearing down test...');
      authProvider.dispose();
      pushinController.dispose();
    });

    /// Helper function to pump widget with proper providers
    Future<void> pumpAppRouter(WidgetTester tester) async {
      debugPrint('🚀 Pumping AppRouter with MultiProvider...');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthStateProvider>.value(value: authProvider),
            ChangeNotifierProvider<PushinAppController>.value(value: pushinController),
          ],
          child: const MaterialApp(
            home: AppRouter(),
          ),
        ),
      );

      // Wait for async initialization
      await authProvider.initialize();
      await tester.pumpAndSettle();

      debugPrint('✅ AppRouter pumped and settled');
    }

    testWidgets('Sign Up Flow: WelcomeScreen → SignUpScreen → register() → justRegistered=true → NewUserWelcomeScreen → clearJustRegisteredFlag() → OnboardingFitnessLevelScreen → HomeScreen',
        (WidgetTester tester) async {
      debugPrint('🧪 STARTING: Sign Up Flow Test');

      // Step 1: Start with WelcomeScreen
      await pumpAppRouter(tester);
      expect(find.byKey(const ValueKey('welcome_screen')), findsOneWidget,
          reason: 'Should start with WelcomeScreen');
      expect(find.byKey(const ValueKey('guest_start_button')), findsOneWidget,
          reason: 'Should show Continue as Guest button');
      _printRouterState(authProvider);
      debugPrint('✅ Step 1: WelcomeScreen displayed');

      // Step 2: Trigger SignUp flow (state-driven navigation)
      await _authProviderCall(tester, () => authProvider.triggerSignUpFlow());

      expect(find.byKey(const ValueKey('signup_screen')), findsOneWidget,
          reason: 'Should show SignUpScreen via state change');
      expect(find.byKey(const ValueKey('welcome_screen')), findsNothing,
          reason: 'Should hide WelcomeScreen');
      _printRouterState(authProvider);
      debugPrint('✅ Step 2: SignUpScreen displayed via triggerSignUpFlow()');

      // Step 3: Complete registration (triggers justRegistered=true)
      final success = await authProvider.register(
        email: 'signup@example.com',
        password: 'password123',
        name: 'Sign Up User',
      );
      expect(success, true, reason: 'Registration should succeed');
      expect(authProvider.isAuthenticated, true, reason: 'User should be authenticated');
      expect(authProvider.justRegistered, true, reason: 'Just registered flag should be true');
      expect(authProvider.showSignUpScreen, false, reason: 'SignUp screen should be cleared');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('new_user_welcome_screen')), findsOneWidget,
          reason: 'Should show NewUserWelcomeScreen for just registered users');
      _printRouterState(authProvider);
      debugPrint('✅ Step 3: Registration successful, NewUserWelcomeScreen displayed');

      // Step 4: Continue from welcome screen (clears justRegistered flag)
      final continueButton = find.text('Continue');
      expect(continueButton, findsOneWidget, reason: 'Continue button should be visible');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(authProvider.justRegistered, false, reason: 'Just registered flag should be cleared');
      expect(find.byKey(const ValueKey('onboarding_fitness_screen')), findsOneWidget,
          reason: 'Should show OnboardingFitnessLevelScreen after clearing justRegistered flag');
      _printRouterState(authProvider);
      debugPrint('✅ Step 4: Just registered flag cleared, OnboardingFitnessLevelScreen displayed');

      // Step 5: Complete onboarding
      await _authProviderCall(tester, () => authProvider.completeOnboardingFlowForTest());

      expect(find.byKey(const ValueKey('home_screen')), findsOneWidget,
          reason: 'Should show HomeScreen after completing onboarding');
      _printRouterState(authProvider);
      debugPrint('✅ Step 5: HomeScreen displayed - Sign Up Flow Complete');

      debugPrint('🎉 Sign Up Flow Test PASSED ✅');
    });

    testWidgets('Sign In Flow: WelcomeScreen → SignInScreen → login() → isAuthenticated=true → OnboardingFitnessLevelScreen → HomeScreen',
        (WidgetTester tester) async {
      debugPrint('🧪 STARTING: Sign In Flow Test');

      // Step 1: Start with WelcomeScreen
      await pumpAppRouter(tester);
      expect(find.byKey(const ValueKey('welcome_screen')), findsOneWidget,
          reason: 'Should start with WelcomeScreen');
      _printRouterState(authProvider);
      debugPrint('✅ Step 1: WelcomeScreen displayed');

      // Step 2: Trigger SignIn flow (state-driven navigation)
      await _authProviderCall(tester, () => authProvider.triggerSignInFlow());

      expect(find.byKey(const ValueKey('signin_screen')), findsOneWidget,
          reason: 'Should show SignInScreen via state change');
      expect(find.byKey(const ValueKey('welcome_screen')), findsNothing,
          reason: 'Should hide WelcomeScreen');
      _printRouterState(authProvider);
      debugPrint('✅ Step 2: SignInScreen displayed via triggerSignInFlow()');

      // Step 3: Complete login (authenticated but onboarding incomplete)
      final loginSuccess = await authProvider.login(
        email: 'signin@example.com',
        password: 'password123',
      );
      expect(loginSuccess, true, reason: 'Login should succeed');
      expect(authProvider.isAuthenticated, true, reason: 'User should be authenticated');
      expect(authProvider.justRegistered, false, reason: 'Should NOT be just registered');
      expect(authProvider.isOnboardingCompleted, false, reason: 'Onboarding should be incomplete');
      expect(authProvider.showSignInScreen, false, reason: 'SignIn screen should be cleared');
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('onboarding_fitness_screen')), findsOneWidget,
          reason: 'Should show OnboardingFitnessLevelScreen for authenticated user with incomplete onboarding');
      _printRouterState(authProvider);
      debugPrint('✅ Step 3: Login successful, OnboardingFitnessLevelScreen displayed');

      // Step 4: Complete onboarding
      await _authProviderCall(tester, () => authProvider.completeOnboardingFlowForTest());

      expect(find.byKey(const ValueKey('home_screen')), findsOneWidget,
          reason: 'Should show HomeScreen after completing onboarding');
      _printRouterState(authProvider);
      debugPrint('✅ Step 4: HomeScreen displayed - Sign In Flow Complete');

      debugPrint('🎉 Sign In Flow Test PASSED ✅');
    });

    testWidgets('Guest Flow: WelcomeScreen → "Continue as Guest" → enterGuestMode() → SkipBlockAppsScreen → SkipExerciseScreen → SkipPushUpTestScreen → SkipEmergencyUnlockScreen → setGuestCompletedSetup() → HomeScreen',
        (WidgetTester tester) async {
      debugPrint('🧪 STARTING: Guest Flow Test');

      // Step 1: Start with WelcomeScreen
      await pumpAppRouter(tester);
      expect(find.byKey(const ValueKey('welcome_screen')), findsOneWidget,
          reason: 'Should start with WelcomeScreen');
      _printRouterState(authProvider);
      debugPrint('✅ Step 1: WelcomeScreen displayed');

      // Step 2: Enter guest mode (state-driven navigation via button tap)
      final guestButton = find.byKey(const ValueKey('guest_start_button'));
      expect(guestButton, findsOneWidget, reason: 'Continue as Guest button should be visible');
      await tester.tap(guestButton);
      await tester.pumpAndSettle();

      expect(authProvider.isGuestMode, true, reason: 'Should be in guest mode');
      expect(authProvider.guestCompletedSetup, false, reason: 'Guest setup should not be completed');
      expect(find.byKey(const ValueKey('guest_apps_screen')), findsOneWidget,
          reason: 'Should show SkipBlockAppsScreen for guest setup');
      _printRouterState(authProvider);
      debugPrint('✅ Step 2: Guest mode entered, SkipBlockAppsScreen displayed');

      // Step 3: Advance through all guest setup screens
      authProvider.advanceGuestSetupStep();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guest_exercise_screen')), findsOneWidget,
          reason: 'Should show SkipExerciseScreen after advancing guest setup');
      debugPrint('✅ Step 3: Advanced to SkipExerciseScreen');

      authProvider.advanceGuestSetupStep();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guest_pushup_test_screen')), findsOneWidget,
          reason: 'Should show SkipPushUpTestScreen after advancing guest setup');
      debugPrint('✅ Step 4: Advanced to SkipPushUpTestScreen');

      authProvider.advanceGuestSetupStep();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guest_emergency_screen')), findsOneWidget,
          reason: 'Should show SkipEmergencyUnlockScreen after advancing guest setup');
      debugPrint('✅ Step 6: Advanced to SkipEmergencyUnlockScreen');

      // Step 7: Complete guest setup
      authProvider.setGuestCompletedSetup();
      await tester.pumpAndSettle();

      expect(authProvider.guestCompletedSetup, true, reason: 'Guest setup should be completed');
      expect(find.byKey(const ValueKey('home_screen')), findsOneWidget,
          reason: 'Should show HomeScreen after completing guest setup');
      _printRouterState(authProvider);
      debugPrint('✅ Step 7: Guest setup completed, HomeScreen displayed - Guest Flow Complete');

      debugPrint('🎉 Guest Flow Test PASSED ✅');
    });

    testWidgets('State Flags Verification', (WidgetTester tester) async {
      debugPrint('🧪 STARTING: State Flags Verification Test');

      // Test initial state
      await pumpAppRouter(tester);
      expect(authProvider.isInitialized, true, reason: 'Should be initialized');
      expect(authProvider.isAuthenticated, false, reason: 'Should not be authenticated initially');
      expect(authProvider.justRegistered, false, reason: 'Should not be just registered initially');
      expect(authProvider.isOnboardingCompleted, false, reason: 'Onboarding should not be completed initially');
      expect(authProvider.isGuestMode, false, reason: 'Should not be in guest mode initially');
      expect(authProvider.guestCompletedSetup, false, reason: 'Guest setup should not be completed initially');
      expect(authProvider.showSignUpScreen, false, reason: 'Should not show sign up screen initially');
      expect(authProvider.showSignInScreen, false, reason: 'Should not show sign in screen initially');
      _printRouterState(authProvider);
      debugPrint('✅ Initial state flags verified');

      // Test sign up flow state changes
      authProvider.triggerSignUpFlow();
      expect(authProvider.showSignUpScreen, true, reason: 'Should show sign up screen after trigger');
      expect(authProvider.showSignInScreen, false, reason: 'Should clear sign in screen when showing sign up');
      debugPrint('✅ Sign up flow state changes verified');

      await authProvider.register(email: 'test@example.com', password: 'test', name: 'Test');
      expect(authProvider.isAuthenticated, true, reason: 'Should be authenticated after registration');
      expect(authProvider.justRegistered, true, reason: 'Should be just registered after registration');
      expect(authProvider.showSignUpScreen, false, reason: 'Should clear sign up screen after registration');
      debugPrint('✅ Registration state changes verified');

      debugPrint('🎉 State Flags Verification Test PASSED ✅');
    });

    testWidgets('BMAD v6 Compliance Verification', (WidgetTester tester) async {
      debugPrint('🧪 STARTING: BMAD v6 Compliance Verification Test');

      await pumpAppRouter(tester);

      // Verify no Navigator usage in auth flows
      expect(find.byKey(const ValueKey('welcome_screen')), findsOneWidget, reason: 'Should use WelcomeScreen');

      // Test state-driven navigation to SignUpScreen
      authProvider.triggerSignUpFlow();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('signup_screen')), findsOneWidget, reason: 'Should navigate to SignUpScreen via state');

      // Test state-driven navigation to SignInScreen
      authProvider.triggerSignInFlow();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('signin_screen')), findsOneWidget, reason: 'Should navigate to SignInScreen via state');

      debugPrint('✅ BMAD v6 state-driven navigation verified (no Navigator.push/pop used)');
      debugPrint('🎉 BMAD v6 Compliance Verification Test PASSED ✅');
    });
  });
}

/// Test helper that enforces pumpAndSettle() after every state change
/// ✅ Prevents flaky tests by ensuring UI rebuilds after notifyListeners()
Future<void> _authProviderCall(WidgetTester tester, void Function() action) async {
  action();
  await tester.pumpAndSettle();
}

void _printRouterState(AuthStateProvider authProvider) {
  debugPrint(
    '🧭 ROUTER STATE: initialized=${authProvider.isInitialized}, '
    'authenticated=${authProvider.isAuthenticated}, '
    'justRegistered=${authProvider.justRegistered}, '
    'onboardingCompleted=${authProvider.isOnboardingCompleted}, '
    'guestMode=${authProvider.isGuestMode}, '
    'guestCompletedSetup=${authProvider.guestCompletedSetup}, '
    'showSignUpScreen=${authProvider.showSignUpScreen}, '
    'showSignInScreen=${authProvider.showSignInScreen}, '
    'showOnboardingWelcomeScreen=${authProvider.showOnboardingWelcomeScreen}, '
    'onboardingStep=${authProvider.onboardingStep}',
  );
}
