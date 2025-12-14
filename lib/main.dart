import 'dart:async';
import 'package:flutter/material.dart';
import 'controller/PushinController.dart';
import 'domain/AppBlockTarget.dart';
import 'services/MockWorkoutTrackingService.dart';
import 'services/MockUnlockService.dart';
import 'services/MockAppBlockingService.dart';
import 'ui/view_models/HomeViewModel.dart';
import 'ui/screens/HomeScreen.dart';

/// PUSHIN MVP - Main Entry Point
///
/// CONTRACT COMPLIANCE DEMONSTRATION:
/// 1. Time injection from external scheduler (Timer)
/// 2. Controller initialized with mock services
/// 3. ViewModel receives initial time injection
/// 4. Time flows from Timer → ViewModel → Controller → UI
void main() {
  runApp(const PushinApp());
}

class PushinApp extends StatelessWidget {
  const PushinApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PUSHIN MVP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PushinHome(),
    );
  }
}

class PushinHome extends StatefulWidget {
  const PushinHome({Key? key}) : super(key: key);

  @override
  State<PushinHome> createState() => _PushinHomeState();
}

class _PushinHomeState extends State<PushinHome> {
  late PushinController _controller;
  late HomeViewModel _viewModel;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Initialize services (mock implementations for MVP)
    final workoutService = MockWorkoutTrackingService();
    final unlockService = MockUnlockService();
    final blockingService = MockAppBlockingService();

    // Define block targets (platform-agnostic identifiers)
    final blockTargets = [
      AppBlockTarget(
        id: 'target-1',
        name: 'Social Media',
        type: 'app',
        platformAgnosticIdentifier: 'com.social.media',
      ),
      AppBlockTarget(
        id: 'target-2',
        name: 'Video Streaming',
        type: 'app',
        platformAgnosticIdentifier: 'com.video.streaming',
      ),
      AppBlockTarget(
        id: 'target-3',
        name: 'Gaming',
        type: 'app',
        platformAgnosticIdentifier: 'com.gaming.app',
      ),
    ];

    // Initialize controller with 5-second grace period
    _controller = PushinController(
      workoutService,
      unlockService,
      blockingService,
      blockTargets,
      gracePeriodSeconds: 5,
    );

    // Initialize ViewModel with explicit time injection
    // CONTRACT: Time is injected, never generated internally
    _viewModel = HomeViewModel(
      _controller,
      initialTime: DateTime.now(), // Only place DateTime.now() appears
    );

    // Start external time scheduler
    // CONTRACT: Time flows from external source (Timer) → ViewModel → Controller
    _startTimeScheduler();
  }

  /// External time scheduler
  /// CONTRACT: Time generation happens here, flows into ViewModel
  void _startTimeScheduler() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();

      // Update ViewModel with current time (triggers UI state recalculation)
      _viewModel.updateTime(now);

      // Update Controller with current time (triggers state transitions)
      _controller.tick(now);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(viewModel: _viewModel);
  }
}

