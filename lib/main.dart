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

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final DailyUsageTracker usageTracker = DailyUsageTracker();
  await usageTracker.initialize();

  final AuthStateProvider authProvider = AuthStateProvider(prefs);
  await authProvider.initialize();

  final PushinAppController pushinController = PushinAppController(
    workoutService: MockWorkoutTrackingService(),
    unlockService: MockUnlockService(),
    blockingService: MockAppBlockingService(),
    blockTargets: const [],
    usageTracker: usageTracker,
  );
  await pushinController.initialize();

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

    // Initialize services for iOS
    if (Platform.isIOS) {
      _focusModeService = FocusModeService.forIOS();
      _shieldNotificationMonitor = ShieldNotificationMonitor();

      // Initialize notification monitor
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _shieldNotificationMonitor?.initialize();
        _shieldNotificationMonitor?.startMonitoring();
        _checkPendingWorkoutNavigation();
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
    if (_focusModeService == null) return;

    try {
      final shouldNavigate = await _focusModeService!.checkPendingWorkoutNavigation();
      debugPrint('📱 Pending workout navigation: $shouldNavigate');

      if (shouldNavigate && mounted) {
        // Signal the app controller to navigate to workout
        debugPrint('🏋️ Signaling workout navigation from shield action');
        final controller = Provider.of<PushinAppController>(context, listen: false);
        controller.setPendingWorkoutNavigation(true);
      }
    } catch (e) {
      debugPrint('Error checking pending workout navigation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ Building PushinApp (MaterialApp)');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PUSHIN',
      theme: ThemeData.dark(),
      home: const AppRouter(),
    );
  }
}
