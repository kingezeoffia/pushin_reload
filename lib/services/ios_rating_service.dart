import 'dart:io';
import 'package:flutter/services.dart';

/// Service to request native iOS rating popup using StoreKit
class IOSRatingService {
  static const MethodChannel _channel = MethodChannel('pushin.app/rating');

  /// Request the native iOS rating dialog (StoreKit)
  /// This will show the system rating popup on iOS
  /// Returns true if the request was successful (doesn't mean user rated)
  static Future<bool> requestNativeRating() async {
    if (!Platform.isIOS) {
      print('⭐ IOSRatingService: Not on iOS, skipping native rating');
      return false;
    }

    try {
      final result = await _channel.invokeMethod('requestReview');
      print('⭐ IOSRatingService: Native rating requested, result: $result');
      return result == true;
    } catch (e) {
      print('⭐ IOSRatingService: Error requesting native rating: $e');
      return false;
    }
  }
}
