import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
import '../services/PaymentService.dart';
import '../services/StreakTrackingService.dart';
import '../services/IntentHandler.dart';
import '../services/WorkoutHistoryService.dart';
import '../ui/widgets/AppBlockOverlay.dart';
import '../controller/PushinController.dart';
import 'auth_state_provider.dart';
import '../services/rating_service.dart';

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
  final AuthStateProvider _authProvider;
  final DailyUsageTracker? _usageTracker;
  final WorkoutRewardCalculator _rewardCalculator;
  late final StreakTrackingService _streakTracker;
  late final WorkoutHistoryService _workoutHistoryService;
  
  // Payment Service
  final PaymentService _paymentService = PaymentConfig.createService();

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

  // Rating check callback (set by UI layer to trigger rating after workout)
  VoidCallback? onCheckWorkoutRating;

  // Tab navigation request (used to switch tabs from deep screens)
  int? _requestedTabIndex;
  int? get requestedTabIndex => _requestedTabIndex;

  void requestTabChange(int index) {
    _requestedTabIndex = index;
    notifyListeners();
  }

  void consumeTabRequest() {
    _requestedTabIndex = null;
  }

  // Track previous state to detect transitions
  PushinState? _previousState;

  // Payment result states
  final ValueNotifier<SubscriptionStatus?> paymentSuccessState =
      ValueNotifier(null);
  final ValueNotifier<bool> paymentCancelState = ValueNotifier(false);

  // Upgrade welcome state (for showing AdvancedUpgradeWelcomeScreen)
  final ValueNotifier<bool> upgradeWelcomeState = ValueNotifier(false);

  // Password reset state (for handling password reset deep links)
  final ValueNotifier<String?> passwordResetToken = ValueNotifier(null);

  // Subscription cancellation state (for showing cancellation screen)
  final ValueNotifier<String?> subscriptionCancelledPlan = ValueNotifier(null);

  // Plan tier (free, pro, advanced)
  String _planTier = 'free';
  String? _previousPlanTier; // Track previous tier to detect upgrades

  // Deep link handler
  DeepLinkHandler? _deepLinkHandler;

  // Emergency Unlock State
  bool _emergencyUnlockEnabled = false;
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
  bool _iosBlockingConfigured =
      false; // Tracks if user has completed iOS app selection

  // Pending workout navigation (from iOS shield action)
  bool _pendingWorkoutNavigation = false;

  // iOS Token Getters
  List<String> get iosAppTokens => _iosAppTokens;
  List<String> get iosCategoryTokens => _iosCategoryTokens;
  bool get hasIOSBlockingConfigured => _iosBlockingConfigured;

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
      'name': 'Figma',
      'packageName': 'com.figma.mirror',
      'bundleId': 'com.figma.Desktop'
    },
  ];

  PushinAppController({
    required WorkoutTrackingService workoutService,
    required UnlockService unlockService,
    required AppBlockingService blockingService,
    required List<AppBlockTarget> blockTargets,
    required AuthStateProvider authProvider,
    DailyUsageTracker? usageTracker,
    WorkoutRewardCalculator? rewardCalculator,
    StreakTrackingService? streakTracker,
    int gracePeriodSeconds = 0, // Instant blocking - no grace period
  })  : _authProvider = authProvider,
        _usageTracker = usageTracker,
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

    // Check for pending emergency unlocks initiated from shield
    await _checkForPendingEmergencyUnlock();

    // Increment app launch count for rating prompting
    try {
      await RatingService.create().then((s) => s.incrementLaunchCount());
    } catch (e) {
      print('⚠️ Error incrementing launch count: $e');
    }

    // Initialize Payment Service using Configuration
    final paymentService = PaymentConfig.createService();

    // Load current plan tier from cached subscription status
    await _loadCachedPlanTier(paymentService);

    _deepLinkHandler = DeepLinkHandler(
      stripeService: paymentService,
      getCurrentUserId: () => _authProvider.currentUser?.id,
      onPaymentSuccess: (status) async {
        print('═══════════════════════════════════════════════');
        print('💰 PAYMENT SUCCESS CALLBACK');
        print('   - New plan: ${status.planId}');
        print('   - isActive: ${status.isActive}');
        print('   - subscriptionId: ${status.subscriptionId}');
        print('   - customerId: ${status.customerId}');
        print('   - currentPeriodEnd: ${status.currentPeriodEnd}');
        print('   - Current plan tier: $_planTier');
        print('   - Previous plan tier: $_previousPlanTier');
        print('   - currentUserId: ${_authProvider.currentUser?.id}');
        print('═══════════════════════════════════════════════');

        // Detect if this is an upgrade from PRO to ADVANCED
        final currentTier = _planTier;
        final newTier = status.planId;
        final isUpgradeToAdvanced =
            (currentTier == 'pro' || _previousPlanTier == 'pro') &&
                newTier == 'advanced';

        print('💰 Upgrade detection:');
        print('   - Current tier: $currentTier');
        print('   - Previous tier: $_previousPlanTier');
        print('   - New tier: $newTier');
        print('   - Is upgrade to ADVANCED: $isUpgradeToAdvanced');

        // Update previous tier before changing current tier
        _previousPlanTier = _planTier;

        // Update plan tier based on subscription
        _planTier = status.planId;
        print('✅ Updated _planTier from $currentTier to $_planTier');

        // CRITICAL: Save subscription status to cache with user ID
        final currentUserId = _authProvider.currentUser?.id;
        if (currentUserId != null) {
          try {
            final statusWithUserId = SubscriptionStatus(
              isActive: status.isActive,
              planId: status.planId,
              customerId: status.customerId,
              subscriptionId: status.subscriptionId,
              currentPeriodEnd: status.currentPeriodEnd,
              cachedUserId: currentUserId,
            );
            await _paymentService.saveSubscriptionStatus(statusWithUserId);
            print(
                '✅ Subscription status saved to cache with userId: $currentUserId');
          } catch (e) {
            print('❌ Error saving subscription status: $e');
          }
        } else {
          print(
              '⚠️ No user ID available - subscription may not persist correctly');
        }

        // CRITICAL: Update usage tracker with new plan tier
        try {
          await _usageTracker?.updatePlanTier(_planTier);
          print('✅ Usage tracker updated with plan tier: $_planTier');
        } catch (e) {
          print('❌ Error updating usage tracker: $e');
        }

        // Sync emergency unlock with plan tier
        _syncEmergencyUnlockWithPlanTier();

        if (isUpgradeToAdvanced) {
          // User upgraded from PRO to ADVANCED - show upgrade welcome screen
          print(
              '🎉 Detected upgrade to ADVANCED - setting upgradeWelcomeState');
          upgradeWelcomeState.value = true;
          // Don't set paymentSuccessState for upgrades - use the upgrade screen instead
        } else {
          // New subscription (not an upgrade) - show regular success screen
          print('💰 New subscription - setting paymentSuccessState');
          // IMPORTANT: Set paymentSuccessState BEFORE notifyListeners
          // This ensures AppRouter sees the success state when it rebuilds
          paymentSuccessState.value = status;
          print('💰 paymentSuccessState set, triggering router rebuild');
        }

        // Trigger AppRouter rebuild to show appropriate screen
        notifyListeners();
        print(
            '🔔 notifyListeners called - UI should update with plan tier: $_planTier');

        // Note: Don't auto-reset states here
        // Success screens will clear them when user taps continue
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
      onPasswordReset: (String token) {
        print('🔑 Password reset deep link received');
        print('   Token: ${token.substring(0, 8)}...');

        // Store the token to trigger navigation to ResetPasswordScreen
        passwordResetToken.value = token;

        // Auto-clear after navigation (will be handled by the screen)
        Future.delayed(const Duration(seconds: 1), () {
          if (passwordResetToken.value == token) {
            print('🧹 Auto-clearing password reset token');
            passwordResetToken.value = null;
          }
        });
      },
      onSubscriptionCancelled: (String? previousPlan) {
        print('🚨 Subscription cancelled callback');
        print('   Previous plan: $previousPlan');

        // Store the cancelled plan to trigger navigation to SubscriptionCancelledScreen
        subscriptionCancelledPlan.value = previousPlan;

        // Auto-clear after navigation (will be handled by the screen)
        Future.delayed(const Duration(seconds: 1), () {
          if (subscriptionCancelledPlan.value == previousPlan) {
            print('🧹 Auto-clearing subscription cancelled plan');
            subscriptionCancelledPlan.value = null;
          }
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
      _iosBlockingConfigured =
          prefs.getBool('ios_blocking_configured') ?? false;
      print(
          'Loaded ${_iosAppTokens.length} app tokens and ${_iosCategoryTokens.length} category tokens, configured: $_iosBlockingConfigured');
      // Notify listeners since blockedApps getter now depends on iOS tokens
      notifyListeners();
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
      await prefs.setBool('ios_blocking_configured', _iosBlockingConfigured);
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
      if (result != null) {
        _iosAppTokens = result.appTokens;
        _iosCategoryTokens = result.categoryTokens;
        _iosBlockingConfigured =
            true; // Mark as configured even if 0 apps selected
        await _saveIOSTokens();
        print('User selected ${result.totalSelected} items for blocking');

        // Update blocking state immediately
        if (_iosAppTokens.isEmpty && _iosCategoryTokens.isEmpty) {
          print('User cleared all apps - explicitly disabling all restrictions');
          // Use emergencyDisable to force clear shields even if session state is lost
          await _focusModeService!.emergencyDisable();
          _iosBlockingActive = false;
        } else {
          // If we are currently in a state that should be blocked, refresh the shield
          if (_iosBlockingActive ||
              currentState == PushinState.locked ||
              currentState == PushinState.expired) {
            print('User updated apps - refreshing iOS blocking');
            await _restoreIOSBlocking();
          }
        }

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
        // Migrate Netflix to Figma if present
        _blockedApps = storedApps.map((app) {
          if (app == 'com.netflix.mediaclient') {
            return Platform.isIOS ? 'com.figma.Desktop' : 'com.figma.mirror';
          }
          return app;
        }).toList();
        // Save migrated list
        await prefs.setStringList('blocked_apps', _blockedApps);
        print('Migrated Netflix to Figma in stored blocked apps');
        print(
            'Loaded ${_blockedApps.length} blocked apps from storage (migrated)');
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

      // Record workout completion for streak and rating
      await recordWorkoutCompletion();

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

      // Increment workout count for rating prompts (first workout trigger)
      try {
        final ratingService = await RatingService.create();
        await ratingService.incrementWorkoutCount();
        debugPrint('⭐ Workout count incremented to ${ratingService.workoutCount}');
        
        // Trigger rating check callback after increment completes
        // This ensures the UI can check the rating conditions with the updated count
        if (onCheckWorkoutRating != null) {
          debugPrint('⭐ Calling onCheckWorkoutRating callback');
          // Use post-frame callback to ensure UI is ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onCheckWorkoutRating?.call();
          });
        }
      } catch (e) {
        debugPrint('⚠️ Error updating rating service: $e');
      }

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
        notifyListeners();
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

  /// Check if iOS blocking is currently active
  bool get isIOSBlockingActive => _iosBlockingActive;

  /// Check if user has completed iOS app selection setup (even if they selected 0 apps)
  bool get hasIOSBlockingBeenConfigured => _iosBlockingConfigured;

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
    print('   User authenticated: ${_authProvider.isAuthenticated}');

    // Skip overlay updates for unauthenticated users (welcome/onboarding screens)
    if (!_authProvider.isAuthenticated) {
      print(
          '   → Skipping: user not authenticated (welcome/onboarding screen)');
      blockOverlayState.value = null;
      return;
    }

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

    // Increment workout count for rating prompts
    try {
      final s = await RatingService.create();
      await s.incrementWorkoutCount();
      debugPrint(
          '⭐ RatingService: Workout count incremented via recordWorkoutCompletion');
    } catch (e) {
      debugPrint('⚠️ RatingService: Error incrementing workout count: $e');
    }

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

  /// Load cached plan tier from PaymentService on startup
  Future<void> _loadCachedPlanTier(PaymentService paymentService) async {
    try {
      print('📦 Loading cached subscription status...');
      final cachedStatus = await paymentService.getCachedSubscriptionStatus();

      if (cachedStatus != null) {
        print('📦 Found cached status:');
        print('   - planId: ${cachedStatus.planId}');
        print('   - isActive: ${cachedStatus.isActive}');
        print('   - customerId: ${cachedStatus.customerId}');
      } else {
        print('📦 No cached subscription status found');
      }

      if (cachedStatus != null && cachedStatus.isActive) {
        _planTier = cachedStatus.planId;
        _previousPlanTier = _planTier; // Initialize previous tier
        print('✅ Loaded cached plan tier: $_planTier');

        // Also update the usage tracker with the plan tier
        await _usageTracker?.updatePlanTier(_planTier);
        print('✅ Updated usage tracker with plan tier: $_planTier');
      } else {
        _planTier = 'free';
        _previousPlanTier = 'free'; // Initialize previous tier
        print('📦 No active subscription, defaulting to free tier');
      }

      // Notify listeners so UI updates with the loaded plan tier
      notifyListeners();
      print('🔔 notifyListeners called after loading cached plan tier');
    } catch (e) {
      print('❌ Error loading cached plan tier: $e');
      _planTier = 'free';
      _previousPlanTier = 'free';
    }
  }

  /// Refresh plan tier from cached subscription status
  ///
  /// Call this after login/logout to ensure the UI shows the correct subscription tier
  /// Requires authenticated user - subscriptions are only available after sign up
  Future<void> refreshPlanTier() async {
    print('🔄 ═══════════════════════════════════════════════');
    print('🔄 refreshPlanTier() called');
    print('   - isAuthenticated: ${_authProvider.isAuthenticated}');
    print('   - currentUser: ${_authProvider.currentUser?.id}');
    print('🔄 ═══════════════════════════════════════════════');

    final paymentService = PaymentConfig.createService();

    // 1. Handle Unauthenticated State - always free tier
    if (!_authProvider.isAuthenticated) {
      print('👤 User not authenticated - setting plan to free');
      _planTier = 'free';
      _previousPlanTier = 'free';
      await _usageTracker?.updatePlanTier(_planTier);
      notifyListeners();
      return;
    }

    final currentUserId = _authProvider.currentUser?.id;
    if (currentUserId == null) {
      print('⚠️ Authenticated but no user ID - this should not happen');
      _planTier = 'free';
      _previousPlanTier = 'free';
      await _usageTracker?.updatePlanTier(_planTier);
      notifyListeners();
      return;
    }

    // 2. Check Local Cache
    final cachedStatus = await paymentService.getCachedSubscriptionStatus();
    print(
        '📦 Cached status: ${cachedStatus?.planId}, active: ${cachedStatus?.isActive}, cachedUserId: ${cachedStatus?.cachedUserId}');

    // 3. Validate Cache - must belong to current user
    if (cachedStatus != null &&
        cachedStatus.isActive &&
        cachedStatus.cachedUserId == currentUserId) {
      _planTier = cachedStatus.planId;
      _previousPlanTier = _planTier;
      await _usageTracker?.updatePlanTier(_planTier);
      print('✅ Restored plan from cache (user match): $_planTier');
      notifyListeners();
      return;
    }

    // 4. Handle legacy cache with no user ID - claim it for current user
    if (cachedStatus != null &&
        cachedStatus.isActive &&
        cachedStatus.cachedUserId == null) {
      print(
          '🔗 Linking legacy subscription (no cachedUserId) to user $currentUserId');

      final claimedStatus = SubscriptionStatus(
        isActive: cachedStatus.isActive,
        planId: cachedStatus.planId,
        customerId: cachedStatus.customerId,
        subscriptionId: cachedStatus.subscriptionId,
        currentPeriodEnd: cachedStatus.currentPeriodEnd,
        cachedUserId: currentUserId,
      );

      await paymentService.saveSubscriptionStatus(claimedStatus);
      _planTier = claimedStatus.planId;
      _previousPlanTier = _planTier;
      await _usageTracker?.updatePlanTier(_planTier);
      print('✅ Legacy subscription linked: $_planTier');
      notifyListeners();
      return;
    }

    // 5. Cache is missing, inactive, or belongs to different user - fetch from server
    if (cachedStatus != null && cachedStatus.cachedUserId != currentUserId) {
      print(
          '⚠️ Cache belongs to different user (${cachedStatus.cachedUserId}). Fetching fresh data...');
    } else {
      print('ℹ️ No valid cache. Fetching from server...');
    }

    try {
      print(
          '🌐 Fetching subscription status from server for user: $currentUserId');
      final freshStatus = await paymentService.checkSubscriptionStatus(
        userId: currentUserId,
      );

      if (freshStatus != null && freshStatus.isActive) {
        _planTier = freshStatus.planId;
        _previousPlanTier = _planTier;
        await _usageTracker?.updatePlanTier(_planTier);
        print('✅ Server fetch success. Plan: $_planTier');
      } else {
        // User is confirmed free on server
        print('ℹ️ No active subscription on server for user $currentUserId');
        _planTier = 'free';
        _previousPlanTier = 'free';
        // Cache the 'free' status with user ID to avoid repeated server calls
        await paymentService.saveSubscriptionStatus(SubscriptionStatus(
            isActive: false, planId: 'free', cachedUserId: currentUserId));
        await _usageTracker?.updatePlanTier(_planTier);
        print('✅ Confirmed free tier on server.');
      }
    } catch (e) {
      print('❌ Error fetching fresh subscription status: $e');
      // On error, default to free if no plan set
      if (_planTier.isEmpty) {
        _planTier = 'free';
        _previousPlanTier = 'free';
        await _usageTracker?.updatePlanTier(_planTier);
      }
      print('⚠️ Using fallback plan tier: $_planTier');
    }

    // Sync emergency unlock with plan tier after any tier change
    _syncEmergencyUnlockWithPlanTier();

    notifyListeners();
  }

  /// Clear the upgrade welcome state after user sees the welcome screen
  Future<void> clearUpgradeWelcomeState() async {
    print('🧹 Clearing upgrade welcome state');
    print('   - Current plan tier: $_planTier');
    upgradeWelcomeState.value = false;
    notifyListeners();
    print('   - Plan tier after clear: $_planTier (should remain advanced)');
  }

  /// Clear the subscription cancelled state
  void clearSubscriptionCancelled() {
    print('🧹 Clearing subscription cancelled state');
    subscriptionCancelledPlan.value = null;
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

  /// Set the pending checkout user ID for payment verification
  /// Call this before launching Stripe checkout so the deep link handler
  /// knows which user to verify the payment for
  void setPendingCheckoutUserId(String? userId) {
    _deepLinkHandler?.pendingCheckoutUserId = userId;
    print('💳 Set pendingCheckoutUserId: $userId');
  }

  /// Store subscription status before opening customer portal
  /// Call this before opening the portal so we can detect if user cancels
  Future<void> setSubscriptionBeforePortal(SubscriptionStatus? status) async {
    _deepLinkHandler?.setSubscriptionBeforePortal(status);
    print('💳 Stored subscription before portal: ${status?.planId}');
  }

  /// Set the pending checkout plan ID for payment verification fallback
  /// Call this before launching Stripe checkout so the deep link handler
  /// knows which plan to show if backend verification fails
  Future<void> setPendingCheckoutPlanId(String? planId) async {
    _deepLinkHandler?.pendingCheckoutPlanId = planId;

    // CRITICAL: Persist to SharedPreferences so it survives app kill/recreation
    try {
      final prefs = await SharedPreferences.getInstance();
      if (planId != null) {
        await prefs.setString('pending_checkout_plan_id', planId);
        print('💳 Set and persisted pendingCheckoutPlanId: $planId');
      } else {
        await prefs.remove('pending_checkout_plan_id');
        print('💳 Cleared pendingCheckoutPlanId');
      }
    } catch (e) {
      print('❌ Error persisting pendingCheckoutPlanId: $e');
    }
  }

  // ============ Emergency Unlock Getters ============

  /// Whether emergency unlock feature is enabled (user toggle)
  bool get emergencyUnlockEnabled => _emergencyUnlockEnabled;

  /// Whether user has access to emergency unlock (requires Pro or Advanced plan)
  bool get hasEmergencyUnlockAccess =>
      _planTier == 'pro' || _planTier == 'advanced';

  /// Whether user can use emergency unlock (has access AND it's enabled)
  bool get canUseEmergencyUnlock =>
      hasEmergencyUnlockAccess && _emergencyUnlockEnabled;

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
  List<String> get blockedApps {
    // For iOS, if user has completed iOS setup, return the iOS tokens (even if empty)
    if (!kIsWeb && Platform.isIOS && hasIOSBlockingBeenConfigured) {
      return List.unmodifiable([..._iosAppTokens, ..._iosCategoryTokens]);
    }
    // For iOS without setup completed, return empty list (no apps blocked)
    if (!kIsWeb && Platform.isIOS) {
      return const [];
    }
    // For Android, return the blocked apps list
    return List.unmodifiable(_blockedApps);
  }

  // ============ Emergency Unlock Setters ============

  /// Enable or disable emergency unlock feature
  /// Note: Only Pro and Advanced users can enable this feature
  void setEmergencyUnlockEnabled(bool enabled) {
    // Prevent free/guest users from enabling emergency unlock
    if (enabled && !hasEmergencyUnlockAccess) {
      debugPrint('❌ Cannot enable emergency unlock - requires Pro or Advanced plan');
      return;
    }

    _emergencyUnlockEnabled = enabled;
    notifyListeners();

    // Save to iOS UserDefaults for extension access
    IOSSettingsBridge.instance.setEmergencyUnlockEnabled(enabled);
  }

  /// Sync emergency unlock state with plan tier
  /// Automatically disabled for free/guest users.
  /// For Pro/Advanced users, we preserve their manual setting.
  void _syncEmergencyUnlockWithPlanTier() {
    // If user lost access (downgraded to free), force disable
    if (!hasEmergencyUnlockAccess && _emergencyUnlockEnabled) {
      debugPrint('🔄 Syncing emergency unlock: User lost access, disabling feature');
      setEmergencyUnlockEnabled(false);
    }
    // Note: We do NOT auto-enable when upgrading. User must enable manually.
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
    // Check if user is currently unlocked before updating
    final wasUnlocked = currentState == PushinState.unlocked;

    // On iOS, update iOS tokens; on Android, update blocked apps list
    if (!kIsWeb && Platform.isIOS) {
      _iosAppTokens = List.from(apps);
      _iosBlockingConfigured = true; // Mark as configured
      await _saveIOSTokens();
      print('Updated ${_iosAppTokens.length} iOS app tokens');
    } else {
      _blockedApps = List.from(apps);
      // Persist to storage
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('blocked_apps', _blockedApps);
        print('Saved ${_blockedApps.length} blocked apps to storage');
      } catch (e) {
        print('Error saving blocked apps: $e');
      }

      // Sync to native blocking service (Android, for when app is in background)
      if (!kIsWeb && Platform.isAndroid) {
        await _blockingServiceBridge.updateBlockedApps(_blockedApps);
      }
    }

    notifyListeners();

    // Sync to platform monitor (Flutter-based, for when app is in foreground)
    await _syncBlockedAppsToMonitor();

    // If user was unlocked before updating apps, preserve that unlocked state
    if (wasUnlocked && !kIsWeb && Platform.isIOS && hasIOSBlockingConfigured) {
      print(
          'User was unlocked before app list update - preserving unlocked state');
      // Get remaining unlock time and re-apply unblocking
      final remainingSeconds = getUnlockTimeRemaining(DateTime.now());
      if (remainingSeconds > 0) {
        final remainingMinutes = (remainingSeconds / 60).ceil();
        await _startIOSUnblocking(remainingMinutes);
      }
    }
  }

  // ============ Emergency Unlock Actions ============

  /// Use an emergency unlock to grant temporary access to a blocked app
  /// Returns true if successful, false if no unlocks remaining or feature not available
  Future<bool> useEmergencyUnlock(String appName) async {
    try {
      debugPrint('🚨 useEmergencyUnlock called for: $appName');

      // Check if user has Pro or Advanced plan (emergency unlock is a premium feature)
      if (!hasEmergencyUnlockAccess) {
        debugPrint('❌ Emergency unlock requires Pro or Advanced plan');
        return false;
      }

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

  /// Check for pending emergency unlocks initiated from shield extension
  Future<void> _checkForPendingEmergencyUnlock() async {
    if (!kIsWeb && Platform.isIOS && _focusModeService != null) {
      debugPrint(
          '🔍 Checking for pending shield-initiated emergency unlock...');

      try {
        final status = await _focusModeService!.getEmergencyUnlockStatus();
        if (status.isActive) {
          debugPrint(
              '🚨 Found active emergency unlock from shield - starting timer management');

          if (status.timeRemaining > 0) {
            // Start the emergency unlock Live Activity and schedule re-blocking
            await _focusModeService!
                .startEmergencyUnlockTimer(status.timeRemaining);

            // Schedule re-blocking after remaining time
            Future.delayed(Duration(seconds: status.timeRemaining), () {
              debugPrint(
                  '⏰ Shield-initiated emergency unlock expired, re-blocking apps');
              _restoreIOSBlocking();
            });

            debugPrint(
                '✅ Shield emergency unlock timer started - ${status.timeRemaining}s remaining');
          } else {
            // Already expired, re-block immediately
            debugPrint(
                '⏰ Shield emergency unlock already expired, re-blocking apps');
            _restoreIOSBlocking();
          }
        } else {
          debugPrint('ℹ️ No active emergency unlock from shield');
        }
      } catch (e) {
        debugPrint('❌ Error checking for pending emergency unlock: $e');
      }
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
    upgradeWelcomeState.dispose();
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
