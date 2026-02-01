import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'routing/app_router.dart';
import 'state/auth_state_provider.dart';
import 'state/pushin_app_controller.dart';

import 'services/DailyUsageTracker.dart';
import 'services/MockAppBlockingService.dart';
import 'services/MockUnlockService.dart';
import 'services/MockWorkoutTrackingService.dart';
import 'services/FocusModeService.dart';
import 'services/ShieldNotificationMonitor.dart';

/// PUSHIN MVP - Production-Ready Main Entry Point
///
/// Guarantees:
/// - Exactly ONE MaterialApp
/// - All providers created ABOVE MaterialApp
/// - State-driven navigation (no Navigator.push/pop)
/// - SharedPreferences persistence
/// - Null-safety & debug logging
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Bootstrapping PUSHIN app');

  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 10));

    final DailyUsageTracker usageTracker = DailyUsageTracker();
    await usageTracker.initialize().timeout(const Duration(seconds: 10),
        onTimeout: () {
      debugPrint('⚠️ DailyUsageTracker initialization timed out');
    });

    final AuthStateProvider authProvider = AuthStateProvider(prefs);
    await authProvider.initialize().timeout(const Duration(seconds: 10),
        onTimeout: () {
      debugPrint('⚠️ AuthStateProvider initialization timed out');
    });

    final PushinAppController pushinController = PushinAppController(
      workoutService: MockWorkoutTrackingService(),
      unlockService: MockUnlockService(),
      blockingService: MockAppBlockingService(),
      blockTargets: const [],
      authProvider: authProvider,
      usageTracker: usageTracker,
    );

    // Delay PushinAppController initialization to ensure platform channels are ready
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        await pushinController.initialize();
      } catch (e) {
        debugPrint('❌ Error initializing PushinAppController: $e');
        // Continue anyway - app should still work
      }
    });

    // Set up callback to refresh plan tier when auth state changes
    authProvider.onAuthStateChanged = () async {
      debugPrint('🔄 Auth state changed - refreshing plan tier');
      await pushinController.refreshPlanTier();
    };

    debugPrint('✅ All providers initialized');

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthStateProvider>.value(value: authProvider),
          ChangeNotifierProvider<PushinAppController>.value(
            value: pushinController,
          ),
        ],
        child: const PushinApp(),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('❌ Fatal error during app initialization: $e');
    debugPrint('Stack trace: $stackTrace');
    // Still try to run the app with minimal setup
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('App initialization failed. Please restart.'),
          ),
        ),
      ),
    );
  }
}

/// Root widget containing the ONLY MaterialApp
/// Handles lifecycle events to check for pending workout navigation from shield
class PushinApp extends StatefulWidget {
  const PushinApp({super.key});

  @override
  State<PushinApp> createState() => _PushinAppState();
}

class _PushinAppState extends State<PushinApp> with WidgetsBindingObserver {
  FocusModeService? _focusModeService;
  ShieldNotificationMonitor? _shieldNotificationMonitor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize services for iOS - delay to ensure platform channels are ready
    if (Platform.isIOS) {
      _focusModeService = FocusModeService.forIOS();
      _shieldNotificationMonitor = ShieldNotificationMonitor();

      // Initialize notification monitor with delay to ensure platform channels are ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Add a longer delay to ensure platform channels are fully initialized
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        try {
          await _shieldNotificationMonitor
              ?.initialize()
              .timeout(const Duration(seconds: 5), onTimeout: () {
            debugPrint('⚠️ ShieldNotificationMonitor initialization timed out');
          });
          _shieldNotificationMonitor?.startMonitoring();
          _checkPendingWorkoutNavigation();
        } catch (e) {
          debugPrint('❌ Error initializing ShieldNotificationMonitor: $e');
          // Continue anyway - app should still work
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shieldNotificationMonitor?.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Manage notification monitoring based on app state
    if (Platform.isIOS) {
      switch (state) {
        case AppLifecycleState.resumed:
          debugPrint('📱 App resumed - resuming notification monitoring');
          _shieldNotificationMonitor?.startMonitoring();
          _checkPendingWorkoutNavigation();
          break;
        case AppLifecycleState.paused:
        case AppLifecycleState.inactive:
          debugPrint('📱 App inactive - pausing notification monitoring');
          _shieldNotificationMonitor?.stopMonitoring();
          break;
        default:
          break;
      }
    }
  }

  Future<void> _checkPendingWorkoutNavigation() async {
    if (_focusModeService == null || !mounted) return;

    try {
      final shouldNavigate = await _focusModeService!
          .checkPendingWorkoutNavigation()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('⚠️ checkPendingWorkoutNavigation timed out');
        return false;
      });
      debugPrint('📱 Pending workout navigation: $shouldNavigate');

      if (shouldNavigate && mounted) {
        // Signal the app controller to navigate to workout
        debugPrint('🏋️ Signaling workout navigation from shield action');
        final controller =
            Provider.of<PushinAppController>(context, listen: false);
        controller.setPendingWorkoutNavigation(true);
      }
    } catch (e) {
      debugPrint('Error checking pending workout navigation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ Building PushinApp (MaterialApp)');
    return Consumer<AuthStateProvider>(
      builder: (context, authProvider, _) {
        debugPrint('🏗️ PushinApp Consumer rebuilding with auth state');
        // Force immediate render - use a simple test screen first to verify Flutter is rendering
        Widget homeWidget = const AppRouter();

        // Debug: Log what widget is being shown
        debugPrint('🏗️ MaterialApp home widget: ${homeWidget.runtimeType}');

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'PUSHIN',
          theme: ThemeData.dark(),
          home: homeWidget,
          key: ValueKey(
              'material_app_${authProvider.isAuthenticated}_${authProvider.isGuestMode}_${authProvider.showSignUpScreen}_${authProvider.showSignInScreen}'),
        );
      },
    );
  }
}
