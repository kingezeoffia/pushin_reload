import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/PushinAppController.dart';
import '../domain/AppBlockTarget.dart';
import '../services/MockWorkoutTrackingService.dart';
import '../services/MockUnlockService.dart';
import '../services/MockAppBlockingService.dart';
import '../services/DailyUsageTracker.dart';
import '../services/WorkoutRewardCalculator.dart';
import '../services/OnboardingService.dart';
import '../services/AuthStateProvider.dart';
import './theme/pushin_theme.dart';
import 'screens/HomeScreen.dart';
import 'screens/onboarding/OnboardingWelcomeScreen.dart';
import 'screens/auth/SignInScreen.dart';

/// Root app router that handles onboarding vs main app routing
///
/// Checks onboarding completion status and routes accordingly:
/// - If onboarding not completed: Show onboarding flow
/// - If onboarding completed: Show main app
class AppRouter extends StatefulWidget {
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAppStatus();
    // Listen for onboarding state changes (for development)
    OnboardingService.setOnboardingCompletedCallback(
        _handleOnboardingCompleted);
    OnboardingService.setDevRefreshCallback(_handleDevRefresh);
  }

  Future<void> _checkAppStatus() async {
    // Read auth state from provider (already initialized at root level)
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

    // Wait for auth provider to finish initialization if it's still loading
    if (authProvider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      // Re-check after a short delay
      if (mounted) _checkAppStatus();
      return;
    }

    final authenticated = authProvider.isAuthenticated;
    final onboardingCompleted =
        authenticated ? await OnboardingService.isOnboardingCompleted() : false;

    if (mounted) {
      setState(() {
        _isOnboardingCompleted = onboardingCompleted;
        _isLoading = false;
      });
    }
  }

  void _handleOnboardingCompleted() {
    setState(() {
      _isOnboardingCompleted = true;
    });
  }

  void _handleDevRefresh() {
    // Re-check app status when dev refresh is triggered
    _checkAppStatus();
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state changes
    final authProvider = context.watch<AuthStateProvider>();

    if (_isLoading || authProvider.isLoading) {
      // Show loading screen while checking app status
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    final isAuthenticated = authProvider.isAuthenticated;

    if (!isAuthenticated) {
      // Show authentication flow
      return AuthApp();
    } else if (_isOnboardingCompleted == false) {
      // Show onboarding flow
      return OnboardingApp(
        onOnboardingCompleted: _handleOnboardingCompleted,
      );
    } else {
      // Show main app
      return MainApp(usageTracker: widget.usageTracker);
    }
  }
}

/// Authentication-only app
/// Separate MaterialApp for authentication with its own navigation stack
class AuthApp extends StatelessWidget {
  const AuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PUSHIN\' - Sign In',
      debugShowCheckedModeBanner: false,
      theme: PushinTheme.darkTheme,
      home: const SignInScreen(),
    );
  }
}

/// Onboarding-only app
/// Separate MaterialApp for onboarding with its own navigation stack
class OnboardingApp extends StatefulWidget {
  final VoidCallback onOnboardingCompleted;

  const OnboardingApp({
    super.key,
    required this.onOnboardingCompleted,
  });

  @override
  State<OnboardingApp> createState() => _OnboardingAppState();
}

class _OnboardingAppState extends State<OnboardingApp> {
  @override
  void initState() {
    super.initState();
    // Set the global callback
    OnboardingService.setOnboardingCompletedCallback(
        widget.onOnboardingCompleted);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PUSHIN\' - Setup',
      debugShowCheckedModeBanner: false,
      theme: PushinTheme.darkTheme,
      home: const OnboardingWelcomeScreen(),
    );
  }
}

/// Main app after onboarding completion
class MainApp extends StatelessWidget {
  final DailyUsageTracker? usageTracker;

  const MainApp({
    super.key,
    required this.usageTracker,
  });

  @override
  Widget build(BuildContext context) {
    // Initialize services (mock implementations for MVP)
    final workoutService = MockWorkoutTrackingService();
    final unlockService = MockUnlockService();
    final blockingService = MockAppBlockingService();
    final rewardCalculator = WorkoutRewardCalculator();

    // Define block targets
    final blockTargets = [
      AppBlockTarget(
        id: 'target-1',
        name: 'Instagram',
        type: 'app',
        platformAgnosticIdentifier: 'com.instagram.android',
      ),
      AppBlockTarget(
        id: 'target-2',
        name: 'TikTok',
        type: 'app',
        platformAgnosticIdentifier: 'com.tiktok.app',
      ),
    ];

    // Create PushinAppController
    final appController = PushinAppController(
      workoutService: workoutService,
      unlockService: unlockService,
      blockingService: blockingService,
      blockTargets: blockTargets,
      usageTracker: usageTracker,
      rewardCalculator: rewardCalculator,
      gracePeriodSeconds: 30, // Free plan: 30 seconds
    );

    // Initialize controller
    appController.initialize();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appController),
      ],
      child: MaterialApp(
        title: 'PUSHIN\'',
        debugShowCheckedModeBanner: false,
        theme: PushinTheme.darkTheme,
        home: const HomeScreen(),
      ),
    );
  }
}


