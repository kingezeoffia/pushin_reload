import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../domain/PushinState.dart';
import '../domain/Workout.dart';
import '../domain/AppBlockTarget.dart';
import '../domain/DailyUsage.dart';
import '../services/WorkoutTrackingService.dart';
import '../services/MockWorkoutTrackingService.dart';
import '../services/UnlockService.dart';
import '../services/AppBlockingService.dart';
import '../services/WorkoutRewardCalculator.dart';
import '../services/DailyUsageTracker.dart';
import '../services/platform/ScreenTimeMonitor.dart';
import '../services/platform/UsageStatsMonitor.dart';
import '../services/DeepLinkHandler.dart';
import '../services/StripeCheckoutService.dart';
import '../ui/widgets/AppBlockOverlay.dart';
import 'PushinController.dart';

/// Enhanced PUSHIN controller integrating:
/// - Core state machine (PushinController)
/// - Daily usage tracking with caps
/// - Workout reward calculation
/// - Platform-specific app monitoring (iOS/Android)
/// - Block overlay trigger logic
///
/// Acts as the main entry point for the Flutter UI.
/// Use this instead of PushinController directly.
class PushinAppController extends ChangeNotifier {
  // Core state machine
  late final PushinController _core;

  // Services
  final DailyUsageTracker? _usageTracker;
  final WorkoutRewardCalculator _rewardCalculator;

  // Platform monitors
  ScreenTimeMonitor? _screenTimeMonitor;
  UsageStatsMonitor? _usageStatsMonitor;

  // Subscriptions
  StreamSubscription? _appLaunchSubscription;
  Timer? _tickTimer;

  // Block overlay state
  final ValueNotifier<BlockOverlayState?> blockOverlayState =
      ValueNotifier(null);

  // Payment result states
  final ValueNotifier<SubscriptionStatus?> paymentSuccessState =
      ValueNotifier(null);
  final ValueNotifier<bool> paymentCancelState = ValueNotifier(false);

  // Plan tier (free, standard, advanced)
  String _planTier = 'free';

  // Deep link handler
  DeepLinkHandler? _deepLinkHandler;

  PushinAppController({
    required WorkoutTrackingService workoutService,
    required UnlockService unlockService,
    required AppBlockingService blockingService,
    required List<AppBlockTarget> blockTargets,
    DailyUsageTracker? usageTracker,
    WorkoutRewardCalculator? rewardCalculator,
    int gracePeriodSeconds = 30, // Free plan default
  })  : _usageTracker = usageTracker,
        _rewardCalculator = rewardCalculator ?? WorkoutRewardCalculator() {
    // Initialize core state machine
    _core = PushinController(
      workoutService,
      unlockService,
      blockingService,
      blockTargets,
      gracePeriodSeconds: gracePeriodSeconds,
    );
  }

  // Delegates to core
  PushinState get currentState => _core.currentState;
  List<String> getBlockedTargets(DateTime now) => _core.getBlockedTargets(now);
  List<String> getAccessibleTargets(DateTime now) =>
      _core.getAccessibleTargets(now);
  double getWorkoutProgress(DateTime now) => _core.getWorkoutProgress(now);
  int getUnlockTimeRemaining(DateTime now) => _core.getUnlockTimeRemaining(now);
  int getGracePeriodRemaining(DateTime now) =>
      _core.getGracePeriodRemaining(now);

