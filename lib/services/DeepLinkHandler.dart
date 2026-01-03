import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uni_links/uni_links.dart';
import 'StripeCheckoutService.dart';

/// Deep Link Handler for Stripe Checkout returns
///
/// Handles:
/// - pushinapp://payment-success?session_id=xxx
/// - pushinapp://payment-cancel
class DeepLinkHandler {
  final StripeCheckoutService stripeService;
  StreamSubscription? _linkSubscription;

  // Callbacks
  Function(SubscriptionStatus)? onPaymentSuccess;
  Function()? onPaymentCanceled;

  DeepLinkHandler({
    required this.stripeService,
    this.onPaymentSuccess,
    this.onPaymentCanceled,
  });

  /// Initialize deep link listener
  Future<void> initialize() async {
    print('Initializing deep link handler...');

    // Deep links are not supported on web platform or test environment
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      print(
          'Deep links not supported on web platform or test environment - deep link functionality disabled');
      return;
    }

    // Handle initial link if app was opened from deep link
    try {
      final initialLink = await getInitialUri();
      if (initialLink != null) {
        print('Initial deep link detected: $initialLink');
        await _handleDeepLink(initialLink);
      } else {
        print('No initial deep link');
      }
    } catch (e) {
      print('Error getting initial link: $e');
      // If this is a MissingPluginException (likely in test environment), skip deep link functionality
      if (e.toString().contains('MissingPluginException')) {
        print('Deep link functionality disabled (likely test environment)');
        return;
      }
    }

    // Listen for links while app is running
    print('Listening for deep links...');
    try {
      _linkSubscription = uriLinkStream.listen(
        (Uri? uri) {
          print('Deep link stream received: $uri');
          if (uri != null) {
            _handleDeepLink(uri);
          }
        },
        onError: (err) {
          print('Deep link stream error: $err');
        },
      );
    } catch (e) {
      print('Failed to listen for deep links: $e');
      // If this is a MissingPluginException (likely in test environment), skip deep link functionality
      if (e.toString().contains('MissingPluginException')) {
        print('Deep link functionality disabled (likely test environment)');
        return;
      }
    }
  }

  /// Handle incoming deep link
  Future<void> _handleDeepLink(Uri uri) async {
    print('Deep link received: $uri');

    // Parse the deep link
    if (uri.scheme == 'pushinapp') {
      switch (uri.host) {
        case 'payment-success':
          await _handlePaymentSuccess(uri);
          break;

        case 'payment-cancel':
          _handlePaymentCancel();
          break;

        default:
          print('Unknown deep link host: ${uri.host}');
      }
    }
  }

  /// Handle payment success
  Future<void> _handlePaymentSuccess(Uri uri) async {
    print('Payment success deep link received');

    // Extract session_id from query parameters
    final sessionId = uri.queryParameters['session_id'];

    if (sessionId == null) {
      print('No session_id in payment success link');
      return;
    }

    print('Verifying payment with session_id: $sessionId');

    // Verify payment with backend
    // TODO: Get userId from your auth service
    const userId = 'test_user_123'; // Match the user ID used in PaywallScreen

    final status = await stripeService.verifyPayment(
      sessionId: sessionId,
      userId: userId,
    );

    if (status != null && status.isActive) {
      print('Payment verified! Plan: ${status.planId}');
      onPaymentSuccess?.call(status);
    } else {
      print('Payment verification failed');
    }
  }

  /// Handle payment cancel
  void _handlePaymentCancel() {
    print('Payment canceled by user');
    onPaymentCanceled?.call();
  }

  /// Dispose listener
  void dispose() {
    _linkSubscription?.cancel();
  }
}
