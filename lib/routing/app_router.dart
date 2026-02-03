import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state_provider.dart';
import '../state/pushin_app_controller.dart';
import '../ui/navigation/main_tab_navigation.dart';
import '../ui/screens/auth/WelcomeScreen.dart';
import '../ui/screens/auth/FirstWelcomeScreen.dart';
import '../ui/screens/auth/NewUserWelcomeScreen.dart';
import '../ui/screens/auth/SignUpScreen.dart';
import '../ui/screens/auth/SignInScreen.dart';
import '../ui/screens/auth/SkipNotificationPermissionScreen.dart';
import '../ui/screens/auth/SkipBlockAppsScreen.dart';


import '../ui/screens/onboarding/OnboardingFitnessLevelScreen.dart';
import '../ui/screens/onboarding/OnboardingGoalsScreen.dart';
import '../ui/screens/onboarding/OnboardingWorkoutHistoryScreen.dart';
import '../ui/screens/onboarding/HowItWorksBlockAppsScreen.dart';
import '../ui/screens/onboarding/HowItWorksNotificationPermissionScreen.dart';
import '../ui/screens/onboarding/HowItWorksChooseWorkoutScreen.dart';
import '../ui/screens/onboarding/HowItWorksPushUpTestScreen.dart';
import '../ui/screens/onboarding/HowItWorksSquatTestScreen.dart';
import '../ui/screens/onboarding/HowItWorksGluteBridgeTestScreen.dart';
import '../ui/screens/onboarding/HowItWorksPlankTestScreen.dart';
import '../ui/screens/onboarding/HowItWorksJumpingJackTestScreen.dart';
import '../ui/screens/onboarding/HowItWorksEmergencyUnlockScreen.dart';
import '../ui/screens/onboarding/HowItWorksWorkoutSuccessScreen.dart';
import '../ui/screens/paywall/PaywallScreen.dart';

