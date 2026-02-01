import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushin_reload/main.dart';
import 'package:pushin_reload/state/auth_state_provider.dart';
import 'package:pushin_reload/state/pushin_app_controller.dart';
import 'package:pushin_reload/services/MockAppBlockingService.dart';
import 'package:pushin_reload/services/MockUnlockService.dart';
import 'package:pushin_reload/services/MockWorkoutTrackingService.dart';
import 'package:pushin_reload/services/DailyUsageTracker.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Routing Integration Tests', () {
    late AuthStateProvider authProvider;
    late PushinAppController pushinController;
    late DailyUsageTracker usageTracker;

    setUp(() async {
      // Reset all persistent state for clean test
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      authProvider = AuthStateProvider(prefs);
      await authProvider.initialize();

      usageTracker = DailyUsageTracker();
      await usageTracker.initialize();

      pushinController = PushinAppController(
        workoutService: MockWorkoutTrackingService(),
        unlockService: MockUnlockService(),
        blockingService: MockAppBlockingService(),
        blockTargets: const [],
        authProvider: authProvider,
        usageTracker: usageTracker,
      );
    });

    tearDown(() {
      authProvider.dispose();
    });

    testWidgets(
        'Sign Up Flow: WelcomeScreen → SignUpScreen → register() → NewUserWelcomeScreen → OnboardingFlow → HomeScreen',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthStateProvider>.value(
                value: authProvider),
            ChangeNotifierProvider<PushinAppController>.value(
                value: pushinController),
          ],
          child: const PushinApp(),
        ),
      );

      await tester.pumpAndSettle();

      // 1. START: Verify WelcomeScreen shows for unauthenticated user
      expect(find.byKey(const ValueKey('welcome_screen')), findsOneWidget,
          reason: 'App should start on WelcomeScreen for new users');
      expect(authProvider.isOnboardingCompleted, false,
          reason: 'New users should not have completed onboarding');
      _printRouterState(authProvider);

      // 2. Click "Sign Up" button → triggerSignUpFlow()
      expect(find.text('Sign Up'), findsOneWidget,
          reason: 'Sign Up button should be visible');
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // 3. Verify SignUpScreen appears
      expect(find.byKey(const ValueKey('signup_screen')), findsOneWidget,
          reason: 'SignUpScreen should appear after triggerSignUpFlow()');
      _printRouterState(authProvider);

      // 4. Fill sign up form and submit → register()
      final emailField = find.byType(TextField).at(0);
      final nameField = find.byType(TextField).at(1);
      final passwordField = find.byType(TextField).at(2);

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(nameField, 'Test User');
      await tester.enterText(passwordField, 'StrongPass123!');
      await tester.pumpAndSettle();

      // Click Sign Up button
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // 5. Verify NewUserWelcomeScreen appears (justRegistered=true)
      expect(
          find.byKey(const ValueKey('new_user_welcome_screen')), findsOneWidget,
          reason:
              'NewUserWelcomeScreen should appear after successful registration');
      expect(find.text('Welcome to the'), findsOneWidget,
          reason: 'Welcome to the heading should be visible');
      expect(find.text('FAMILY'), findsOneWidget,
          reason: 'FAMILY heading should be visible');
      _printRouterState(authProvider);

      // 6. Click Continue → clearJustRegisteredFlag() + showOnboardingWelcomeScreen()
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 7. Verify OnboardingWelcomeScreen appears
      expect(find.byKey(const ValueKey('onboarding_welcome_screen')),
          findsOneWidget,
          reason:
              'OnboardingWelcomeScreen should appear after NewUserWelcomeScreen');
      expect(
          find.byKey(const ValueKey('new_user_welcome_screen')), findsNothing,
          reason: 'NewUserWelcomeScreen should disappear after continue');
      _printRouterState(authProvider);

      // 8. Click Get Started → clearOnboardingWelcomeScreen()
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // 9. Verify OnboardingFitnessLevelScreen appears
      expect(find.byKey(const ValueKey('onboarding_fitness_screen')),
          findsOneWidget,
          reason:
              'OnboardingFitnessLevelScreen should appear after OnboardingWelcomeScreen');
      expect(
          find.byKey(const ValueKey('onboarding_welcome_screen')), findsNothing,
          reason: 'OnboardingWelcomeScreen should disappear after Get Started');
      _printRouterState(authProvider);

      // 10. Complete all onboarding steps using state-driven navigation
      // Use AuthStateProvider methods to advance through onboarding

      // Fitness Level → set fitness level and advance
      authProvider.setFitnessLevel('beginner');
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      // Goals screen → set goals and advance
      authProvider.setGoals(['Build muscle', 'Lose weight']);
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      // Workout History screen → set workout history and advance
      authProvider.setWorkoutHistory('3 years');
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      // Block Apps screen → advance (no apps selected)
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      // Exercise screen → set selected workout and advance
      authProvider.setSelectedWorkout('Push-ups');
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      // PushUp Test screen → advance
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      // Unlock Duration screen → set duration and advance
      authProvider.setUnlockDuration(30);
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      // Emergency Unlock screen - simulate Complete Setup button tap
      expect(find.text('Complete Setup'), findsOneWidget,
          reason:
              'Complete Setup button should be visible on emergency unlock screen');

      // Use the new helper method for consistent state management
      authProvider.completeOnboardingFlowForTest();
      await tester.pumpAndSettle();

      // 9. Verify HomeScreen appears after completing onboarding
      expect(find.byKey(const ValueKey('home_screen')), findsOneWidget,
          reason: 'HomeScreen should appear after completing onboarding');
      _printRouterState(authProvider);
    });

    testWidgets(
        'Sign In Flow: SignInScreen → login() → OnboardingFlow → HomeScreen',
        (WidgetTester tester) async {
      // Setup: Simulate existing user who hasn't completed onboarding
      await authProvider.initialize();
      // Sign-in users who haven't completed onboarding should still go through it
      authProvider.setOnboardingCompleted(
          false); // Simulate user who hasn't completed onboarding

      // Launch the app
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthStateProvider>.value(
                value: authProvider),
            ChangeNotifierProvider<PushinAppController>.value(
                value: pushinController),
          ],
          child: const PushinApp(),
        ),
      );

      await tester.pumpAndSettle();

      // 1. START: Verify WelcomeScreen shows
      expect(find.byKey(const ValueKey('welcome_screen')), findsOneWidget,
          reason: 'App should start on WelcomeScreen');
      expect(authProvider.isOnboardingCompleted, false,
          reason: 'Test user should not have completed onboarding');
      _printRouterState(authProvider);

      // 2. Navigate to Sign In (assuming there's a way to get to sign in screen)
      // For this test, we'll directly trigger sign in flow
      authProvider.triggerSignInFlow();
      await tester.pumpAndSettle();

      // 3. Verify SignInScreen appears
      expect(find.byKey(const ValueKey('signin_screen')), findsOneWidget,
          reason: 'SignInScreen should appear after triggerSignInFlow()');
      _printRouterState(authProvider);

      // 4. Fill sign in form and submit → login()
      final emailField = find.byType(TextField).at(0);
      final passwordField = find.byType(TextField).at(1);

      await tester.enterText(emailField, 'existing@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      // Click Sign In button
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // 5. Verify OnboardingWelcomeScreen appears for sign-in users
      expect(find.byKey(const ValueKey('onboarding_welcome_screen')),
          findsOneWidget,
          reason:
              'OnboardingWelcomeScreen should appear for authenticated user without completed onboarding');
      _printRouterState(authProvider);

      // 6. Click Get Started → clearOnboardingWelcomeScreen()
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // 7. Verify onboarding starts
      expect(find.byKey(const ValueKey('onboarding_fitness_screen')),
          findsOneWidget,
          reason:
              'OnboardingFitnessLevelScreen should appear after OnboardingWelcomeScreen');
      _printRouterState(authProvider);

      // 8. Complete onboarding flow using state methods
      authProvider.setFitnessLevel('beginner');
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      authProvider.setGoals(['Build muscle']);
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      authProvider.setWorkoutHistory('2 years');
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      authProvider.advanceOnboardingStep(); // Block apps
      await tester.pumpAndSettle();

      authProvider.setSelectedWorkout('Push-ups');
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      authProvider.advanceOnboardingStep(); // Push-up test
      await tester.pumpAndSettle();

      authProvider.setUnlockDuration(30);
      authProvider.advanceOnboardingStep();
      await tester.pumpAndSettle();

      // Emergency Unlock screen - simulate Complete Setup button
      expect(find.text('Complete Setup'), findsOneWidget,
          reason:
              'Complete Setup button should be visible on emergency unlock screen');

      // Use the new helper method for consistent state management
      authProvider.completeOnboardingFlowForTest();
      await tester.pumpAndSettle();

      // 7. Verify HomeScreen appears
      expect(find.byKey(const ValueKey('home_screen')), findsOneWidget,
          reason: 'HomeScreen should appear after completing onboarding');
      _printRouterState(authProvider);
    });

    testWidgets(
        'Guest Flow: WelcomeScreen → Continue as Guest → GuestSetupScreens → HomeScreen',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthStateProvider>.value(
                value: authProvider),
            ChangeNotifierProvider<PushinAppController>.value(
                value: pushinController),
          ],
          child: const PushinApp(),
        ),
      );

      await tester.pumpAndSettle();

      // 1. START: Verify WelcomeScreen shows
      expect(find.byKey(const ValueKey('welcome_screen')), findsOneWidget,
          reason: 'App should start on WelcomeScreen');
      _printRouterState(authProvider);

      // 2. Click "Continue as Guest" → enterGuestMode()
      await tester.tap(find.text('Continue as Guest'));
      await tester.pumpAndSettle();

      // 3. Verify first guest setup screen appears (SkipBlockAppsScreen)
      expect(find.byKey(const ValueKey('guest_apps_screen')), findsOneWidget,
          reason:
              'SkipBlockAppsScreen should appear after entering guest mode');
      _printRouterState(authProvider);

      // 4. Complete guest setup flow using state methods
      // SkipBlockAppsScreen → SkipExerciseScreen → SkipPushUpTestScreen → SkipEmergencyUnlockScreen

      // Block Apps screen - advance (guest doesn't select apps)
      authProvider.advanceGuestSetupStep();
      await tester.pumpAndSettle();

      // Exercise screen - set workout and advance
      authProvider.setSelectedWorkout('Push-ups');
      authProvider.advanceGuestSetupStep();
      await tester.pumpAndSettle();

      // PushUp Test screen - advance
      authProvider.advanceGuestSetupStep();
      await tester.pumpAndSettle();

      // Unlock Duration screen - set duration and advance
      authProvider.setUnlockDuration(30);
      authProvider.advanceGuestSetupStep();
      await tester.pumpAndSettle();

      // Emergency Unlock screen - complete setup → setGuestCompletedSetup()
      authProvider.setGuestCompletedSetup();
      await tester.pumpAndSettle();

      // 5. Verify HomeScreen appears for completed guest
      expect(find.byKey(const ValueKey('home_screen')), findsOneWidget,
          reason: 'HomeScreen should appear after completing guest setup');
      _printRouterState(authProvider);
    });

    testWidgets(
        'State-driven routing verification - all router flags working correctly',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthStateProvider>.value(
                value: authProvider),
            ChangeNotifierProvider<PushinAppController>.value(
                value: pushinController),
          ],
          child: const PushinApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state: unauthenticated user
      expect(find.byKey(const ValueKey('welcome_screen')), findsOneWidget);
      expect(authProvider.isInitialized, true);
      expect(authProvider.isAuthenticated, false);
      expect(authProvider.justRegistered, false);
      expect(authProvider.isOnboardingCompleted, false);
      expect(authProvider.isGuestMode, false);
      expect(authProvider.guestCompletedSetup, false);
      expect(authProvider.showSignUpScreen, false);
      expect(authProvider.showSignInScreen, false);
      expect(authProvider.showOnboardingWelcomeScreen, false);

      // Test state transitions
      authProvider.triggerSignUpFlow();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('signup_screen')), findsOneWidget);
      expect(authProvider.showSignUpScreen, true);

      // Test sign in flow
      authProvider.triggerSignInFlow();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('signin_screen')), findsOneWidget);
      expect(authProvider.showSignInScreen, true);
      expect(
          authProvider.showSignUpScreen, false); // Should clear sign up screen

      // Test guest mode
      authProvider.enterGuestMode();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('guest_apps_screen')), findsOneWidget);
      expect(authProvider.isGuestMode, true);
      expect(
          authProvider.isOnboardingCompleted, true); // Guest skips onboarding
      expect(authProvider.showSignInScreen, false); // Should clear auth screens

      // Test guest completion
      authProvider.setGuestCompletedSetup();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home_screen')), findsOneWidget);
      expect(authProvider.guestCompletedSetup, true);
    });
  });
}

/// Helper function to print router state for debugging
void _printRouterState(AuthStateProvider authProvider) {
  debugPrint(
    '🧭 ROUTER STATE: initialized=${authProvider.isInitialized}, authenticated=${authProvider.isAuthenticated}, justRegistered=${authProvider.justRegistered}, onboardingCompleted=${authProvider.isOnboardingCompleted}, guestMode=${authProvider.isGuestMode}, guestCompletedSetup=${authProvider.guestCompletedSetup}, showSignUpScreen=${authProvider.showSignUpScreen}, showSignInScreen=${authProvider.showSignInScreen}, showOnboardingWelcomeScreen=${authProvider.showOnboardingWelcomeScreen}, onboardingStep=${authProvider.onboardingStep}',
  );
}
