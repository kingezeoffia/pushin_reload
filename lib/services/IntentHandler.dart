import 'package:flutter/services.dart';

/// Handles Android intents from native code
///
/// Used to handle cases where the native blocking service launches
/// the app with specific actions (e.g., "start_workout")
class IntentHandler {
  static const MethodChannel _channel = MethodChannel('com.pushin.intent');

  Function(String? blockedApp)? _onStartWorkoutIntent;

  /// Initialize the intent handler and set up method call handler
  void initialize({
    required Function(String? blockedApp) onStartWorkoutIntent,
  }) {
    _onStartWorkoutIntent = onStartWorkoutIntent;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onStartWorkoutIntent') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        final blockedApp = args?['blocked_app'] as String?;

        print('IntentHandler: Received start workout intent for app: $blockedApp');
        _onStartWorkoutIntent?.call(blockedApp);
      }
    });

    print('IntentHandler: Initialized');
  }

  /// Dispose of resources
  void dispose() {
    _onStartWorkoutIntent = null;
  }
}
