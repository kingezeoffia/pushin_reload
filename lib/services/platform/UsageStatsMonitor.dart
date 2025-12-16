import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/AppBlockTarget.dart';

/// Android Usage Stats monitoring service with safe overlay-based blocking.
///
/// Reality Check:
/// - UsageStatsManager provides app usage data, NOT blocking
/// - Accessibility Service would allow blocking but often rejected by Play Store
/// - Safe approach: Detect app launches → Show full-screen overlay
///
/// Strategy:
/// - Request PACKAGE_USAGE_STATS permission
/// - Poll UsageStats API to detect foreground app changes
/// - When blocked app launched → Emit event to show AppBlockOverlay
/// - User must navigate away or start workout to dismiss
///
/// Platform Channel Communication:
/// - Uses method channel to communicate with native Android code
/// - Native module handles UsageStatsManager queries
/// - No Accessibility Service abuse (Play Store compliant)
class UsageStatsMonitor {
  static const MethodChannel _channel =
      MethodChannel('com.pushin.usagestats');

  final StreamController<AppLaunchEvent> _appLaunchController =
      StreamController<AppLaunchEvent>.broadcast();
  
  Timer? _pollingTimer;
  String? _currentForegroundApp;
  Set<String> _blockedAppIds = {};

  /// Stream of app launch events (for triggering block overlay)
  Stream<AppLaunchEvent> get appLaunchEvents => _appLaunchController.stream;

  /// Initialize Usage Stats monitoring.
  ///
  /// Steps:
  /// 1. Check if PACKAGE_USAGE_STATS permission granted
  /// 2. Request permission if needed (opens Settings)
  /// 3. Start polling foreground app
  Future<bool> initialize() async {
    try {
      final hasPermission = await _channel.invokeMethod<bool>(
        'hasUsageStatsPermission',
      );

      if (hasPermission == true) {
        await _startMonitoring();
        return true;
      } else {
        return false;
      }
    } on PlatformException catch (e) {
      print('UsageStats initialization failed: ${e.message}');
      return false;
    }
  }

  /// Request Usage Stats permission.
  ///
  /// Opens Android Settings > Apps > Special Access > Usage Access
  /// Returns true if permission granted after user returns
  Future<bool> requestPermission() async {
    try {
      // Opens system settings
      await _channel.invokeMethod('requestUsageStatsPermission');
      
      // Wait a bit for user to grant permission
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Check if permission was granted
      final hasPermission = await _channel.invokeMethod<bool>(
        'hasUsageStatsPermission',
      );
      
      if (hasPermission == true) {
        await _startMonitoring();
        return true;
      }
      
      return false;
    } on PlatformException catch (e) {
      print('Failed to request permission: ${e.message}');
      return false;
    }
  }

  /// Set list of apps to monitor/block.
  ///
  /// Stores package names to watch for in foreground detection
  Future<void> setBlockedApps(List<AppBlockTarget> apps) async {
    _blockedAppIds = apps.map((app) => app.platformAgnosticIdentifier).toSet();
  }

  /// Start polling foreground app.
  ///
  /// Polls every 1 second to detect app changes
  /// When blocked app detected → Emit launch event
  Future<void> _startMonitoring() async {
    // Cancel existing timer if any
    _pollingTimer?.cancel();
    
    // Poll every 1 second
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkForegroundApp(),
    );
  }

  /// Check current foreground app
  Future<void> _checkForegroundApp() async {
    try {
      final result = await _channel.invokeMethod<Map>('getForegroundApp');
      
      if (result != null) {
        final packageName = result['packageName'] as String?;
        final appName = result['appName'] as String?;
        
        if (packageName != null && appName != null) {
          // Detect app change
          if (packageName != _currentForegroundApp) {
            _currentForegroundApp = packageName;
            
            // Check if this is a blocked app
            if (_blockedAppIds.contains(packageName)) {
              _appLaunchController.add(AppLaunchEvent(
                packageName: packageName,
                appName: appName,
                timestamp: DateTime.now(),
              ));
            }
          }
        }
      }
    } on PlatformException catch (e) {
      print('Failed to check foreground app: ${e.message}');
    }
  }

  /// Stop monitoring (cleanup)
  Future<void> dispose() async {
    _pollingTimer?.cancel();
    await _appLaunchController.close();
  }

  /// Get installed apps (for block selection UI)
  ///
  /// Queries PackageManager for installed apps
  /// Filters out system apps (only user-installed apps)
  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List>('getInstalledApps');
      
      if (result != null) {
        return result.map((app) {
          return InstalledApp(
            packageName: app['packageName'] as String,
            name: app['name'] as String,
            iconData: app['iconData'] as String?, // Base64 encoded
          );
        }).toList();
      }
    } on PlatformException catch (e) {
      print('Failed to get installed apps: ${e.message}');
    }

    return [];
  }

  /// Get app usage stats for today (analytics)
  ///
  /// Returns map of package name → usage time in seconds
  Future<Map<String, int>> getTodayUsageStats() async {
    try {
      final result = await _channel.invokeMethod<Map>('getTodayUsageStats');
      
      if (result != null) {
        return result.map((key, value) {
          return MapEntry(key as String, value as int);
        });
      }
    } on PlatformException catch (e) {
      print('Failed to get usage stats: ${e.message}');
    }

    return {};
  }
}

/// App launch event (emitted when user opens a blocked app)
class AppLaunchEvent {
  final String packageName;
  final String appName;
  final DateTime timestamp;

  AppLaunchEvent({
    required this.packageName,
    required this.appName,
    required this.timestamp,
  });
}

/// Installed app info (for block selection UI)
class InstalledApp {
  final String packageName;
  final String name;
  final String? iconData; // Base64 encoded image

  InstalledApp({
    required this.packageName,
    required this.name,
    this.iconData,
  });
}

