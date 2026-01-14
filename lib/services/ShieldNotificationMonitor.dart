import 'dart:async';
import 'package:flutter/foundation.dart';
import 'NotificationService.dart';
import 'platform/ScreenTimeMonitor.dart';

/// Shield Notification Monitor
///
/// Monitors for shield actions and shows workout reminder notifications.
/// Uses Flutter-based notification system for cross-platform compatibility.
class ShieldNotificationMonitor {
  static final ShieldNotificationMonitor _instance = ShieldNotificationMonitor._internal();
  factory ShieldNotificationMonitor() => _instance;

  ShieldNotificationMonitor._internal();

  final ScreenTimeService _screenTimeService = ScreenTimeService();
  final NotificationService _notificationService = NotificationService();

  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  /// Initialize the shield notification monitor
  Future<void> initialize() async {
    await _notificationService.initialize();

    // Check permissions
    final enabled = await _notificationService.areNotificationsEnabled();
    if (!enabled) {
      debugPrint('⚠️ Notifications are not enabled - user needs to grant permissions');
    } else {
      debugPrint('✅ Notification permissions granted');
    }

    // Check immediately for any pending notifications from shield actions
    await _checkForPendingNotifications();

    debugPrint('✅ Shield notification monitor initialized');
  }

  /// Start monitoring for shield actions
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    debugPrint('👀 Started monitoring shield actions');

    // Check immediately for any pending actions
    _checkForPendingNotifications();

    // Set up periodic monitoring (every 2 seconds when app is active)
    _monitoringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkForPendingNotifications();
    });
  }

  /// Stop monitoring for shield actions
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    debugPrint('⏹️ Stopped monitoring shield actions');
  }

  /// Check for pending notifications from shield actions
  Future<void> _checkForPendingNotifications() async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      debugPrint('🔍 [$timestamp] Checking for pending workout notifications...');

      final response = await _screenTimeService.checkPendingWorkoutNotification();

      debugPrint('📊 Shield notification check result:');
      debugPrint('   - hasPending: ${response.hasPendingNotification}');
      debugPrint('   - expired: ${response.expired}');
      debugPrint('   - alreadyShown: ${response.alreadyShown}');
      debugPrint('   - notificationId: ${response.notificationId}');

      if (response.hasPendingNotification &&
          response.notificationId != null &&
          !response.expired &&
          !response.alreadyShown) {

        debugPrint('📱 Found valid pending notification: ${response.notificationId}');
        debugPrint('🏋️ Navigating directly to workout screen (skipping notification)');

        // Mark as processed
        await _screenTimeService.markNotificationShown(response.notificationId!);

        // Trigger navigation to workout screen directly
        _navigateToWorkoutScreen();

        debugPrint('✅ Notification shown and marked as processed');
      } else {
        debugPrint('ℹ️ No valid pending notification to show');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking pending notifications: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Show workout reminder notification
  Future<void> _showWorkoutNotification(String notificationId) async {
    try {
      await _notificationService.showWorkoutReminder(
        title: 'Earn Screen Time',
        body: 'Complete a quick workout to unblock your apps',
        badgeNumber: null, // Let system handle badge
      );

      debugPrint('✅ Workout notification shown for: $notificationId');
    } catch (e) {
      debugPrint('❌ Failed to show workout notification: $e');
    }
  }

  /// Handle notification action (called from notification service)
  void handleNotificationAction(String actionId) {
    debugPrint('📱 Handling notification action: $actionId');

    switch (actionId) {
      case 'start_workout':
        _navigateToWorkoutScreen();
        break;
      case 'later':
        // Just dismiss - no action needed
        debugPrint('⏰ User selected "Later"');
        break;
      default:
        // Default action - navigate to workout
        _navigateToWorkoutScreen();
        break;
    }
  }

  /// Navigate to workout selection screen
  void _navigateToWorkoutScreen() {
    debugPrint('🧭 Navigating to workout screen');
    // This will be handled by the app's navigation system
    // We'll emit an event that the app can listen to
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    return await _notificationService.areNotificationsEnabled();
  }

  /// Cancel all pending notifications
  Future<void> cancelAllNotifications() async {
    await _notificationService.cancelAllNotifications();
  }

  /// Get monitoring status
  bool get isMonitoring => _isMonitoring;

  /// Manually trigger a notification check (for debugging)
  Future<void> manualCheckForNotifications() async {
    debugPrint('🔧 Manual notification check triggered');
    await _checkForPendingNotifications();
  }

  /// Test notification system (for debugging)
  Future<void> testNotificationSystem() async {
    debugPrint('🧪 Testing notification system...');

    // Check permissions
    final enabled = await _notificationService.areNotificationsEnabled();
    debugPrint('   ✓ Permissions enabled: $enabled');

    // Try to show a test notification
    try {
      await _notificationService.showWorkoutReminder(
        title: 'Test Notification',
        body: 'This is a test from PUSHIN notification system',
      );
      debugPrint('   ✓ Test notification sent successfully');
    } catch (e) {
      debugPrint('   ✗ Test notification failed: $e');
    }

    // Check for pending notifications from shield
    final response = await _screenTimeService.checkPendingWorkoutNotification();
    debugPrint('   ✓ Pending notification status: ${response.hasPendingNotification}');

    debugPrint('🧪 Test complete');
  }
}