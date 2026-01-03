import 'dart:async';
import 'package:flutter/services.dart';

/// PUSHIN Screen Time Service
///
/// Implements the Flutter platform channel contract for Screen Time APIs.
/// Provides a clean Dart API for voluntary self-control features.
///
/// Key Behaviors:
/// - Authorization via FamilyControls (individual use only)
/// - Blocking via ManagedSettingsStore (shield.applications)
/// - Monitoring via DeviceActivity (with extension for reporting)
/// - All operations are user-initiated and easily reversible
class ScreenTimeService {
  static const MethodChannel _channel = MethodChannel('dev.pushin.screentime');

  // MARK: - Authorization

  /// Get current Screen Time authorization status
  Future<AuthorizationStatusResponse> getAuthorizationStatus() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAuthorizationStatus');

      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<dynamic, dynamic>;
        return AuthorizationStatusResponse(
          status: _parseAuthorizationStatus(data['status'] as String),
          canRequest: data['canRequest'] as bool,
        );
      } else {
        throw ScreenTimeException.fromPlatformResponse(result);
      }
    } on PlatformException catch (e) {
      throw ScreenTimeException.fromPlatformException(e);
    }
  }

  /// Request Screen Time authorization with user explanation
  Future<AuthorizationStatusResponse> requestAuthorization(String explanation) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestAuthorization', {
        'explanation': explanation,
      });

      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<dynamic, dynamic>;
        return AuthorizationStatusResponse(
          status: _parseAuthorizationStatus(data['status'] as String),
          canRequest: data['canRequest'] as bool,
        );
      } else {
        throw ScreenTimeException.fromPlatformResponse(result);
      }
    } on PlatformException catch (e) {
      throw ScreenTimeException.fromPlatformException(e);
    }
  }

  // MARK: - Blocking Rules Configuration

  /// Configure blocking rules using activity tokens
  Future<ConfigureRulesResponse> configureBlockingRules(List<BlockingRuleDTO> rules) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('configureBlockingRules', {
        'rules': rules.map((rule) => rule.toJson()).toList(),
      });

      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<dynamic, dynamic>;
        return ConfigureRulesResponse(
          configuredRules: data['configuredRules'] as int,
          failedRules: List<String>.from(data['failedRules'] as List),
          invalidTokens: List<String>.from(data['invalidTokens'] ?? []),
        );
      } else {
        throw ScreenTimeException.fromPlatformResponse(result);
      }
    } on PlatformException catch (e) {
      throw ScreenTimeException.fromPlatformException(e);
    }
  }

  // MARK: - Focus Sessions

  /// Start a focus session with scheduled blocking
  Future<FocusSessionResponse> startFocusSession({
    required String sessionId,
    required int durationMinutes,
    required List<String> ruleIds,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('startFocusSession', {
        'sessionId': sessionId,
        'durationMinutes': durationMinutes,
        'ruleIds': ruleIds,
      });

      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<dynamic, dynamic>;
        return FocusSessionResponse(
          sessionId: data['sessionId'] as String,
          startTime: DateTime.parse(data['startTime'] as String),
          endTime: DateTime.parse(data['endTime'] as String),
          activeRuleIds: List<String>.from(data['activeRuleIds'] as List),
        );
      } else {
        throw ScreenTimeException.fromPlatformResponse(result);
      }
    } on PlatformException catch (e) {
      throw ScreenTimeException.fromPlatformException(e);
    }
  }

  /// End an active focus session
  Future<void> endFocusSession(String sessionId) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('endFocusSession', {
        'sessionId': sessionId,
      });

      if (result == null || result['success'] != true) {
        throw ScreenTimeException.fromPlatformResponse(result);
      }
    } on PlatformException catch (e) {
      throw ScreenTimeException.fromPlatformException(e);
    }
  }

  // MARK: - Manual Override & Emergency Controls

  /// Allow manual override of current restrictions
  Future<ManualOverrideResponse> manualOverride() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('manualOverride');

      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<dynamic, dynamic>;
        return ManualOverrideResponse(
          overrideGranted: data['overrideGranted'] as bool,
          expiresAt: data['expiresAt'] != null ? DateTime.parse(data['expiresAt'] as String) : null,
        );
      } else {
        throw ScreenTimeException.fromPlatformResponse(result);
      }
    } on PlatformException catch (e) {
      throw ScreenTimeException.fromPlatformException(e);
    }
  }

  /// Emergency disable of all Screen Time features
  Future<void> disableAllRestrictions() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('disableAllRestrictions');

      if (result == null || result['success'] != true) {
        throw ScreenTimeException.fromPlatformResponse(result);
      }
    } on PlatformException catch (e) {
      throw ScreenTimeException.fromPlatformException(e);
    }
  }

  // MARK: - Family Activity Picker

  /// Present Apple's Family Activity Picker for app/category selection
  Future<FamilySelectionResult> presentFamilyActivityPicker() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('presentFamilyActivityPicker');

      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<dynamic, dynamic>;
        return FamilySelectionResult(
          appTokens: List<String>.from(data['applications']),
          categoryTokens: List<String>.from(data['categories']),
          totalSelected: data['totalSelected'] as int,
        );
      } else {
        throw ScreenTimeException.fromPlatformResponse(result);
      }
    } on PlatformException catch (e) {
      throw ScreenTimeException.fromPlatformException(e);
    }
  }

  // MARK: - Aggregated Statistics

  /// Get aggregated Screen Time statistics
  Future<AggregatedStatsResponse> getAggregatedStats(String period) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAggregatedStats', {
        'period': period,
      });

      if (result != null && result['success'] == true) {
        final data = result['data'] as Map<dynamic, dynamic>;
        return AggregatedStatsResponse(
          extensionTriggered: data['extensionTriggered'] as bool,
          dataAvailable: data['dataAvailable'] as bool,
          lastUpdate: data['lastUpdate'] != null ? DateTime.parse(data['lastUpdate'] as String) : null,
          stats: data['stats'] != null ? ScreenTimeStatsDTO.fromJson(Map<String, dynamic>.from(data['stats'] as Map)) : null,
          nextScheduledRun: data['nextScheduledRun'] != null ? DateTime.parse(data['nextScheduledRun'] as String) : null,
        );
      } else {
        throw ScreenTimeException.fromPlatformResponse(result);
      }
    } on PlatformException catch (e) {
      throw ScreenTimeException.fromPlatformException(e);
    }
  }

  // MARK: - Private Helpers

  AuthorizationStatus _parseAuthorizationStatus(String status) {
    switch (status) {
      case 'authorized':
        return AuthorizationStatus.authorized;
      case 'denied':
        return AuthorizationStatus.denied;
      case 'notDetermined':
        return AuthorizationStatus.notDetermined;
      case 'restricted':
        return AuthorizationStatus.restricted;
      default:
        return AuthorizationStatus.notDetermined;
    }
  }
}

