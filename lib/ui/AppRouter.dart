import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/DailyUsageTracker.dart';
import '../services/OnboardingService.dart';
import '../state/auth_state_provider.dart';
import '../controller/PushinAppController.dart';
import 'screens/HomeScreen.dart';
import 'screens/auth/WelcomeScreen.dart';
import 'screens/auth/NewUserWelcomeScreen.dart';
import 'screens/auth/GuestCompleteOverviewScreen.dart';
import 'screens/onboarding/OnboardingFitnessLevelScreen.dart';

/// Root app router - CENTRALIZED routing with EXACTLY ONE MaterialApp
///
/// ROUTING LOGIC (simplified and predictable):
/// 1. if (isGuestMode && onboardingCompleted) → Main App (guest)
/// 2. if (isGuestMode && !onboardingCompleted) → Guest onboarding flow
/// 3. if (!isAuthenticated) → Welcome Screen (brand new user)
/// 4. if (justRegistered) → Welcome Screen (sign up success)
/// 5. if (!onboardingCompleted) → Onboarding flow
/// 6. else → Main App (authenticated user)
///
/// NO screen may push or replace routes manually.
/// All navigation happens through state changes that trigger rebuilds.
class AppRouter extends StatefulWidget {
  // Global key to access AppRouter state from anywhere
  static final GlobalKey<_AppRouterState> globalKey =
      GlobalKey<_AppRouterState>();

  // Method to force onboarding completion from anywhere
  static void forceOnboardingComplete() {
    globalKey.currentState?._forceOnboardingComplete();
  }

  // Method to force onboarding reset from anywhere
  static void forceOnboardingReset() {
    globalKey.currentState?._forceOnboardingReset();
  }

  final DailyUsageTracker? usageTracker;

  const AppRouter({
    super.key,
    required this.usageTracker,
  });

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  bool? _isOnboardingCompleted;

  // Method to force onboarding completion (called from static method)
  void _forceOnboardingComplete() {
    if (mounted) {
      setState(() {
        _isOnboardingCompleted = true;
        print('✅ Forced onboarding completion via AppRouter');
      });
    }
  }

  // Method to force onboarding reset (called from static method)
  void _forceOnboardingReset() {
    if (mounted) {
      print(
          '🔄 AppRouter._forceOnboardingReset() called - about to set _isOnboardingCompleted = false');
      setState(() {
        _isOnboardingCompleted = false;
        print(
            '🔄 Forced onboarding reset via AppRouter - _isOnboardingCompleted set to false');
      });
      print('🔄 AppRouter._forceOnboardingReset() completed');
    } else {
      print(
          '🔄 AppRouter._forceOnboardingReset() called but widget not mounted');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Set up onboarding completion callback
    OnboardingService.setOnboardingCompletedCallback(() {
      print('🎯 Onboarding completion callback triggered!');
      print('🔄 About to set _isOnboardingCompleted = true via callback');
      if (mounted) {
        setState(() {
          _isOnboardingCompleted = true;
          print('✅ Set _isOnboardingCompleted = true via callback');
        });
        print('🔄 Onboarding completion callback setState completed');
      } else {
        print(
            '🔄 Onboarding completion callback triggered but widget not mounted');
      }
    });

    // Set up onboarding reset callback
    OnboardingService.setOnboardingResetCallback(() {
      print('🔄 Onboarding reset callback triggered!');
      print('🔄 About to reset onboarding state via callback');
      if (mounted) {
        setState(() {
          _isOnboardingCompleted = false;
          print('✅ Reset onboarding state via callback');
        });
        print('🔄 Onboarding reset callback setState completed');
      } else {
        print('🔄 Onboarding reset callback triggered but widget not mounted');
      }
    });

    // Check initial onboarding status
    _checkOnboardingStatus();
  }

  void _checkOnboardingStatusAsync() {
    print('🔄 Starting async onboarding status check...');
    OnboardingService.isOnboardingCompleted().then((completed) {
      print(
          '📋 OnboardingService.isOnboardingCompleted() returned: $completed');
      if (mounted) {
        setState(() {
          _isOnboardingCompleted = completed;
          print('🎯 Onboarding status updated to: $_isOnboardingCompleted');
        });
      }
    });
  }

  void _checkOnboardingStatus() {
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    print(
        '🔍 _checkOnboardingStatus called - Guest: ${authProvider.isGuestMode}');

    if (authProvider.isGuestMode) {
      // For guest users, check if they've completed onboarding or skipped it
      // Default to false (incomplete) for new guest users
      print(
          '   🎯 Guest user detected - setting default onboarding status to false');
      _isOnboardingCompleted = false; // Default for guest users
      _checkOnboardingStatusAsync(); // This will update it if they've completed it
      print(
          '   📊 After setting: _isOnboardingCompleted = $_isOnboardingCompleted');
    } else {
      _isOnboardingCompleted = null; // Not guest, let auth flow handle it
      print('👤 User not in guest mode, onboarding status set to null');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthStateProvider, PushinAppController>(
      builder: (context, authProvider, pushinController, _) {
        print('🏁 Route Check: '
            'justRegistered=${authProvider.justRegistered}, '
            'isGuestMode=${authProvider.isGuestMode}, '
            'guestCompletedSetup=${authProvider.guestCompletedSetup}, '
            'isOnboardingCompleted=${authProvider.isOnboardingCompleted}');

        // Guest flow: setup → overview → main app
        if (authProvider.isGuestMode && !authProvider.guestCompletedSetup) {
          print(
              '   🎯 Guest user - not completed setup → GuestCompleteOverviewScreen');
          return GuestCompleteOverviewScreen();
        } else if (authProvider.isGuestMode &&
            authProvider.guestCompletedSetup) {
          print('   🎯 Guest user - completed setup → HomeScreen');
          return HomeScreen();

          // Registered user flow: new registration → onboarding → main app
        } else if (authProvider.justRegistered &&
            !authProvider.isOnboardingCompleted) {
          print(
              '   🎯 Just registered user - onboarding not completed → NewUserWelcomeScreen');
          return NewUserWelcomeScreen(isReturningUser: false);
        } else if (!authProvider.isOnboardingCompleted) {
          print(
              '   🎯 Registered user - onboarding not completed → OnboardingFitnessLevelScreen');
          return OnboardingFitnessLevelScreen();
        } else if (authProvider.isAuthenticated ||
            authProvider.isOnboardingCompleted) {
          print(
              '   🎯 User authenticated or onboarding completed → HomeScreen');
          return HomeScreen();
        } else {
          print('   🎯 Fallback - no specific condition met → WelcomeScreen');
          return WelcomeScreen();
        }
      },
    );
  }
}
