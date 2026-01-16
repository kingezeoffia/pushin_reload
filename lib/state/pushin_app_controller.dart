import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../services/platform/AppBlockingServiceBridge.dart';
import '../services/platform/IOSSettingsBridge.dart';
import '../services/DeepLinkHandler.dart';
import '../services/StripeCheckoutService.dart';
import '../services/StreakTrackingService.dart';
import '../services/IntentHandler.dart';
import '../services/WorkoutHistoryService.dart';
import '../ui/widgets/AppBlockOverlay.dart';
import '../controller/PushinController.dart';

/// Enhanced PUSHIN controller integrating:
/// - Core state machine (PushinController)
/// - Daily usage tracking with caps
/// - Workout reward calculation
/// - Platform-specific app monitoring (iOS/Android)
/// - Block overlay trigger logic
/// - Emergency unlock management
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
  late final WorkoutHistoryService _workoutHistoryService;

  // Platform monitors
  FocusModeService? _focusModeService;
  UsageStatsMonitor? _usageStatsMonitor;

  // Native blocking service (Android)
  late final AppBlockingServiceBridge _blockingServiceBridge;
  late final IntentHandler _intentHandler;

  // Subscriptions
  StreamSubscription? _appLaunchSubscription;
  StreamSubscription? _blockingServiceSubscription;
  Timer? _tickTimer;
  Timer? _emergencyUnlockSyncTimer;

  // Block overlay state
  final ValueNotifier<BlockOverlayState?> blockOverlayState =
      ValueNotifier(null);

  // Intent navigation callback (set by UI layer)
  Function(String? blockedApp)? onStartWorkoutFromIntent;

  // Track previous state to detect transitions
  PushinState? _previousState;

  // Payment result states
  final ValueNotifier<SubscriptionStatus?> paymentSuccessState =
      ValueNotifier(null);
  final ValueNotifier<bool> paymentCancelState = ValueNotifier(false);

  // Plan tier (free, pro, advanced)
  String _planTier = 'free';

  // Deep link handler
  DeepLinkHandler? _deepLinkHandler;

  // Emergency Unlock State
  bool _emergencyUnlockEnabled = true;
  int _emergencyUnlockMinutes = 10;
  int _emergencyUnlocksUsedToday = 0;
  int _maxEmergencyUnlocksPerDay = 3;
  DateTime? _emergencyUnlockResetTime;
  DateTime? _currentEmergencyUnlockExpiry;

  // Blocked apps list - populated with common distracting apps by default
  List<String> _blockedApps = [];

  // iOS Screen Time tokens (stored after user selects apps via Family Activity Picker)
  List<String> _iosAppTokens = [];
  List<String> _iosCategoryTokens = [];
  bool _iosBlockingActive = false;

  // Pending workout navigation (from iOS shield action)
  bool _pendingWorkoutNavigation = false;

  // Default blocked apps (common distracting apps)
  static const List<Map<String, String>> defaultBlockedApps = [
    {
      'name': 'Instagram',
      'packageName': 'com.instagram.android',
      'bundleId': 'com.burbn.instagram'
    },
    {
      'name': 'TikTok',
      'packageName': 'com.zhiliaoapp.musically',
      'bundleId': 'com.zhiliaoapp.musically'
    },
    {
      'name': 'Facebook',
      'packageName': 'com.facebook.katana',
      'bundleId': 'com.facebook.Facebook'
    },
    {
      'name': 'Twitter',
      'packageName': 'com.twitter.android',
      'bundleId': 'com.atebits.Tweetie2'
    },
    {
      'name': 'YouTube',
      'packageName': 'com.google.android.youtube',
      'bundleId': 'com.google.ios.youtube'
    },
    {
      'name': 'Snapchat',
      'packageName': 'com.snapchat.android',
      'bundleId': 'com.toyopagroup.picaboo'
    },
    {
      'name': 'Reddit',
      'packageName': 'com.reddit.frontpage',
      'bundleId': 'com.reddit.Reddit'
    },
    {
      'name': 'Netflix',
      'packageName': 'com.netflix.mediaclient',
      'bundleId': 'com.netflix.Netflix'
    },
  ];

  PushinAppController({
    required WorkoutTrackingService workoutService,
    required UnlockService unlockService,
    required AppBlockingService blockingService,
    required List<AppBlockTarget> blockTargets,
    DailyUsageTracker? usageTracker,
    WorkoutRewardCalculator? rewardCalculator,
    StreakTrackingService? streakTracker,
    int gracePeriodSeconds = 0, // Instant blocking - no grace period
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

    // Initialize workout history service
    _workoutHistoryService = WorkoutHistoryService();
    await _workoutHistoryService.initialize();

    // Initialize native blocking service (Android)
    _blockingServiceBridge = AppBlockingServiceBridge.instance;
    await _blockingServiceBridge.initialize();

    // Listen for events from native blocking service
    _blockingServiceSubscription =
        _blockingServiceBridge.events.listen(_handleBlockingServiceEvent);

    // Initialize intent handler (Android) to handle app launches from native service
    _intentHandler = IntentHandler();
    _intentHandler.initialize(
      onStartWorkoutIntent: (blockedApp) {
        print('Intent: Start workout requested for app: $blockedApp');
        // Dismiss native overlay
        _blockingServiceBridge.dismissOverlay();
        // Notify UI layer to navigate to workout screen
        onStartWorkoutFromIntent?.call(blockedApp);
      },
    );

    // Initialize platform settings (saves current emergency unlock settings for extension/service access)
    IOSSettingsBridge.instance
        .setEmergencyUnlockEnabled(_emergencyUnlockEnabled);
    IOSSettingsBridge.instance
        .setEmergencyUnlockMinutes(_emergencyUnlockMinutes);

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
        // Start the native blocking service
        await _startNativeBlockingService();
      }
    }

    // Start tick timer for state transitions
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tick(),
    );

    // Start emergency unlock sync timer (iOS only) - syncs every 3 seconds
    if (!kIsWeb && Platform.isIOS) {
      _startEmergencyUnlockSync();
    }

    // Initialize previous state
    _previousState = currentState;

    // Proactively show overlay if user is in locked/expired state at startup
    // This ensures the overlay appears when the app opens
    _updateOverlayForState();

    print('═══════════════════════════════════════════════');
    print('🚀 PushinAppController INITIALIZED');
    print('   Current state: $currentState');
    print('   Blocked apps: ${_blockedApps.length} - $_blockedApps');
    print('   iOS app tokens: ${_iosAppTokens.length}');
    print('   iOS category tokens: ${_iosCategoryTokens.length}');
    print('   hasIOSBlockingConfigured: $hasIOSBlockingConfigured');
    print('   Platform: ${Platform.isIOS ? "iOS" : "Android"}');
    print('   blockOverlayState: ${blockOverlayState.value?.reason}');
    print('═══════════════════════════════════════════════');
  }

  /// Start the native Android blocking service
  Future<void> _startNativeBlockingService() async {
    if (kIsWeb || !Platform.isAndroid) return;

    // Check if we have overlay permission
    final hasOverlay = await _blockingServiceBridge.hasOverlayPermission();
    if (!hasOverlay) {
      print('Native blocking: Overlay permission not granted');
      // Will request permission when user enables blocking in settings
    }

    // Start the service
    await _blockingServiceBridge.startService();

    // Send blocked apps to native service
    await _blockingServiceBridge.updateBlockedApps(_blockedApps);

    // Sync current state to native service
    await _syncStateToNativeService();

    print('Native blocking service started');
  }

  /// Sync current state to the native blocking service
  Future<void> _syncStateToNativeService() async {
    if (kIsWeb || !Platform.isAndroid) return;

    if (currentState == PushinState.unlocked) {
      final remainingSeconds = getUnlockTimeRemaining(DateTime.now());
      await _blockingServiceBridge.setUnlocked(remainingSeconds);
    } else {
      await _blockingServiceBridge.setLocked();
    }
  }

  /// Handle events from the native blocking service
  void _handleBlockingServiceEvent(BlockingServiceEvent event) {
    if (event is EmergencyUnlockUsedEvent) {
      print('Native: Emergency unlock used for ${event.blockedApp}');
      // Update our state to reflect the emergency unlock
      _emergencyUnlocksUsedToday++;
      _currentEmergencyUnlockExpiry =
          DateTime.now().add(Duration(minutes: event.durationMinutes));
      notifyListeners();
    } else if (event is BlockedAppDetectedEvent) {
      print('Native: Blocked app detected: ${event.blockedApp}');
      // The native overlay handles this, but we can track it
    }
  }

  /// Initialize iOS Screen Time monitoring
  Future<void> _initializeIOSMonitoring() async {
    try {
      _focusModeService = FocusModeService.forIOS();
      await _focusModeService!.initialize();

      print('✅ Focus Mode Service initialized');
      print(
          '🔐 Authorization status: ${_focusModeService!.authorizationStatus}');

      // Load stored iOS tokens from SharedPreferences
      await _loadIOSTokens();

      // CRITICAL FIX: Load blocked apps on iOS too (was missing before!)
      // This ensures overlay can show even if user hasn't used iOS Family Picker
      await _loadBlockedApps();

      // If we have iOS tokens configured, ensure apps are blocked by default
      if (_iosAppTokens.isNotEmpty || _iosCategoryTokens.isNotEmpty) {
        print('iOS: Tokens configured - ensuring apps are blocked by default');
        await _restoreIOSBlocking();
      } else if (_blockedApps.isNotEmpty) {
        print(
            'iOS: Blocked apps configured but no Screen Time tokens - user needs to set up blocking');
      }

      // Check if blocking should be active based on current state
      _checkIOSBlockingState();
    } catch (e) {
      // Graceful fallback when native module not available
      // This happens when:
      // - Running in simulator
      // - Xcode project not configured
      // - iOS native module not registered
      print('❌ Screen Time monitoring unavailable: $e');
      print('🔄 Falling back to UX overlay (works for 100% of users)');
      _focusModeService = null;

      // Still load blocked apps even if Screen Time fails
      await _loadBlockedApps();
    }
  }

  /// Load iOS Screen Time tokens from storage
  Future<void> _loadIOSTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _iosAppTokens = prefs.getStringList('ios_app_tokens') ?? [];
      _iosCategoryTokens = prefs.getStringList('ios_category_tokens') ?? [];
      print(
          'Loaded ${_iosAppTokens.length} app tokens and ${_iosCategoryTokens.length} category tokens');
    } catch (e) {
      print('Error loading iOS tokens: $e');
    }
  }

  /// Save iOS Screen Time tokens to storage
  Future<void> _saveIOSTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('ios_app_tokens', _iosAppTokens);
      await prefs.setStringList('ios_category_tokens', _iosCategoryTokens);
    } catch (e) {
      print('Error saving iOS tokens: $e');
    }
  }

  /// Check if iOS blocking should be active based on current state
  void _checkIOSBlockingState() {
    if (_focusModeService == null) return;

    // Use the centralized overlay state management
    _updateOverlayForState();
  }

  /// Present iOS Family Activity Picker for app selection
  /// Returns true if user selected apps, false otherwise
  Future<bool> presentIOSAppPicker() async {
    if (_focusModeService == null) return false;

    try {
      // First ensure we have Screen Time permission
      if (!_focusModeService!.isAuthorized) {
        final authResult =
            await _focusModeService!.requestScreenTimePermission();
        if (authResult != AuthorizationResult.granted) {
          print('Screen Time permission not granted');
          return false;
        }
      }

      // Present the picker
      final result = await _focusModeService!.presentAppPicker();
      if (result != null && result.hasSelection) {
        _iosAppTokens = result.appTokens;
        _iosCategoryTokens = result.categoryTokens;
        await _saveIOSTokens();
        print('User selected ${result.totalSelected} items for blocking');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Error presenting app picker: $e');
      return false;
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

      // Load blocked apps from storage or use defaults
      await _loadBlockedApps();

      // Set up blocked apps in the monitor
      await _syncBlockedAppsToMonitor();

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

  /// Load blocked apps from storage or initialize with defaults
  Future<void> _loadBlockedApps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedApps = prefs.getStringList('blocked_apps');

      if (storedApps != null && storedApps.isNotEmpty) {
        _blockedApps = storedApps;
        print('Loaded ${_blockedApps.length} blocked apps from storage');
      } else {
        // Initialize with default blocked apps
        _blockedApps = defaultBlockedApps
            .map((app) =>
                Platform.isIOS ? app['bundleId']! : app['packageName']!)
            .toList();
        // Save defaults to storage
        await prefs.setStringList('blocked_apps', _blockedApps);
        print('Initialized with ${_blockedApps.length} default blocked apps');
      }
      notifyListeners();
    } catch (e) {
      print('Error loading blocked apps: $e');
      // Fall back to defaults
      _blockedApps = defaultBlockedApps
          .map((app) => Platform.isIOS ? app['bundleId']! : app['packageName']!)
          .toList();
    }
  }

  /// Sync blocked apps list to the platform monitor
  Future<void> _syncBlockedAppsToMonitor() async {
    if (_usageStatsMonitor != null) {
      final targets = _blockedApps.map((packageName) {
        // Find the app name from defaults
        final appInfo = defaultBlockedApps.firstWhere(
          (app) =>
              app['packageName'] == packageName ||
              app['bundleId'] == packageName,
          orElse: () => {
            'name': packageName,
            'packageName': packageName,
            'bundleId': packageName
          },
        );
        return AppBlockTarget(
          id: packageName,
          name: appInfo['name']!,
          type: 'app',
          platformAgnosticIdentifier: packageName,
        );
      }).toList();

      await _usageStatsMonitor!.setBlockedApps(targets);
      print('Synced ${targets.length} blocked apps to monitor');
    }
  }

  /// Handle app launch event from platform monitor
  void _handleAppLaunch(AppLaunchEvent event) {
    // Skip if emergency unlock is active
    if (isEmergencyUnlockActive) {
      print('Emergency unlock active, allowing app: ${event.appName}');
      return;
    }

    // Only show block overlay if app is in blocked list and user is in locked/expired state
    if (_blockedApps.contains(event.packageName)) {
      if (currentState == PushinState.locked ||
          currentState == PushinState.expired) {
        print('Blocking app: ${event.appName} (${event.packageName})');
        blockOverlayState.value = BlockOverlayState(
          reason: BlockReason.appBlocked,
          appName: event.appName,
        );
      }
    }
  }

  /// Tick handler - runs every second
  void _tick() {
    final now = DateTime.now();

    // Store previous state to detect transitions
    final previousState = _previousState ?? currentState;

    // Update core state machine
    _core.tick(now);

    // Check if state changed
    final stateChanged = previousState != currentState;
    _previousState = currentState;

    // Check daily usage cap
    _checkDailyCap(now);

    // Update overlay and sync to native service if state changed
    if (stateChanged) {
      print('State transition: $previousState -> $currentState');
      _updateOverlayForState();
      // Sync state to native Android service
      _syncStateToNativeService();
    }

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

  /// Start periodic sync of emergency unlock status from iOS UserDefaults
  void _startEmergencyUnlockSync() {
    debugPrint('🚀 Starting emergency unlock sync timer (iOS only)');
    _emergencyUnlockSyncTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _syncEmergencyUnlockStatus(),
    );
  }

  /// Sync emergency unlock status from iOS UserDefaults to Flutter state
  Future<void> _syncEmergencyUnlockStatus() async {
    try {
      final status = await _focusModeService?.getEmergencyUnlockStatus();
      if (status != null) {
        bool needsNotify = false;

        // Update unlock count if changed
        if (_emergencyUnlocksUsedToday != status.usedToday) {
          debugPrint(
              '🔄 Emergency unlock sync: was $_emergencyUnlocksUsedToday, now ${status.usedToday}');
          _emergencyUnlocksUsedToday = status.usedToday;
          needsNotify = true;
        }

        // Sync emergency unlock expiry from native side
        if (status.isActive && status.expiryTimestamp > 0) {
          final newExpiry = DateTime.fromMillisecondsSinceEpoch(
              (status.expiryTimestamp * 1000).toInt());
          final wasNotActive = _currentEmergencyUnlockExpiry == null;
          if (_currentEmergencyUnlockExpiry != newExpiry) {
            debugPrint(
                '🔄 Emergency unlock expiry sync: active=${status.isActive}, expiry=$newExpiry, timeRemaining=${status.timeRemaining}s');
            _currentEmergencyUnlockExpiry = newExpiry;
            needsNotify = true;

            // Start Live Activity with orange theme if this is a new emergency unlock
            if (wasNotActive && !kIsWeb && Platform.isIOS) {
              debugPrint('🚨 Starting emergency unlock Live Activity...');
              _focusModeService
                  ?.startEmergencyUnlockTimer(status.timeRemaining);
            }
          }
        } else if (!status.isActive && _currentEmergencyUnlockExpiry != null) {
          // Emergency unlock expired - re-apply blocking
          debugPrint(
              '🔄 Emergency unlock expired on native side, re-applying shields');
          _currentEmergencyUnlockExpiry = null;
          needsNotify = true;

          // Re-apply iOS blocking
          if (!kIsWeb && Platform.isIOS && hasIOSBlockingConfigured) {
            await _restoreIOSBlocking();
          }
        }

        if (needsNotify) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error syncing emergency unlock status: $e');
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

    debugPrint(
        '🏋️ completeWorkout called - actualReps: $actualReps, desiredSeconds: $_desiredScreenTimeSeconds');

    // Prevent multiple completion calls for the same workout
    if (_desiredScreenTimeSeconds == null) {
      debugPrint('⚠️ completeWorkout called but no active workout session');
      return;
    }

    // For rep-based workouts, require actualReps > 0
    // For time-based workouts (like plank), allow completion even with 0 reps
    final isTimeBasedWorkout =
        _core.workoutService.getCurrentWorkout()?.type.toLowerCase() == 'plank';
    final shouldComplete = (actualReps > 0 || isTimeBasedWorkout) &&
        _desiredScreenTimeSeconds != null;

    if (shouldComplete) {
      // Record the reps in the workout service
      final workoutService = _core.workoutService as MockWorkoutTrackingService;
      // For time-based workouts, record the target value (seconds completed)
      // instead of actualReps (which is 0 for plank)
      final repsToRecord = isTimeBasedWorkout
          ? (_core.workoutService.getCurrentWorkout()?.targetReps ?? 0)
          : actualReps;
      workoutService.recordReps(repsToRecord, now);

      // Use the stored desired screen time (what the user selected)
      final earnedSeconds = _desiredScreenTimeSeconds!;
      final earnedMinutes = (earnedSeconds / 60).round();

      debugPrint(
          '🎯 Earned time: $earnedMinutes minutes ($earnedSeconds seconds)');

      // Add to daily usage tracker
      await _usageTracker?.addEarnedTime(earnedSeconds);

      // Record workout in history
      final currentWorkout = _core.workoutService.getCurrentWorkout();
      if (currentWorkout != null) {
        // Get workout mode from SharedPreferences (default to 'normal')
        final prefs = await SharedPreferences.getInstance();
        final savedModeIndex = prefs.getInt('selected_workout_mode') ??
            1; // Default to normal (index 1)
        final workoutModes = ['cozy', 'normal', 'tuff'];
        final workoutMode =
            workoutModes[savedModeIndex.clamp(0, workoutModes.length - 1)];

        print(
            '💾 Recording workout history: ${currentWorkout.type}, reps: $actualReps, time: $earnedSeconds, mode: $workoutMode');
        await _workoutHistoryService.recordCompletedWorkout(
          workoutType: currentWorkout.type,
          repsCompleted: actualReps,
          earnedTimeSeconds: earnedSeconds,
          workoutMode: workoutMode,
        );
        print('✅ Workout history recorded');
      } else {
        print('⚠️ No current workout found for history recording');
      }

      // Complete workout in core - this transitions to UNLOCKED state
      _core.completeWorkout(now);

      // Update previous state to track the transition
      _previousState = currentState;

      // Start platform-specific app UNblocking for the earned duration
      // Core controller now handles extending existing sessions
      final totalUnlockSeconds = getUnlockTimeRemaining(now);
      final totalUnlockMinutes = (totalUnlockSeconds / 60).round();

      debugPrint('🔓 Unlock logic:');
      debugPrint('   - Earned seconds: $earnedSeconds');
      debugPrint(
          '   - Total remaining after workout: $totalUnlockSeconds seconds');
      debugPrint('   - Total unlock minutes: $totalUnlockMinutes');

      if (!kIsWeb) {
        if (Platform.isIOS) {
          debugPrint('🍎 iOS: Setting unblock for $totalUnlockMinutes minutes');
          debugPrint(
              '   - hasIOSBlockingConfigured: $hasIOSBlockingConfigured');
          debugPrint(
              '   - iOS tokens: ${_iosAppTokens.length} apps, ${_iosCategoryTokens.length} categories');
          final unlocked = await _startIOSUnblocking(totalUnlockMinutes);
          debugPrint('🍎 iOS unblock result: $unlocked');
        } else if (Platform.isAndroid) {
          // Tell native service user is unlocked with total time
          await _blockingServiceBridge.setUnlocked(totalUnlockSeconds);
        }
      } else {
        debugPrint('⚠️ Running on web - no platform-specific unlocking');
      }

      // Clear the stored desired time
      _desiredScreenTimeSeconds = null;

      // Show congratulatory overlay (auto-dismisses after 3 seconds)
      // Show total unlock time, not just newly earned time
      _showCongratulatoryOverlay(earnedMinutes: totalUnlockMinutes);

      // Record workout for streak tracking
      await recordWorkoutCompletion();

      notifyListeners();
    }
  }

  /// Start iOS Screen Time blocking for a specified duration
  /// Blocks the apps/categories selected by the user
  Future<bool> _startIOSBlocking(int durationMinutes) async {
    if (_focusModeService == null) return false;
    if (_iosAppTokens.isEmpty && _iosCategoryTokens.isEmpty) {
      print(
          'iOS: No app/category tokens configured - skipping Screen Time blocking');
      return false;
    }

    try {
      final result = await _focusModeService!.startFocusSession(
        durationMinutes: durationMinutes,
        blockedAppTokens: _iosAppTokens,
        blockedCategoryTokens: _iosCategoryTokens,
        sessionName: 'PUSHIN Focus Session',
      );

      if (result == FocusSessionResult.started) {
        _iosBlockingActive = true;
        print('iOS Screen Time blocking started for $durationMinutes minutes');
        notifyListeners();
        return true;
      } else if (result == FocusSessionResult.noPermission) {
        print('iOS: Screen Time permission not granted');
      } else if (result == FocusSessionResult.tokensInvalid) {
        print('iOS: App tokens invalid - user needs to re-select apps');
        // Clear invalid tokens
        _iosAppTokens = [];
        _iosCategoryTokens = [];
        await _saveIOSTokens();
      }
      return false;
    } catch (e) {
      print('Error starting iOS blocking: $e');
      return false;
    }
  }

  /// Start iOS Screen Time UNblocking (give access to apps for duration)
  /// Uses manualOverride to remove all shields (unlock apps).
  /// Schedules automatic re-blocking after the duration expires.
  Future<bool> _startIOSUnblocking(int durationMinutes) async {
    debugPrint(
        '🔓 _startIOSUnblocking called - duration: $durationMinutes minutes');

    if (_focusModeService == null) {
      debugPrint('❌ focusModeService is null');
      return false;
    }

    if (_iosAppTokens.isEmpty && _iosCategoryTokens.isEmpty) {
      debugPrint('❌ No iOS app/category tokens - cannot unlock');
      debugPrint(
          '   This means apps were selected but tokens werent saved properly');
      return false;
    }

    debugPrint('✅ Prerequisites met:');
    debugPrint('   - focusModeService: available');
    debugPrint('   - App tokens: ${_iosAppTokens.length}');
    debugPrint('   - Category tokens: ${_iosCategoryTokens.length}');

    try {
      // Use manualOverride to remove all shields (unlocks apps)
      // Pass duration to show unlock timer in Dynamic Island and notifications
      // Swift code: managedSettingsStore.shield.applications = nil
      debugPrint('🚀 Calling manualOverride to UNLOCK apps with timer...');

      final overrideResult = await _focusModeService!.manualOverride(
        durationMinutes: durationMinutes,
      );

      if (overrideResult == OverrideResult.granted) {
        _iosBlockingActive = false; // Apps are now unblocked
        debugPrint('✅ iOS apps UNLOCKED for $durationMinutes minutes');
        debugPrint(
            '   - Timer shown in Dynamic Island and notification center');
        debugPrint('   - _iosBlockingActive set to: $_iosBlockingActive');

        // Schedule re-blocking after the duration expires
        Future.delayed(Duration(minutes: durationMinutes), () {
          debugPrint('⏰ Unblock duration expired, re-blocking apps');
          _restoreIOSBlocking();
        });

        notifyListeners();
        return true;
      } else {
        debugPrint('❌ Manual override was denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error during iOS unblocking: $e');
      return false;
    }
  }

  /// Restore iOS Screen Time blocking (block apps again)
  /// Calls the native Swift reapplyBlocking() method which restores shields
  Future<bool> _restoreIOSBlocking() async {
    if (_focusModeService == null) return false;

    try {
      debugPrint('🔒 Restoring iOS blocking...');
      // Call Swift's reapplyBlocking which sets: managedSettingsStore.shield.applications = storedApplications
      final success = await _focusModeService!.reapplyBlocking();

      if (success) {
        _iosBlockingActive = true; // Apps are now blocked
        debugPrint('✅ iOS Screen Time blocking restored');
        notifyListeners();
        return true;
      } else {
        debugPrint('❌ Failed to restore blocking');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error restoring iOS blocking: $e');
      return false;
    }
  }

  /// Stop iOS Screen Time blocking
  Future<bool> _stopIOSBlocking() async {
    if (_focusModeService == null) {
      debugPrint('_stopIOSBlocking: focusModeService is null, returning true');
      return true; // No service available, nothing to stop
    }

    if (!_iosBlockingActive) {
      debugPrint('_stopIOSBlocking: blocking not active, returning true');
      return true; // Already stopped, nothing to do
    }

    try {
      debugPrint('_stopIOSBlocking: Attempting to end focus session...');
      final success = await _focusModeService!.endFocusSession();

      // Even if endFocusSession returns false (no active session), we should
      // still mark blocking as inactive since that's the desired state
      _iosBlockingActive = false;
      debugPrint(
          '_stopIOSBlocking: Result=$success, _iosBlockingActive set to false');
      notifyListeners();

      return true; // Return true since blocking is now stopped
    } catch (e) {
      debugPrint('❌ Error stopping iOS blocking: $e');
      // Even on error, mark as inactive to prevent stuck state
      _iosBlockingActive = false;
      notifyListeners();
      return true; // Return true to not block the unlock flow
    }
  }

  /// Check if iOS has Screen Time tokens configured
  bool get hasIOSBlockingConfigured =>
      _iosAppTokens.isNotEmpty || _iosCategoryTokens.isNotEmpty;

  /// Check if iOS blocking is currently active
  bool get isIOSBlockingActive => _iosBlockingActive;

  /// Check if there's a pending workout navigation from iOS shield action
  bool get hasPendingWorkoutNavigation => _pendingWorkoutNavigation;

  /// Set pending workout navigation (from iOS shield "Earn Screen Time" button)
  void setPendingWorkoutNavigation(bool value) {
    _pendingWorkoutNavigation = value;
    if (value) {
      // Also trigger the workout intent callback if set
      onStartWorkoutFromIntent?.call(null);
    }
    notifyListeners();
  }

  /// Consume the pending workout navigation flag (call after handling)
  bool consumePendingWorkoutNavigation() {
    if (_pendingWorkoutNavigation) {
      _pendingWorkoutNavigation = false;
      return true;
    }
    return false;
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

  /// Update overlay based on current state.
  /// Called on state transitions and when app resumes from background.
  void _updateOverlayForState() {
    print('🔍 _updateOverlayForState called');
    print('   State: $currentState');
    print('   Blocked apps: ${_blockedApps.length}');
    print('   iOS tokens configured: $hasIOSBlockingConfigured');
    print('   Emergency unlock active: $isEmergencyUnlockActive');
    print('   Current overlay: ${blockOverlayState.value?.reason}');

    // Skip if emergency unlock is active
    if (isEmergencyUnlockActive) {
      print('   → Skipping: emergency unlock active');
      blockOverlayState.value = null;
      return;
    }

    // Skip overlay updates during earning state (user is working out)
    if (currentState == PushinState.earning) {
      print('   → Skipping: user is earning (working out)');
      blockOverlayState.value = null;
      return;
    }

    // Skip if unlocked - no overlay needed
    if (currentState == PushinState.unlocked) {
      print('   → Skipping: user is unlocked');
      // Clear any existing overlay when unlocked
      if (blockOverlayState.value != null &&
          blockOverlayState.value!.reason != BlockReason.workoutCompleted) {
        blockOverlayState.value = null;
      }
      return;
    }

    // Show overlay for locked state (if blocked apps are configured)
    if (currentState == PushinState.locked) {
      final hasBlockingConfigured =
          _blockedApps.isNotEmpty || hasIOSBlockingConfigured;
      print('   → LOCKED state, hasBlockingConfigured: $hasBlockingConfigured');

      if (hasBlockingConfigured) {
        // Only show if no overlay is currently displayed
        if (blockOverlayState.value == null) {
          print('   ✅ SHOWING preWorkout overlay');
          blockOverlayState.value = BlockOverlayState(
            reason: BlockReason.preWorkout,
            appName: null,
          );
        } else {
          print(
              '   → Overlay already showing: ${blockOverlayState.value?.reason}');
        }
      } else {
        print('   → No blocking configured, not showing overlay');
      }
      return;
    }

    // Show overlay for expired state
    if (currentState == PushinState.expired) {
      final hasBlockingConfigured =
          _blockedApps.isNotEmpty || hasIOSBlockingConfigured;
      print(
          '   → EXPIRED state, hasBlockingConfigured: $hasBlockingConfigured');

      if (hasBlockingConfigured) {
        print('   ✅ SHOWING sessionExpired overlay');
        blockOverlayState.value = BlockOverlayState(
          reason: BlockReason.sessionExpired,
          appName: null,
        );
      }
      return;
    }
  }

  /// Show congratulatory overlay after workout completion.
  /// Auto-dismisses after a delay.
  void _showCongratulatoryOverlay({required int earnedMinutes}) {
    blockOverlayState.value = BlockOverlayState(
      reason: BlockReason.workoutCompleted,
      appName: '$earnedMinutes min earned',
    );

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (blockOverlayState.value?.reason == BlockReason.workoutCompleted) {
        blockOverlayState.value = null;
      }
    });
  }

  /// Call this when app comes to foreground to check if overlay should show.
  /// This should be called from the Flutter lifecycle observer.
  void onAppResumed() {
    _updateOverlayForState();
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

  /// Get total number of workouts completed
  int getTotalWorkoutsCompleted() {
    return _streakTracker.getTotalWorkouts();
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

  // ============ Emergency Unlock Getters ============

  /// Whether emergency unlock feature is enabled
  bool get emergencyUnlockEnabled => _emergencyUnlockEnabled;

  /// Minutes per emergency unlock session
  int get emergencyUnlockMinutes => _emergencyUnlockMinutes;

  /// Number of emergency unlocks remaining today
  int get emergencyUnlocksRemaining {
    _checkEmergencyUnlockReset();
    return _maxEmergencyUnlocksPerDay - _emergencyUnlocksUsedToday;
  }

  /// Maximum emergency unlocks allowed per day
  int get maxEmergencyUnlocksPerDay => _maxEmergencyUnlocksPerDay;

  /// Number of emergency unlocks used today
  int get emergencyUnlocksUsedToday => _emergencyUnlocksUsedToday;

  /// Whether an emergency unlock session is currently active
  bool get isEmergencyUnlockActive {
    final isActive = _currentEmergencyUnlockExpiry != null &&
        DateTime.now().isBefore(_currentEmergencyUnlockExpiry!);
    return isActive;
  }

  /// Time remaining in current emergency unlock session (in seconds)
  int get emergencyUnlockTimeRemaining {
    if (_currentEmergencyUnlockExpiry == null) return 0;
    final remaining =
        _currentEmergencyUnlockExpiry!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Get list of blocked apps
  List<String> get blockedApps => List.unmodifiable(_blockedApps);

  // ============ Emergency Unlock Setters ============

  /// Enable or disable emergency unlock feature
  void setEmergencyUnlockEnabled(bool enabled) {
    _emergencyUnlockEnabled = enabled;
    notifyListeners();

    // Save to iOS UserDefaults for extension access
    IOSSettingsBridge.instance.setEmergencyUnlockEnabled(enabled);
  }

  /// Set duration for emergency unlock (in minutes)
  void setEmergencyUnlockMinutes(int minutes) {
    if ([10, 15, 30].contains(minutes)) {
      _emergencyUnlockMinutes = minutes;
      notifyListeners();

      // Save to iOS UserDefaults for extension access
      IOSSettingsBridge.instance.setEmergencyUnlockMinutes(minutes);
    }
  }

  // ============ Android Overlay Permission ============

  /// Check if the app has overlay permission (required for Android blocking)
  Future<bool> hasOverlayPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    return await _blockingServiceBridge.hasOverlayPermission();
  }

  /// Request overlay permission from the user
  /// Opens Android settings for "Display over other apps"
  Future<void> requestOverlayPermission() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _blockingServiceBridge.requestOverlayPermission();
  }

  /// Check if the native blocking service is running
  Future<bool> isBlockingServiceRunning() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    return await _blockingServiceBridge.isServiceRunning();
  }

  /// Update the list of blocked apps and persist to storage
  Future<void> updateBlockedApps(List<String> apps) async {
    _blockedApps = List.from(apps);
    notifyListeners();

    // Persist to storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_apps', _blockedApps);
      print('Saved ${_blockedApps.length} blocked apps to storage');
    } catch (e) {
      print('Error saving blocked apps: $e');
    }

    // Sync to platform monitor (Flutter-based, for when app is in foreground)
    await _syncBlockedAppsToMonitor();

    // Sync to native blocking service (Android, for when app is in background)
    if (!kIsWeb && Platform.isAndroid) {
      await _blockingServiceBridge.updateBlockedApps(_blockedApps);
    }
  }

  // ============ Emergency Unlock Actions ============

  /// Use an emergency unlock to grant temporary access to a blocked app
  /// Returns true if successful, false if no unlocks remaining
  Future<bool> useEmergencyUnlock(String appName) async {
    try {
      debugPrint('🚨 useEmergencyUnlock called for: $appName');

      // Check if emergency unlocks reset is needed
      _checkEmergencyUnlockReset();

      // Check if user has remaining unlocks
      if (_emergencyUnlocksUsedToday >= _maxEmergencyUnlocksPerDay) {
        debugPrint('❌ No emergency unlocks remaining');
        return false;
      }

      // Use an emergency unlock
      _emergencyUnlocksUsedToday++;
      debugPrint(
          '✅ Emergency unlock used (${_emergencyUnlocksUsedToday}/$_maxEmergencyUnlocksPerDay)');

      // Set expiry time
      _currentEmergencyUnlockExpiry =
          DateTime.now().add(Duration(minutes: _emergencyUnlockMinutes));

      // Notify listeners immediately so UI updates to show emergency unlock state
      notifyListeners();
      debugPrint('🔔 notifyListeners called after setting expiry');

      // Dismiss the block overlay
      blockOverlayState.value = null;
      debugPrint('✅ Block overlay dismissed');

      // Grant access via platform module
      debugPrint('🔓 Granting emergency access...');
      await _grantEmergencyAccess(appName);
      debugPrint('✅ Emergency access granted');

      // Sync emergency unlock to native service (Android)
      if (!kIsWeb && Platform.isAndroid) {
        await _blockingServiceBridge
            .activateEmergencyUnlock(_emergencyUnlockMinutes);
      }

      // Notify again after all operations complete
      notifyListeners();

      // Schedule auto-reblock when timer expires
      Future.delayed(Duration(minutes: _emergencyUnlockMinutes), () {
        debugPrint('⏰ Emergency unlock timer expired, re-blocking...');
        _onEmergencyUnlockExpired(appName);
      });

      debugPrint('✅ Emergency unlock complete');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in useEmergencyUnlock: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Check if emergency unlock counter should reset (at midnight)
  void _checkEmergencyUnlockReset() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_emergencyUnlockResetTime == null ||
        _emergencyUnlockResetTime!.isBefore(today)) {
      // Reset the counter
      _emergencyUnlocksUsedToday = 0;
      _emergencyUnlockResetTime = today;
      notifyListeners();
    }
  }

  /// Grant emergency access via platform module
  Future<void> _grantEmergencyAccess(String appName) async {
    if (!kIsWeb) {
      if (Platform.isIOS && _focusModeService != null) {
        // For emergency unlock, we need to:
        // 1. Unlock the apps WITHOUT starting the regular green Live Activity
        // 2. Start the orange emergency Live Activity separately

        debugPrint('🚨 Emergency unlock: Unlocking apps...');

        // Check prerequisites
        if (_iosAppTokens.isEmpty && _iosCategoryTokens.isEmpty) {
          debugPrint('❌ No iOS app/category tokens - cannot unlock');
          return;
        }

        // Unlock apps without starting timer (don't pass durationMinutes)
        final overrideResult = await _focusModeService!.manualOverride();

        if (overrideResult == OverrideResult.granted) {
          _iosBlockingActive = false;
          debugPrint('✅ iOS apps UNLOCKED for emergency');

          // Start emergency unlock Live Activity with orange theme
          debugPrint(
              '🚨 Starting emergency unlock Live Activity (orange theme)...');
          final durationSeconds = _emergencyUnlockMinutes * 60;
          await _focusModeService!.startEmergencyUnlockTimer(durationSeconds);
          debugPrint(
              '✅ Emergency Live Activity started - should show in Dynamic Island');

          // Schedule re-blocking after the duration expires
          Future.delayed(Duration(minutes: _emergencyUnlockMinutes), () {
            debugPrint('⏰ Emergency unlock duration expired, re-blocking apps');
            _restoreIOSBlocking();
          });

          notifyListeners();
        } else {
          debugPrint('❌ Manual override was denied');
        }
      } else if (Platform.isAndroid && _usageStatsMonitor != null) {
        // On Android, we rely on the overlay dismissal
        // The app is already accessible once the overlay is dismissed
        await _usageStatsMonitor!.grantEmergencyAccess(
          appName: appName,
          durationMinutes: _emergencyUnlockMinutes,
        );
      }
    }
  }

  /// Called when emergency unlock timer expires
  Future<void> _onEmergencyUnlockExpired(String appName) async {
    _currentEmergencyUnlockExpiry = null;

    // Restore iOS blocking if we have tokens configured
    if (!kIsWeb && Platform.isIOS && hasIOSBlockingConfigured) {
      // Restore permanent blocking
      await _restoreIOSBlocking();
    }

    // Show block overlay again if app is still blocked
    if (_blockedApps.isNotEmpty) {
      blockOverlayState.value = BlockOverlayState(
        reason: BlockReason.sessionExpired,
        appName: appName,
      );
    }

    notifyListeners();
  }

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
    _blockingServiceSubscription?.cancel();
    _tickTimer?.cancel();
    _emergencyUnlockSyncTimer?.cancel();
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
