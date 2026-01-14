import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// PUSHIN Notification Service
///
/// Handles local notifications for Screen Time shield workout reminders.
/// Uses flutter_local_notifications for cross-platform compatibility.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'workout_reminder';
  static const String _channelName = 'Workout Reminders';
  static const String _channelDescription = 'Reminders to complete workouts for screen time';

  /// Initialize the notification service
  Future<void> initialize() async {
    debugPrint('🔔 Initializing NotificationService...');
    // Initialize settings for Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Create notification category for iOS (cannot be const due to non-const actions)
    final workoutCategory = DarwinNotificationCategory(
      'workout_reminder',
      actions: [
        DarwinNotificationAction.plain(
          'start_workout',
          'Start Workout',
          options: {DarwinNotificationActionOption.foreground},
        ),
        DarwinNotificationAction.plain(
          'later',
          'Later',
          options: {DarwinNotificationActionOption.destructive},
        ),
      ],
    );

    // Initialize settings for iOS
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [workoutCategory],
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    // Request permissions on iOS
    if (Platform.isIOS) {
      await _requestIOSPermissions();
    }

    debugPrint('✅ NotificationService initialized');

    debugPrint('✅ Notification service initialized');
  }

  /// Request iOS notification permissions
  Future<bool> _requestIOSPermissions() async {
    final bool? granted = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    debugPrint('📱 iOS notification permissions: ${granted ?? false}');
    return granted ?? false;
  }

  /// Show workout reminder notification
  Future<void> showWorkoutReminder({
    required String title,
    required String body,
    int? badgeNumber,
  }) async {
    try {
      debugPrint('🔔 Attempting to show workout reminder: "$title" - "$body"');

      // Verify permissions first
      if (Platform.isIOS) {
        final enabled = await areNotificationsEnabled();
        if (!enabled) {
          debugPrint('❌ Cannot show notification - permissions not granted');
          debugPrint('💡 User needs to enable notifications in Settings > PUSHIN > Notifications');
          return;
        }
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        autoCancel: true,
        category: AndroidNotificationCategory.reminder,
        actions: [
          AndroidNotificationAction('start_workout', 'Start Workout'),
          AndroidNotificationAction('later', 'Later'),
        ],
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        categoryIdentifier: 'workout_reminder',
        interruptionLevel: InterruptionLevel.timeSensitive,
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        0, // notification id
        title,
        body,
        details,
        payload: 'workout_reminder',
      );

      debugPrint('✅ Workout reminder notification shown successfully');

      // Verify it was scheduled
      final pending = await getPendingNotifications();
      debugPrint('📊 Pending notifications count: ${pending.length}');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to show workout notification: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Cancel all pending notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('🗑️ All notifications cancelled');
  }

  /// Cancel specific notification by ID
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    debugPrint('🗑️ Notification $id cancelled');
  }

  /// Handle notification tap when app is in foreground
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Notification tapped: ${response.payload}');

    if (response.payload == 'workout_reminder') {
      _handleWorkoutNotificationAction(response.actionId);
    }
  }

  /// Handle notification tap when app is in background
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    debugPrint('📱 Background notification tapped: ${response.payload}');
    // This will wake the app and handle the notification
  }

  /// Handle workout notification actions
  void _handleWorkoutNotificationAction(String? actionId) {
    switch (actionId) {
      case 'start_workout':
        debugPrint('🏋️ User tapped "Start Workout"');
        // Navigate to workout selection screen
        _navigateToWorkoutScreen();
        break;

      case 'later':
        debugPrint('⏰ User tapped "Later"');
        // Just dismiss - no action needed
        break;

      default:
        debugPrint('🏋️ User tapped notification directly');
        // Navigate to workout selection screen
        _navigateToWorkoutScreen();
        break;
    }
  }

  /// Navigate to workout selection screen
  void _navigateToWorkoutScreen() {
    // This will be handled by the app's navigation system
    // We'll emit an event that the app can listen to
    debugPrint('🧭 Navigation to workout screen requested');
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isIOS) return true; // Assume enabled on Android

    final iosPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin == null) {
      debugPrint('⚠️ iOS notification plugin not available');
      return false;
    }

    final permissions = await iosPlugin.checkPermissions();
    if (permissions == null) {
      debugPrint('⚠️ Notification permissions are null - likely not granted');
      return false;
    }

    final isEnabled = permissions.isEnabled;
    debugPrint('📱 Notification permissions status - Enabled: $isEnabled');
    return isEnabled;
  }

  /// Get pending notification requests (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }
}