// MARK: - DTO Classes

/// Authorization status response
class AuthorizationStatusResponse {
  final AuthorizationStatus status;
  final bool canRequest;

  AuthorizationStatusResponse({
    required this.status,
    required this.canRequest,
  });
}

/// Blocking rule DTO
class BlockingRuleDTO {
  final String id;
  final BlockingRuleType type;
  final List<String> activityTokens;
  final ScheduleConfigDTO? schedule;
  final DurationConfigDTO? duration;
  final bool allowOverride;
  final String? name;

  BlockingRuleDTO({
    required this.id,
    required this.type,
    required this.activityTokens,
    this.schedule,
    this.duration,
    this.allowOverride = true,
    this.name,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'activityTokens': activityTokens,
    'schedule': schedule?.toJson(),
    'duration': duration?.toJson(),
    'allowOverride': allowOverride,
    'name': name,
  };

  factory BlockingRuleDTO.fromJson(Map<String, dynamic> json) => BlockingRuleDTO(
    id: json['id'],
    type: BlockingRuleType.values.firstWhere((e) => e.name == json['type']),
    activityTokens: List<String>.from(json['activityTokens']),
    schedule: json['schedule'] != null ? ScheduleConfigDTO.fromJson(json['schedule']) : null,
    duration: json['duration'] != null ? DurationConfigDTO.fromJson(json['duration']) : null,
    allowOverride: json['allowOverride'] ?? true,
    name: json['name'],
  );
}

/// Schedule configuration DTO
class ScheduleConfigDTO {
  final List<int> weekdays;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool repeatWeekly;

  ScheduleConfigDTO({
    required this.weekdays,
    required this.startTime,
    required this.endTime,
    this.repeatWeekly = true,
  });

  Map<String, dynamic> toJson() => {
    'weekdays': weekdays,
    'startTime': '${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}',
    'endTime': '${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}',
    'repeatWeekly': repeatWeekly,
  };

  factory ScheduleConfigDTO.fromJson(Map<String, dynamic> json) => ScheduleConfigDTO(
    weekdays: List<int>.from(json['weekdays']),
    startTime: _parseTime(json['startTime']),
    endTime: _parseTime(json['endTime']),
    repeatWeekly: json['repeatWeekly'] ?? true,
  );

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

/// Duration configuration DTO
class DurationConfigDTO {
  final int minutes;
  final bool allowExtension;

  DurationConfigDTO({
    required this.minutes,
    this.allowExtension = false,
  });

  Map<String, dynamic> toJson() => {
    'minutes': minutes,
    'allowExtension': allowExtension,
  };

  factory DurationConfigDTO.fromJson(Map<String, dynamic> json) => DurationConfigDTO(
    minutes: json['minutes'],
    allowExtension: json['allowExtension'] ?? false,
  );
}

/// Time of day (since Flutter doesn't have built-in TimeOfDay in foundation)
class TimeOfDay {
  final int hour;
  final int minute;

