import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/AppBlockTarget.dart';

/// iOS Screen Time monitoring service with graceful fallback.
///
/// Reality Check (from Architecture Review):
/// - FamilyControls API requires Family Sharing OR device supervision (MDM)
/// - Most consumer users DON'T have Family Sharing enabled
/// - Cannot guarantee system-level blocking for all devices
///
/// Strategy:
/// - Attempt to use Screen Time APIs when available
/// - Fall back to UX-based blocking (overlay) when APIs unavailable
/// - Track app usage via DeviceActivity framework
/// - Show AppBlockOverlay when blocked app launched
///
/// Platform Channel Communication:
/// - Uses method channel to communicate with native iOS code
/// - Native module handles FamilyControls, ManagedSettings, DeviceActivity
/// - Returns capability status (blocking_available, monitoring_only, unavailable)
class ScreenTimeMonitor {
  static const MethodChannel _channel =
      MethodChannel('com.pushin.screentime');

  ScreenTimeCapability _capability = ScreenTimeCapability.unknown;
  final StreamController<AppLaunchEvent> _appLaunchController =
      StreamController<AppLaunchEvent>.broadcast();

  /// Stream of app launch events (for triggering block overlay)
  Stream<AppLaunchEvent> get appLaunchEvents => _appLaunchController.stream;

  /// Current Screen Time API capability
  ScreenTimeCapability get capability => _capability;

  /// Initialize Screen Time monitoring.
  ///
  /// Steps:
  /// 1. Check if FamilyControls framework is available
  /// 2. Request authorization if needed
  /// 3. Determine capability level
  /// 4. Start monitoring if possible
  Future<ScreenTimeCapability> initialize() async {
    try {
      final result = await _channel.invokeMethod<Map>('initialize');
      
      if (result != null) {
        _capability = _parseCapability(result['capability'] as String?);
        
        // Start app usage monitoring if available
        if (_capability != ScreenTimeCapability.unavailable) {
          await _startMonitoring();
        }
      } else {
        _capability = ScreenTimeCapability.unavailable;
      }
    } on PlatformException catch (e) {
      print('ScreenTime initialization failed: ${e.message}');
      _capability = ScreenTimeCapability.unavailable;
    }

    return _capability;
  }

  /// Request Screen Time authorization from user.
  ///
  /// Shows system prompt: "PUSHIN would like to manage Screen Time"
  /// Returns true if granted, false if denied
  Future<bool> requestAuthorization() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestAuthorization');
      return granted ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Set list of apps to block/monitor.
  ///
  /// Behavior depends on capability:
  /// - blocking_available: Applies ManagedSettings shield
  /// - monitoring_only: Only tracks launches, no system block
  /// - unavailable: No-op, relies on UX overlay only
  Future<void> setBlockedApps(List<AppBlockTarget> apps) async {
    if (_capability == ScreenTimeCapability.unavailable) {
      // UX-based blocking only, no Screen Time integration
      return;
    }

    try {
      final appBundleIds = apps.map((app) => app.platformAgnosticIdentifier).toList();
      await _channel.invokeMethod('setBlockedApps', {
        'bundleIds': appBundleIds,
      });
    } on PlatformException catch (e) {
      print('Failed to set blocked apps: ${e.message}');
    }
  }

  /// Start monitoring app usage.
  ///
  /// Sets up DeviceActivity monitoring to detect app launches
  /// Emits events to appLaunchEvents stream
  Future<void> _startMonitoring() async {
    try {
      // Set up event handler for app launches
      _channel.setMethodCallHandler(_handleMethodCall);
      
      await _channel.invokeMethod('startMonitoring');
    } on PlatformException catch (e) {
      print('Failed to start monitoring: ${e.message}');
    }
  }

  /// Handle method calls from native iOS code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAppLaunched':
        final bundleId = call.arguments['bundleId'] as String?;
        final appName = call.arguments['appName'] as String?;
        
        if (bundleId != null && appName != null) {
          _appLaunchController.add(AppLaunchEvent(
            bundleId: bundleId,
            appName: appName,
            timestamp: DateTime.now(),
          ));
        }
        break;
      
      case 'onCapabilityChanged':
        final newCapability = _parseCapability(
          call.arguments['capability'] as String?,
        );
        _capability = newCapability;
        break;
    }
  }

  /// Stop monitoring (cleanup)
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
    } catch (e) {
      // Ignore errors during cleanup
    }
    
    await _appLaunchController.close();
  }

  /// Parse capability string from native code
  ScreenTimeCapability _parseCapability(String? capability) {
    switch (capability?.toLowerCase()) {
      case 'blocking_available':
        return ScreenTimeCapability.blockingAvailable;
      case 'monitoring_only':
        return ScreenTimeCapability.monitoringOnly;
      case 'unavailable':
      default:
        return ScreenTimeCapability.unavailable;
    }
  }

  /// Get installed apps (for block selection UI)
  ///
  /// Uses FamilyActivityPicker on iOS 15+
  /// Returns list of installed apps with bundle IDs
  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod<List>('getInstalledApps');
      
      if (result != null) {
        return result.map((app) {
          return InstalledApp(
            bundleId: app['bundleId'] as String,
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
}

/// Screen Time API capability levels
enum ScreenTimeCapability {
  /// Unknown state (not initialized yet)
  unknown,
  
  /// Full blocking available (Family Sharing or MDM enabled)
  blockingAvailable,
  
  /// Can monitor app usage, but cannot enforce system blocks
  /// Falls back to UX overlay
  monitoringOnly,
  
  /// Screen Time APIs not available (iOS < 15, permission denied)
  /// Fully UX-based blocking
  unavailable,
}

/// App launch event (emitted when user opens a blocked app)
class AppLaunchEvent {
  final String bundleId;
  final String appName;
  final DateTime timestamp;

  AppLaunchEvent({
    required this.bundleId,
    required this.appName,
    required this.timestamp,
  });
}

/// Installed app info (for block selection UI)
class InstalledApp {
  final String bundleId;
  final String name;
  final String? iconData; // Base64 encoded image

  InstalledApp({
    required this.bundleId,
    required this.name,
    this.iconData,
  });
}