  /// Initialize platform monitoring and daily usage tracking
  Future<void> initialize() async {
    // Initialize Hive storage (if available)
    await _usageTracker?.initialize();

    // Load current plan tier
    // TODO: Integrate with subscription service
    _planTier = 'free'; // Hardcoded for MVP

    // Initialize deep link handler for Stripe payments
    final stripeService = StripeCheckoutService(
      baseUrl: 'https://pushin-production.up.railway.app/api',
      isTestMode: true,
    );

    _deepLinkHandler = DeepLinkHandler(
      stripeService: stripeService,
      onPaymentSuccess: (status) {
        print('Payment success! Plan: ${status.planId}');
        // Update plan tier based on subscription
        _planTier = status.planId;
        notifyListeners();

        // Trigger UI to show success dialog
        paymentSuccessState.value = status;
        // Reset after a delay (give user time to read and tap)
        Future.delayed(const Duration(seconds: 8), () {
          paymentSuccessState.value = null;
        });
      },
      onPaymentCanceled: () {
        print('Payment canceled by user');

        // Trigger UI to show cancel message
        paymentCancelState.value = true;
        // Reset after a delay
        Future.delayed(const Duration(seconds: 3), () {
          paymentCancelState.value = false;
        });
      },
    );

    await _deepLinkHandler!.initialize();

    // Initialize platform-specific monitoring
    if (!kIsWeb) {
      if (Platform.isIOS) {
        await _initializeIOSMonitoring();
      } else if (Platform.isAndroid) {
        await _initializeAndroidMonitoring();
      }
    }

    // Start tick timer for state transitions
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tick(),
    );
  }

  /// Initialize iOS Screen Time monitoring
  Future<void> _initializeIOSMonitoring() async {
    try {
      _screenTimeMonitor = ScreenTimeMonitor();
      final capability = await _screenTimeMonitor!.initialize();

      print('Screen Time capability: $capability');

      // Listen for app launch events
      _appLaunchSubscription =
          _screenTimeMonitor!.appLaunchEvents.listen(_handleAppLaunch);
    } catch (e) {
      // Graceful fallback when native module not available
      // This happens when:
      // - Running in simulator
      // - Xcode project not configured
      // - iOS native module not registered
      print('Screen Time monitoring unavailable (expected in simulator): $e');
      print('Falling back to UX overlay (works for 100% of users)');
      _screenTimeMonitor = null;
    }
  }

  /// Initialize Android Usage Stats monitoring
  Future<void> _initializeAndroidMonitoring() async {
    try {
      _usageStatsMonitor = UsageStatsMonitor();
      final hasPermission = await _usageStatsMonitor!.initialize();

      if (!hasPermission) {
        print('Usage Stats permission not granted');
        // Will request in UI flow when user tries to block apps
      } else {
        print('Usage Stats permission granted');
      }

      // Listen for app launch events
      _appLaunchSubscription =
          _usageStatsMonitor!.appLaunchEvents.listen(_handleAppLaunch);
    } catch (e) {
      // Graceful fallback when native module not available
      print('Usage Stats monitoring unavailable: $e');
      print('Falling back to UX overlay (works for 100% of users)');
      _usageStatsMonitor = null;
    }
  }

  /// Handle app launch event from platform monitor
  void _handleAppLaunch(dynamic event) {
    // Only show block overlay if currently LOCKED or session expired
    if (currentState == PushinState.locked ||
        currentState == PushinState.expired) {
      blockOverlayState.value = BlockOverlayState(
        reason: BlockReason.appBlocked,
        appName: _getAppName(event),
      );
    }
  }

  String _getAppName(dynamic event) {
    if (event is ScreenTimeMonitor) {
      return event.appLaunchEvents.toString();
    } else if (event is UsageStatsMonitor) {
      return event.appLaunchEvents.toString();
    }
    return 'App';
  }

  /// Tick handler - runs every second
  void _tick() {
    final now = DateTime.now();

    // Update core state machine
    _core.tick(now);

    // Check daily usage cap
    _checkDailyCap(now);

    // Notify listeners of state changes
    notifyListeners();
  }

  /// Check if user has hit daily usage cap
  Future<void> _checkDailyCap(DateTime now) async {
    if (currentState == PushinState.unlocked) {
      final hasHitCap = await _usageTracker?.hasHitDailyCap() ?? false;

      if (hasHitCap) {
        // Show block overlay with daily cap message
        blockOverlayState.value = BlockOverlayState(
          reason: BlockReason.dailyCapReached,
        );

        // Force lock
        _core.lock();
        notifyListeners();
      }
    }
  }

  /// Start workout with reward calculation
  Future<void> startWorkout(String workoutType, int targetReps) async {
    final now = DateTime.now();

    // Calculate earned time for this workout
    final earnedSeconds = _rewardCalculator.calculateEarnedTime(
      workoutType: workoutType,
      repsCompleted: targetReps,
    );

    final workout = Workout(
      id: 'workout_${now.millisecondsSinceEpoch}',
      type: workoutType,
      targetReps: targetReps,
      earnedTimeSeconds: earnedSeconds,
    );

    _core.startWorkout(workout, now);
    notifyListeners();
  }

  /// Complete workout and track earned time
  Future<void> completeWorkout(int actualReps) async {
    final now = DateTime.now();

    // Calculate actual earned time based on reps completed
    // Note: Using last workout type from startWorkout call
    // TODO: Improve by storing current workout type in controller state
    if (actualReps > 0) {
      // Record the reps in the workout service
      final workoutService = _core.workoutService as MockWorkoutTrackingService;
      workoutService.recordReps(actualReps, now);

      final earnedSeconds = _rewardCalculator.calculateEarnedTime(
        workoutType: 'push-ups', // TODO: Get from current workout context
        repsCompleted: actualReps,
      );

      // Add to daily usage tracker
      await _usageTracker?.addEarnedTime(earnedSeconds);

      // Complete workout in core
      _core.completeWorkout(now);

      notifyListeners();
    }
  }

  /// Cancel workout
  void cancelWorkout() {
    _core.cancelWorkout();
    notifyListeners();
  }

  /// Manual lock (force lock from any state)
  void lock() {
    _core.lock();
    blockOverlayState.value = null; // Dismiss overlay
    notifyListeners();
  }

  /// Dismiss block overlay (navigate to workout screen)
  void dismissBlockOverlay() {
    blockOverlayState.value = null;
  }

  /// Get today's usage summary
  Future<UsageSummary> getTodayUsage() async {
    final usage = await _usageTracker?.getTodayUsage() ??
        DailyUsage(
          date: DateTime.now().toIso8601String().split('T')[0],
          planTier: 'free',
          lastUpdated: DateTime.now(),
        );

    return UsageSummary(
      earnedSeconds: usage.earnedSeconds,
      consumedSeconds: usage.consumedSeconds,
      remainingSeconds: usage.remainingSeconds,
      dailyCapSeconds: usage.dailyCapSeconds,
      hasReachedCap: usage.hasReachedDailyCap,
      progress: usage.dailyCapProgress,
    );
  }

  /// Update plan tier (after subscription purchase)
  Future<void> updatePlanTier(String tier, int newGracePeriodSeconds) async {
    _planTier = tier;
    await _usageTracker?.updatePlanTier(tier);

    // Update grace period
    // Note: Would need to recreate PushinController with new grace period
    // For MVP, can restart app after subscription change

    notifyListeners();
  }

  /// Get workout reward description for UI
  String getWorkoutRewardDescription(String workoutType, int reps) {
    return _rewardCalculator.getRewardDescription(
      workoutType: workoutType,
      reps: reps,
    );
  }

  /// Get plan tier
  String get planTier => _planTier;

  /// Request platform permissions (called from UI)
  Future<bool> requestPlatformPermissions() async {
    if (Platform.isIOS && _screenTimeMonitor != null) {
      return await _screenTimeMonitor!.requestAuthorization();
    } else if (Platform.isAndroid && _usageStatsMonitor != null) {
      return await _usageStatsMonitor!.requestPermission();
    }
    return false;
  }

  @override
  void dispose() {
    _appLaunchSubscription?.cancel();
    _tickTimer?.cancel();
    _screenTimeMonitor?.dispose();
    _usageStatsMonitor?.dispose();
    _usageTracker?.dispose();
    blockOverlayState.dispose();
    paymentSuccessState.dispose();
    paymentCancelState.dispose();
    _deepLinkHandler?.dispose();
    super.dispose();
  }
}

/// State for showing block overlay
class BlockOverlayState {
  final BlockReason reason;
  final String? appName;

  BlockOverlayState({
    required this.reason,
    this.appName,
  });
}

/// Today's usage summary (for UI display)
class UsageSummary {
  final int earnedSeconds;
  final int consumedSeconds;
  final int remainingSeconds;
  final int dailyCapSeconds;
  final bool hasReachedCap;
  final double progress;

  UsageSummary({
    required this.earnedSeconds,
    required this.consumedSeconds,
    required this.remainingSeconds,
    required this.dailyCapSeconds,
    required this.hasReachedCap,
    required this.progress,
  });

  int get earnedMinutes => (earnedSeconds / 60).round();
  int get consumedMinutes => (consumedSeconds / 60).round();
  int get remainingMinutes => (remainingSeconds / 60).round();
}
