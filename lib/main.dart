import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/DailyUsageTracker.dart';
import 'services/AuthStateProvider.dart';
import 'ui/AppRouter.dart';

/// PUSHIN MVP - Main Entry Point
///
/// Features:
/// - Platform-realistic app blocking with UX overlay
/// - Daily usage tracking with plan-based caps
/// - Workout reward calculation
/// - GO Club-inspired dark theme
/// - Proper onboarding separation from main app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  final usageTracker = DailyUsageTracker();
  await usageTracker.initialize();

  runApp(PushinApp(usageTracker: usageTracker));
}

class PushinApp extends StatefulWidget {
  final DailyUsageTracker? usageTracker;

  const PushinApp({
    Key? key,
    required this.usageTracker,
  }) : super(key: key);

  @override
  State<PushinApp> createState() => _PushinAppState();
}

class _PushinAppState extends State<PushinApp> {
  late final AuthStateProvider _authProvider;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthStateProvider();
    // Initialize auth provider on app startup
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _authProvider.initialize();
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen until auth is initialized
    if (!_isInitialized) {
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
      ],
      child: AppRouter(usageTracker: widget.usageTracker),
    );
  }
}