  TimeOfDay({required this.hour, required this.minute});
}

/// Blocking rule types
enum BlockingRuleType {
  scheduled,
  focusSession,
  category,
  application,
}

/// Authorization statuses
enum AuthorizationStatus {
  notDetermined,
  authorized,
  denied,
  restricted,
}

// MARK: - Response Classes

/// Family Activity Picker result
class FamilySelectionResult {
  final List<String> appTokens;
  final List<String> categoryTokens;
  final int totalSelected;

  FamilySelectionResult({
    required this.appTokens,
    required this.categoryTokens,
    required this.totalSelected,
  });

  bool get hasSelection => totalSelected > 0;
}

/// Configure rules response
class ConfigureRulesResponse {
  final int configuredRules;
  final List<String> failedRules;
  final List<String> invalidTokens;

  ConfigureRulesResponse({
    required this.configuredRules,
    required this.failedRules,
    required this.invalidTokens,
  });

  bool get hasInvalidTokens => invalidTokens.isNotEmpty;
}

/// Focus session response
class FocusSessionResponse {
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> activeRuleIds;

  FocusSessionResponse({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.activeRuleIds,
  });
}

/// Manual override response
class ManualOverrideResponse {
  final bool overrideGranted;
  final DateTime? expiresAt;

  ManualOverrideResponse({
    required this.overrideGranted,
    this.expiresAt,
  });
}

/// Aggregated stats response
class AggregatedStatsResponse {
  final bool extensionTriggered;
  final bool dataAvailable;
  final DateTime? lastUpdate;
  final ScreenTimeStatsDTO? stats;
  final DateTime? nextScheduledRun;

  AggregatedStatsResponse({
    required this.extensionTriggered,
    required this.dataAvailable,
    this.lastUpdate,
    this.stats,
    this.nextScheduledRun,
  });
}

/// Screen Time stats DTO
class ScreenTimeStatsDTO {
  final int totalBlockedMinutes;
  final int sessionsCompleted;
  final int totalSessionsStarted;
  final String? mostBlockedCategory;
  final double averageSessionLengthMinutes;
  final Map<String, int> categoryBreakdown;
  final DateTime periodStart;
  final DateTime periodEnd;

  ScreenTimeStatsDTO({
    required this.totalBlockedMinutes,
    required this.sessionsCompleted,
    required this.totalSessionsStarted,
    this.mostBlockedCategory,
    required this.averageSessionLengthMinutes,
    required this.categoryBreakdown,
    required this.periodStart,
    required this.periodEnd,
  });

  factory ScreenTimeStatsDTO.fromJson(Map<String, dynamic> json) => ScreenTimeStatsDTO(
    totalBlockedMinutes: json['totalBlockedMinutes'],
    sessionsCompleted: json['sessionsCompleted'],
    totalSessionsStarted: json['totalSessionsStarted'],
    mostBlockedCategory: json['mostBlockedCategory'],
    averageSessionLengthMinutes: json['averageSessionLengthMinutes'],
    categoryBreakdown: Map<String, int>.from(json['categoryBreakdown']),
    periodStart: DateTime.parse(json['periodStart']),
    periodEnd: DateTime.parse(json['periodEnd']),
  );
}

// MARK: - Exception Handling

/// Screen Time specific exceptions
class ScreenTimeException implements Exception {
  final ScreenTimeError code;
  final String message;
  final String? recoverySuggestion;

  ScreenTimeException(this.code, this.message, {this.recoverySuggestion});

  static ScreenTimeException fromPlatformResponse(Map<dynamic, dynamic>? response) {
    if (response == null || response['success'] == true) {
      return ScreenTimeException(ScreenTimeError.unknown, 'Unknown error');
    }

    final errorCode = response['errorCode'] as String?;
    final errorMessage = response['errorMessage'] as String? ?? 'Unknown error';

    final code = _parseErrorCode(errorCode ?? 'UNKNOWN');
    return ScreenTimeException(code, errorMessage);
  }

  static ScreenTimeException fromPlatformException(PlatformException e) {
    final code = _parseErrorCode(e.code);
    return ScreenTimeException(code, e.message ?? 'Platform error');
  }

  static ScreenTimeError _parseErrorCode(String code) {
    switch (code) {
      case 'NOT_AUTHORIZED':
        return ScreenTimeError.notAuthorized;
      case 'AUTH_ERROR':
        return ScreenTimeError.authorizationError;
      case 'CONFIG_ERROR':
        return ScreenTimeError.configurationError;
      case 'SESSION_ERROR':
        return ScreenTimeError.sessionError;
      case 'SESSION_NOT_FOUND':
        return ScreenTimeError.sessionNotFound;
      case 'EXTENSION_ERROR':
        return ScreenTimeError.extensionError;
      default:
        return ScreenTimeError.unknown;
    }
  }
}

/// Screen Time error codes
enum ScreenTimeError {
  notAuthorized,
  authorizationError,
  configurationError,
  sessionError,
  sessionNotFound,
  extensionError,
  unknown,
}