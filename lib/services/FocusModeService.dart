import 'dart:async';
import 'package:flutter/foundation.dart';
import 'platform/ScreenTimeMonitor.dart';

/// PUSHIN Focus Mode Service
///
/// High-level service for managing focus sessions and Screen Time integration.
/// Provides user-friendly API for the Flutter UI with proper error handling.
///
/// Features:
/// - Focus session lifecycle management
/// - Screen Time authorization flow
/// - Blocking rule configuration
/// - Manual override handling
/// - Usage statistics
/// - Graceful fallback when Screen Time unavailable
class FocusModeService extends ChangeNotifier {
  final ScreenTimeService _screenTimeService;

  // Service state
  FocusSessionState _sessionState = FocusSessionState.inactive;
  AuthorizationStatus _authStatus = AuthorizationStatus.notDetermined;
  bool _isInitialized = false;

  // Current session data
  FocusSessionResponse? _currentSession;
  List<BlockingRuleDTO> _activeRules = [];

  // Error handling
  ScreenTimeError? _lastError;
  String? _errorMessage;

  FocusModeService(this._screenTimeService);

  /// Factory constructor for iOS platform
  factory FocusModeService.forIOS() {
    return FocusModeService(ScreenTimeService());
  }

  // MARK: - Public API

  /// Initialize the focus mode service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _checkAuthorizationStatus();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _handleError(e);
    }
  }

  /// Request Screen Time permission with user-friendly explanation
  Future<AuthorizationResult> requestScreenTimePermission() async {
    try {
      const explanation =
          "This allows PUSHIN to create distraction-free focus sessions by temporarily limiting access to selected apps. You can disable this anytime.";

      final response =
          await _screenTimeService.requestAuthorization(explanation);

      _authStatus = response.status;
      _clearError();

      if (response.status == AuthorizationStatus.authorized) {
        return AuthorizationResult.granted;
      } else if (response.status == AuthorizationStatus.denied) {
        return AuthorizationResult.denied;
      } else {
        return AuthorizationResult.restricted;
      }
    } catch (e) {
      _handleError(e);
      return AuthorizationResult.error;
    }
  }

  /// Start a focus session with app blocking
  Future<FocusSessionResult> startFocusSession({
    required int durationMinutes,
    required List<String> blockedAppTokens,
    required List<String> blockedCategoryTokens,
    String? sessionName,
  }) async {
    try {
      // Check authorization first
      if (_authStatus != AuthorizationStatus.authorized) {
        final authResult = await requestScreenTimePermission();
        if (authResult != AuthorizationResult.granted) {
          return FocusSessionResult.noPermission;
        }
      }

      // Create blocking rules
      final rules = <BlockingRuleDTO>[];

      if (blockedAppTokens.isNotEmpty) {
        rules.add(BlockingRuleDTO(
          id: 'focus_apps_${DateTime.now().millisecondsSinceEpoch}',
          type: BlockingRuleType.application,
          activityTokens: blockedAppTokens,
          duration: DurationConfigDTO(minutes: durationMinutes),
          allowOverride: true,
          name: sessionName,
        ));
      }

      if (blockedCategoryTokens.isNotEmpty) {
        rules.add(BlockingRuleDTO(
          id: 'focus_categories_${DateTime.now().millisecondsSinceEpoch}',
          type: BlockingRuleType.category,
          activityTokens: blockedCategoryTokens,
          duration: DurationConfigDTO(minutes: durationMinutes),
          allowOverride: true,
          name: sessionName,
        ));
      }

      // Configure rules
      final configResult =
          await _screenTimeService.configureBlockingRules(rules);
      if (configResult.failedRules.isNotEmpty) {
        if (configResult.hasInvalidTokens) {
          // Tokens are invalid - user needs to re-select apps
          return FocusSessionResult.tokensInvalid;
        }
        return FocusSessionResult.configurationFailed;
      }

      // Start the session
      final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      final sessionResponse = await _screenTimeService.startFocusSession(
        sessionId: sessionId,
        durationMinutes: durationMinutes,
        ruleIds: rules.map((r) => r.id).toList(),
      );

      // Update state
      _currentSession = sessionResponse;
      _activeRules = rules;
      _sessionState = FocusSessionState.active;
      _clearError();
      notifyListeners();

      return FocusSessionResult.started;
    } catch (e) {
      _handleError(e);
      return FocusSessionResult.error;
    }
  }

  /// End the current focus session
  Future<bool> endFocusSession() async {
    if (_currentSession == null) return false;

    try {
      await _screenTimeService.endFocusSession(_currentSession!.sessionId);

      _currentSession = null;
      _activeRules = [];
      _sessionState = FocusSessionState.inactive;
      notifyListeners();

      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  /// Manually override current restrictions
  Future<OverrideResult> manualOverride() async {
    try {
      final response = await _screenTimeService.manualOverride();

      if (response.overrideGranted) {
        _sessionState = FocusSessionState.overridden;
        notifyListeners();
        return OverrideResult.granted;
      } else {
        return OverrideResult.denied;
      }
    } catch (e) {
      _handleError(e);
      return OverrideResult.error;
    }
  }

  /// Emergency disable all Screen Time features
  Future<bool> emergencyDisable() async {
    try {
      await _screenTimeService.disableAllRestrictions();

      _currentSession = null;
      _activeRules = [];
      _sessionState = FocusSessionState.inactive;
      notifyListeners();

      return true;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  /// Present Apple's Family Activity Picker for app/category selection
  Future<FamilySelectionResult?> presentAppPicker() async {
    try {
      // ❗ KEINE Authorization-Logik mehr hier - wird vom Caller gemacht
      final result = await _screenTimeService.presentFamilyActivityPicker();
      _clearError();
      return result;
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  /// Get usage statistics
  Future<ScreenTimeStatsDTO?> getUsageStats(String period) async {
    try {
      final response = await _screenTimeService.getAggregatedStats(period);
      return response.stats;
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  // MARK: - State Getters

  FocusSessionState get sessionState => _sessionState;
  AuthorizationStatus get authorizationStatus => _authStatus;
  FocusSessionResponse? get currentSession => _currentSession;
  List<BlockingRuleDTO> get activeRules => _activeRules;
  bool get hasError => _lastError != null;
  String? get errorMessage => _errorMessage;

  bool get isAuthorized => _authStatus == AuthorizationStatus.authorized;
  bool get canRequestPermission =>
      _authStatus == AuthorizationStatus.notDetermined ||
      _authStatus == AuthorizationStatus.denied;
  bool get hasActiveSession => _sessionState == FocusSessionState.active;

  // MARK: - Private Methods

  Future<void> _checkAuthorizationStatus() async {
    try {
      final response = await _screenTimeService.getAuthorizationStatus();
      _authStatus = response.status;
    } catch (e) {
      _handleError(e);
      _authStatus = AuthorizationStatus.notDetermined;
    }
  }

  void _handleError(dynamic error) {
    if (error is ScreenTimeException) {
      _lastError = error.code;
      _errorMessage = error.message;
    } else {
      _lastError = ScreenTimeError.unknown;
      _errorMessage = 'An unexpected error occurred';
    }

    if (kDebugMode) {
      print('FocusModeService error: $_errorMessage');
    }

    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
    _errorMessage = null;
    notifyListeners();
  }
}

// MARK: - Enums and Types

/// Focus session states
enum FocusSessionState {
  inactive, // No active session
  active, // Session running with blocking active
  overridden // Session paused due to manual override
}

/// Authorization results
enum AuthorizationResult {
  granted, // Permission granted
  denied, // User denied permission
  restricted, // System restriction (can't request)
  error // Error during request
}

/// Focus session results
enum FocusSessionResult {
  started, // Session started successfully
  noPermission, // Screen Time not authorized
  configurationFailed, // Failed to configure blocking rules
  tokensInvalid, // Selected apps/categories are no longer available
  error // Unexpected error
}

/// Manual override results
enum OverrideResult {
  granted, // Override allowed
  denied, // Override denied
  error // Error during override
}
