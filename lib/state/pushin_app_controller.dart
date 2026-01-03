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
import '../services/FocusModeService.dart';
import '../services/platform/UsageStatsMonitor.dart';
import '../services/DeepLinkHandler.dart';
import '../services/StripeCheckoutService.dart';
import '../services/StreakTrackingService.dart';
import '../ui/widgets/AppBlockOverlay.dart';
import '../controller/PushinController.dart';

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
  late final StreakTrackingService _streakTracker;

  // Platform monitors
  FocusModeService? _focusModeService;
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

  // Plan tier (free, pro, advanced)
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
    StreakTrackingService? streakTracker,
    int gracePeriodSeconds = 30, // Free plan default
  })  : _usageTracker = usageTracker,
        _rewardCalculator = rewardCalculator ?? WorkoutRewardCalculator(),
        _streakTracker = streakTracker ?? StreakTrackingService() {
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
  int getTotalUnlockDuration() => _core.getTotalUnlockDuration();
  int getGracePeriodRemaining(DateTime now) =>
      _core.getGracePeriodRemaining(now);

  /// Initialize platform monitoring and daily usage tracking
  Future<void> initialize() async {
    // Initialize Hive storage (if available)
    await _usageTracker?.initialize();
    await _streakTracker.initialize();

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
      _focusModeService = FocusModeService.forIOS();
      await _focusModeService!.initialize();

      print('Focus Mode Service initialized');

      // Note: FocusModeService doesn't provide app launch monitoring
      // App launch monitoring removed for better architecture separation
    } catch (e) {
      // Graceful fallback when native module not available
      // This happens when:
      // - Running in simulator
      // - Xcode project not configured
      // - iOS native module not registered
      print('Screen Time monitoring unavailable (expected in simulator): $e');
      print('Falling back to UX overlay (works for 100% of users)');
      _focusModeService = null;
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
    // Controller should not check platform service types for better architecture
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

  // Store desired screen time for the current workout
  int? _desiredScreenTimeSeconds;

  /// Start workout with desired screen time (in minutes)
  /// The desiredScreenTimeMinutes is what the user selected - this is the actual
  /// unlock time they'll get upon completing the workout.
  Future<void> startWorkout(
    String workoutType,
    int targetReps, {
    required int desiredScreenTimeMinutes,
  }) async {
    final now = DateTime.now();

    // Store the user's desired screen time (convert to seconds)
    _desiredScreenTimeSeconds = desiredScreenTimeMinutes * 60;

    final workout = Workout(
      id: 'workout_${now.millisecondsSinceEpoch}',
      type: workoutType,
      targetReps: targetReps,
      earnedTimeSeconds: _desiredScreenTimeSeconds!,
    );

    _core.startWorkout(workout, now);
    notifyListeners();
  }

  /// Complete workout and track earned time
  /// Uses the desired screen time from startWorkout, ensuring the user gets
  /// exactly the unlock time they selected.
  Future<void> completeWorkout(int actualReps) async {
    final now = DateTime.now();

    if (actualReps > 0 && _desiredScreenTimeSeconds != null) {
      // Record the reps in the workout service
      final workoutService = _core.workoutService as MockWorkoutTrackingService;
      workoutService.recordReps(actualReps, now);

      // Use the stored desired screen time (what the user selected)
      final earnedSeconds = _desiredScreenTimeSeconds!;

      // Add to daily usage tracker
      await _usageTracker?.addEarnedTime(earnedSeconds);

      // Complete workout in core
      _core.completeWorkout(now);

      // Clear the stored desired time
      _desiredScreenTimeSeconds = null;

      notifyListeners();
    }
  }

  /// Cancel workout
  void cancelWorkout() {
    _core.cancelWorkout();
    _desiredScreenTimeSeconds = null;
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

  /// Get current streak (consecutive workout days)
  int getCurrentStreak() {
    return _streakTracker.getCurrentStreak();
  }

  /// Get best streak ever achieved
  int getBestStreak() {
    return _streakTracker.getBestStreak();
  }

  /// Check if today's workout is completed
  bool isTodayCompleted() {
    return _streakTracker.isTodayCompleted();
  }

  /// Record workout completion (should be called when workout finishes)
  Future<void> recordWorkoutCompletion() async {
    await _streakTracker.recordWorkoutCompletion();
    notifyListeners();
  }

  /// Get weekly usage summary for the past 7 days
  Future<List<DailyUsage>> getWeeklyUsage() async {
    if (_usageTracker == null) {
      return [];
    }

    // Get usage history for the past 7 days
    final history = await _usageTracker!.getUsageHistory(7);

    // Ensure we have exactly 7 days, filling missing days with empty usage
    final now = DateTime.now();
    final weeklyUsage = <DailyUsage>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Find usage for this date in history
      final existingUsage =
          history.where((usage) => usage.date == dateKey).firstOrNull;

      if (existingUsage != null) {
        weeklyUsage.add(existingUsage);
      } else {
        // If no data for this date, add empty usage
        weeklyUsage.add(DailyUsage(
          date: dateKey,
          planTier: 'free',
          lastUpdated: date,
        ));
      }
    }

    return weeklyUsage;
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

  /// Get focus mode service
  FocusModeService? get focusModeService => _focusModeService;

  /// Request platform permissions (called from UI)
  Future<bool> requestPlatformPermissions() async {
    if (Platform.isIOS && _focusModeService != null) {
      return await _focusModeService!.requestScreenTimePermission() ==
          AuthorizationResult.granted;
    } else if (Platform.isAndroid && _usageStatsMonitor != null) {
      return await _usageStatsMonitor!.requestPermission();
    }
    return false;
  }

  @override
  void dispose() {
    _appLaunchSubscription?.cancel();
    _tickTimer?.cancel();
    _focusModeService?.dispose();
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
