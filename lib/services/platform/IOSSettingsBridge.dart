import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to iOS UserDefaults and Android SharedPreferences for storing app settings
/// that need to be accessed by platform extensions
class IOSSettingsBridge {
  static const MethodChannel _iosChannel =
      MethodChannel('com.pushin.iossettings');
  static const MethodChannel _androidChannel =
      MethodChannel('com.pushin.blockingservice');

  static IOSSettingsBridge? _instance;
  static IOSSettingsBridge get instance {
    _instance ??= IOSSettingsBridge._();
    return _instance!;
  }

  IOSSettingsBridge._();

  /// Whether this bridge is supported on the current platform
  bool get isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Save emergency unlock enabled setting to platform storage
  Future<void> setEmergencyUnlockEnabled(bool enabled) async {
    if (!isSupported) return;

    try {
      if (Platform.isIOS) {
        await _iosChannel
            .invokeMethod('setEmergencyUnlockEnabled', {'enabled': enabled});
      } else if (Platform.isAndroid) {
        await _androidChannel
            .invokeMethod('setEmergencyUnlockEnabled', {'enabled': enabled});
      }
    } catch (e) {
      print('❌ Failed to save emergency unlock setting: $e');
    }
  }

  /// Save emergency unlock duration setting to platform storage
  Future<void> setEmergencyUnlockMinutes(int minutes) async {
    if (!isSupported) return;

    try {
      if (Platform.isIOS) {
        await _iosChannel
            .invokeMethod('setEmergencyUnlockMinutes', {'minutes': minutes});
        print('✅ Saved emergency unlock minutes to iOS: $minutes');
      } else if (Platform.isAndroid) {
        await _androidChannel
            .invokeMethod('setEmergencyUnlockMinutes', {'minutes': minutes});
        print('✅ Saved emergency unlock minutes to Android: $minutes');
      }
    } catch (e) {
      print('❌ Failed to save emergency unlock minutes: $e');
    }
  }
}
