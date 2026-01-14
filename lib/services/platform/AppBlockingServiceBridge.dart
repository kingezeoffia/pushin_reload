import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter bridge to native Android AppBlockingService.
///
/// This service manages the native foreground service that:
/// - Monitors for blocked app launches in the background
/// - Shows a system overlay when blocked apps are detected
/// - Handles emergency unlock functionality
///
/// The native service continues running even when the Flutter app is in background.
class AppBlockingServiceBridge {
  static const MethodChannel _channel =
      MethodChannel('com.pushin.blockingservice');
  static const EventChannel _eventChannel =
      EventChannel('com.pushin.blockingevents');

  static AppBlockingServiceBridge? _instance;
  static AppBlockingServiceBridge get instance {
    _instance ??= AppBlockingServiceBridge._();
    return _instance!;
  }

  AppBlockingServiceBridge._();

  StreamSubscription? _eventSubscription;
  final StreamController<BlockingServiceEvent> _eventController =
      StreamController<BlockingServiceEvent>.broadcast();

  /// Stream of events from the blocking service
  Stream<BlockingServiceEvent> get events => _eventController.stream;

  /// Whether the blocking service is supported on this platform
  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Initialize the service bridge and start listening for events
  Future<void> initialize() async {
    if (!isSupported) {
      print('AppBlockingServiceBridge: Not supported on this platform');
      return;
    }

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final eventType = event['event'] as String?;
          final blockedApp = event['blocked_app'] as String?;

          switch (eventType) {
            case 'emergency_unlock_used':
              final durationMinutes = event['duration_minutes'] as int? ?? 5;
              _eventController.add(EmergencyUnlockUsedEvent(
                blockedApp: blockedApp ?? '',
                durationMinutes: durationMinutes,
              ));
              break;
            case 'blocked_app_detected':
              _eventController.add(BlockedAppDetectedEvent(
                blockedApp: blockedApp ?? '',
              ));
              break;
          }
        }
      },
      onError: (error) {
        print('AppBlockingServiceBridge: Event stream error: $error');
      },
    );

    print('AppBlockingServiceBridge: Initialized');
  }

  /// Check if the system overlay permission is granted
  Future<bool> hasOverlayPermission() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check overlay permission: ${e.message}');
      return false;
    }
  }

  /// Request the system overlay permission
  /// Opens Android settings for the user to grant permission
  Future<void> requestOverlayPermission() async {
    if (!isSupported) return;

    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      print('Failed to request overlay permission: ${e.message}');
    }
  }

  /// Start the background blocking service
  Future<bool> startService() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('startBlockingService');
      print('AppBlockingServiceBridge: Service started: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to start blocking service: ${e.message}');
      return false;
    }
  }

  /// Stop the background blocking service
  Future<bool> stopService() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('stopBlockingService');
      print('AppBlockingServiceBridge: Service stopped: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to stop blocking service: ${e.message}');
      return false;
    }
  }

  /// Check if the blocking service is currently running
  Future<bool> isServiceRunning() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isServiceRunning');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check service status: ${e.message}');
      return false;
    }
  }

  /// Update the list of blocked apps in the native service
  Future<bool> updateBlockedApps(List<String> apps) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'updateBlockedApps',
        {'apps': apps},
      );
      print('AppBlockingServiceBridge: Updated blocked apps: $apps');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to update blocked apps: ${e.message}');
      return false;
    }
  }

  /// Set the service to unlocked state (don't block apps)
  /// This is called when user completes a workout and earns screen time
  Future<bool> setUnlocked(int durationSeconds) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'setUnlocked',
        {'duration_seconds': durationSeconds},
      );
      print('AppBlockingServiceBridge: Set unlocked for $durationSeconds seconds');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set unlocked: ${e.message}');
      return false;
    }
  }

  /// Set the service to locked state (block apps)
  /// This is called when the earned time expires
  Future<bool> setLocked() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('setLocked');
      print('AppBlockingServiceBridge: Set locked');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set locked: ${e.message}');
      return false;
    }
  }

  /// Activate emergency unlock in the native service
  Future<bool> activateEmergencyUnlock(int durationMinutes) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>(
        'activateEmergencyUnlock',
        {'duration_minutes': durationMinutes},
      );
      print('AppBlockingServiceBridge: Emergency unlock for $durationMinutes min');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to activate emergency unlock: ${e.message}');
      return false;
    }
  }

  /// Dismiss the native overlay
  Future<bool> dismissOverlay() async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<bool>('dismissOverlay');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to dismiss overlay: ${e.message}');
      return false;
    }
  }

  /// Dispose of resources
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
  }
}

/// Base class for blocking service events
abstract class BlockingServiceEvent {}

/// Event fired when emergency unlock is used from native overlay
class EmergencyUnlockUsedEvent extends BlockingServiceEvent {
  final String blockedApp;
  final int durationMinutes;

  EmergencyUnlockUsedEvent({
    required this.blockedApp,
    required this.durationMinutes,
  });
}

/// Event fired when a blocked app is detected
class BlockedAppDetectedEvent extends BlockingServiceEvent {
  final String blockedApp;

  BlockedAppDetectedEvent({required this.blockedApp});
}