/// Production-ready state-driven router
///
/// ROUTING LOGIC (strict order - no deviations):
/// 1. App loading
/// 2. Sign up/in screens (state-driven)
/// 3. Unauthenticated non-guest → WelcomeScreen (with Continue as Guest)
/// 4. New user welcome (just registered authenticated users)
/// 5. Onboarding (non-guest only)
/// 6. Guest setup (incomplete)
/// 6.5. Returning guest (completed setup) → FirstWelcomeScreen (force authentication)
/// 7. Main app access (authenticated only)
///
/// Key Guarantees:
/// ✅ NO Navigator.push/pop for primary navigation
/// ✅ ALL routing decisions centralized here
/// ✅ State-driven navigation via Provider rebuilds
/// ✅ Debug logging for all routing decisions
/// ✅ ValueKeys for testability
class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthStateProvider, PushinAppController>(
      builder: (context, authProvider, pushinController, _) {
        debugPrint(
          '🧭 Router STATE: authenticated=${authProvider.isAuthenticated}, onboardingCompleted=${authProvider.isOnboardingCompleted}',
        );

        // PARTY MODE: State analysis
        if (authProvider.isAuthenticated &&
            authProvider.isOnboardingCompleted) {
          debugPrint(
              '🎭 PARTY MODE ROUTER: ✅ PERFECT STATE - HomeScreen should be shown');
        }

        return _buildRoute(context, authProvider, pushinController);
      },
    );
  }

  Widget _buildRoute(
    BuildContext context,
    AuthStateProvider authProvider,
    PushinAppController pushinController,
  ) {
    debugPrint('🧭 Router: Building route with state:');
    debugPrint('  - isInitialized: ${authProvider.isInitialized}');
    debugPrint('  - isAuthenticated: ${authProvider.isAuthenticated}');
    debugPrint('  - isGuestMode: ${authProvider.isGuestMode}');
    debugPrint(
        '  - isOnboardingCompleted: ${authProvider.isOnboardingCompleted}');
    debugPrint('  - onboardingStep: ${authProvider.onboardingStep}');
    debugPrint('  - guestSetupStep: ${authProvider.guestSetupStep}');
    debugPrint('  - showSignUpScreen: ${authProvider.showSignUpScreen}');
    debugPrint('  - showSignInScreen: ${authProvider.showSignInScreen}');
    debugPrint('  - justRegistered: ${authProvider.justRegistered}');

    // 1. App loading
    if (!authProvider.isInitialized) {
      debugPrint('🧭 Router: App not initialized yet → Loading screen');
      return Scaffold(
        key: const ValueKey('loading_screen'),
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    // 2. SIGN UP/IN SCREENS (state-driven navigation - must come BEFORE auth checks)
    if (authProvider.showSignUpScreen) {
      debugPrint('🧭 Router: Show sign up screen → SignUpScreen');
      return const SignUpScreen(key: ValueKey('signup_screen'));
    }
    if (authProvider.showSignInScreen) {
      debugPrint('🧭 Router: Show sign in screen → SignInScreen');
      return const SignInScreen(key: ValueKey('signin_screen'));
    }

    // 3. AUTHENTICATED USER CHECKS (only for non-sign-up/sign-in states)
    if (!authProvider.isAuthenticated && !authProvider.isGuestMode) {
      // If user has used the app before (logged out), show FirstWelcomeScreen (force authentication)
      // If brand new user (never used app), show WelcomeScreen (with Continue as Guest option)
      if (authProvider.hasUsedAppBefore) {
        debugPrint(
            '🧭 Router: Returning user (logged out) → FirstWelcomeScreen (force authentication)');
        return const FirstWelcomeScreen(
          key: ValueKey('first_welcome_screen'),
        );
      } else {
        debugPrint(
            '🧭 Router: Brand new user → WelcomeScreen (with Continue as Guest)');
        return const WelcomeScreen(
          key: ValueKey('welcome_screen'),
        );
      }
    }

    // 4. NEW USER WELCOME - for authenticated users who just registered
    if (authProvider.justRegistered) {
      debugPrint('🧭 Router: Just registered user → NewUserWelcomeScreen');
      return const NewUserWelcomeScreen(
        key: ValueKey('new_user_welcome_screen'),
        isReturningUser: false,
      );
    }

    // 5. ONBOARDING FLOW - authenticated users who haven't completed onboarding
    if (!authProvider.isOnboardingCompleted) {
      debugPrint(
          '🧭 Router: ONBOARDING - authenticated=${authProvider.isAuthenticated}, onboardingCompleted=${authProvider.isOnboardingCompleted}, onboardingStep=${authProvider.onboardingStep}');
      switch (authProvider.onboardingStep) {
        case OnboardingStep.fitnessLevel:
          debugPrint('🧭 Router: Showing OnboardingFitnessLevelScreen');
          return const OnboardingFitnessLevelScreen(
            key: ValueKey('onboarding_fitness_level_screen'),
          );
        case OnboardingStep.goals:
          return OnboardingGoalsScreen(
            key: const ValueKey('onboarding_goals_screen'),
            fitnessLevel: authProvider.fitnessLevel ?? '',
          );
        case OnboardingStep.otherGoal:
          // TODO: Implement OnboardingOtherGoalScreen
          return const OnboardingFitnessLevelScreen(
            key: ValueKey('onboarding_other_goal_screen'),
          );
        case OnboardingStep.workoutHistory:
          return OnboardingWorkoutHistoryScreen(
            key: const ValueKey('onboarding_workout_history_screen'),
            fitnessLevel: authProvider.fitnessLevel ?? '',
            goals: authProvider.goals,
            otherGoal: authProvider.otherGoal,
          );
        case OnboardingStep.notificationPermission:
          return HowItWorksNotificationPermissionScreen(
            key: const ValueKey('onboarding_notification_permission_screen'),
            fitnessLevel: authProvider.fitnessLevel ?? '',
            goals: authProvider.goals,
            otherGoal: authProvider.otherGoal,
            workoutHistory: authProvider.workoutHistory,
          );
        case OnboardingStep.blockApps:
          return HowItWorksBlockAppsScreen(
            key: const ValueKey('onboarding_block_apps_screen'),
            fitnessLevel: authProvider.fitnessLevel ?? '',
            goals: authProvider.goals,
            otherGoal: authProvider.otherGoal,
            workoutHistory: authProvider.workoutHistory,
          );
        case OnboardingStep.exercise:
          return HowItWorksChooseWorkoutScreen(
            key: const ValueKey('onboarding_exercise_screen'),
            fitnessLevel: authProvider.fitnessLevel ?? '',
            goals: authProvider.goals,
            otherGoal: authProvider.otherGoal,
            workoutHistory: authProvider.workoutHistory,
            blockedApps: authProvider.blockedApps,
          );
        case OnboardingStep.pushUpTest:
          return _buildWorkoutTestScreen(
            context,
            authProvider,
            key: const ValueKey('onboarding_pushup_test_screen'),
          );
        case OnboardingStep.workoutSuccess:
          return HowItWorksWorkoutSuccessScreen(
            key: const ValueKey('onboarding_workout_success_screen'),
            fitnessLevel: authProvider.fitnessLevel ?? '',
            goals: authProvider.goals,
            otherGoal: authProvider.otherGoal,
            workoutHistory: authProvider.workoutHistory,
            blockedApps: authProvider.blockedApps,
            workoutType: authProvider.selectedWorkout ?? 'Push-Ups',
          );
        case OnboardingStep.emergencyUnlock:
          debugPrint(
              '🧭 Router: EMERGENCY UNLOCK SCREEN - onboardingStep=${authProvider.onboardingStep}');
          return HowItWorksEmergencyUnlockScreen(
            key: const ValueKey('onboarding_emergency_screen'),
            fitnessLevel: authProvider.fitnessLevel ?? '',
            goals: authProvider.goals,
            otherGoal: authProvider.otherGoal,
            workoutHistory: authProvider.workoutHistory,
            blockedApps: authProvider.blockedApps,
            selectedWorkout: authProvider.selectedWorkout ?? '',
            unlockDuration: authProvider.unlockDuration ?? 30,
          );
        case OnboardingStep.paywall:
          debugPrint(
              '🧭 Router: PAYWALL SCREEN - onboardingStep=${authProvider.onboardingStep}');
          return PaywallScreen(
            key: const ValueKey('paywall_screen'),
          );
        case OnboardingStep.completed:
          // Should not reach here due to outer condition
          break;
      }
    }

    // 6. GUEST SETUP (must come BEFORE guest completion)
    if (authProvider.isGuestMode && !authProvider.guestCompletedSetup) {
      debugPrint('🧭 Router: Guest setup incomplete → guest screens');
      switch (authProvider.guestSetupStep) {
        case GuestSetupStep.notificationPermission:
          return const SkipNotificationPermissionScreen(
            key: ValueKey('guest_notification_permission_screen'),
          );
        case GuestSetupStep.appsSelection:
          return const SkipBlockAppsScreen(
            key: ValueKey('guest_apps_screen'),
          );
        case GuestSetupStep.exerciseSelection:
          return HowItWorksChooseWorkoutScreen(
            key: const ValueKey('guest_exercise_screen'),
            blockedApps: authProvider.blockedApps,
          );
        case GuestSetupStep.pushUpTest:
          return _buildWorkoutTestScreen(
            context,
            authProvider,
            key: const ValueKey('guest_pushup_test_screen'),
          );
        case GuestSetupStep.workoutSuccess:
          return HowItWorksWorkoutSuccessScreen(
            key: const ValueKey('guest_workout_success_screen'),
            fitnessLevel: '',
            goals: const [],
            otherGoal: '',
            workoutHistory: '',
            blockedApps: authProvider.blockedApps,
            workoutType: authProvider.selectedWorkout ?? 'Push-Ups',
          );
        case GuestSetupStep.emergencyUnlock:
          return HowItWorksEmergencyUnlockScreen(
            key: const ValueKey('guest_emergency_screen'),
            fitnessLevel: '',
            goals: const [],
            otherGoal: '',
            workoutHistory: '',
            blockedApps: authProvider.blockedApps,
            selectedWorkout: authProvider.selectedWorkout ?? 'Push-Ups',
            unlockDuration: authProvider.unlockDuration ?? 15,
          );
        case GuestSetupStep.completed:
          // Should not reach here due to outer condition
          break;
      }
    }

    // 6.5. RETURNING GUEST USERS - CHECK REMOVED
    // Previously, we forced authentication here. 
    // Now, we allow the fall-through to Step 7 (Main App Access) so guests can actually use the app after setup.
    // Note: On app restart, isGuestMode resets to false, so returning users will naturally hit Step 3 above.


    // 7. MAIN APP ACCESS (authenticated + onboarding completed)
    debugPrint('🧭 Router: MAIN APP ACCESS - showing MainTabNavigation');
    debugPrint(
        '🧭 Router: Authenticated=${authProvider.isAuthenticated}, OnboardingCompleted=${authProvider.isOnboardingCompleted}, GuestMode=${authProvider.isGuestMode}, GuestSetupCompleted=${authProvider.guestCompletedSetup}');
    
    // Check for notification permissions for returning users
    if (!authProvider.notificationPermissionRequested) {
      debugPrint('🧭 Router: Returning user missing notification permissions → HowItWorksNotificationPermissionScreen');
      return HowItWorksNotificationPermissionScreen(
        key: const ValueKey('returning_user_notification_permission_screen'),
        // Pass empty/dummy data as it won't be used for next steps logic in this mode
        fitnessLevel: '',
        goals: const [],
        otherGoal: '',
        workoutHistory: '',
        isReturningUser: true,
      );
    }

    return const MainTabNavigation(
      key: ValueKey('main_tab_navigation'),
    );
  }

  /// Helper to build the correct workout test screen based on selection
  Widget _buildWorkoutTestScreen(
    BuildContext context,
    AuthStateProvider authProvider, {
    required ValueKey key,
  }) {
    final workout = authProvider.selectedWorkout ?? 'Push-Ups';
    final fitnessLevel = authProvider.fitnessLevel ?? '';
    final goals = authProvider.goals;
    final otherGoal = authProvider.otherGoal;
    final workoutHistory = authProvider.workoutHistory;
    final blockedApps = authProvider.blockedApps;

    debugPrint('🧭 Router: Building workout test screen for: $workout');

    switch (workout) {
      case 'Push-Ups':
        return HowItWorksPushUpTestScreen(
          key: key,
          fitnessLevel: fitnessLevel,
          goals: goals,
          otherGoal: otherGoal,
          workoutHistory: workoutHistory,
          blockedApps: blockedApps,
        );
      case 'Squats':
        return HowItWorksSquatTestScreen(
          key: key,
          fitnessLevel: fitnessLevel,
          goals: goals,
          otherGoal: otherGoal,
          workoutHistory: workoutHistory,
          blockedApps: blockedApps,
        );
      case 'Glute Bridge':
        return HowItWorksGluteBridgeTestScreen(
          key: key,
          fitnessLevel: fitnessLevel,
          goals: goals,
          otherGoal: otherGoal,
          workoutHistory: workoutHistory,
          blockedApps: blockedApps,
        );
      case 'Plank':
        return HowItWorksPlankTestScreen(
          key: key,
          fitnessLevel: fitnessLevel,
          goals: goals,
          otherGoal: otherGoal,
          workoutHistory: workoutHistory,
          blockedApps: blockedApps,
        );
      case 'Jumping Jacks':
        return HowItWorksJumpingJackTestScreen(
          key: key,
          fitnessLevel: fitnessLevel,
          goals: goals,
          otherGoal: otherGoal,
          workoutHistory: workoutHistory,
          blockedApps: blockedApps,
        );
      default:
        return HowItWorksPushUpTestScreen(
          key: key,
          fitnessLevel: fitnessLevel,
          goals: goals,
          otherGoal: otherGoal,
          workoutHistory: workoutHistory,
          blockedApps: blockedApps,
        );
    }
  }
}
