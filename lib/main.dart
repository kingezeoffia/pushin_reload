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
class PushinApp extends StatelessWidget {
  const PushinApp({super.key});

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
