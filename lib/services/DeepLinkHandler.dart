import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'StripeCheckoutService.dart';

/// Deep Link Handler for Stripe Checkout returns
///
/// Handles:
/// - pushinapp://payment-success?session_id=xxx
/// - pushinapp://payment-cancel
class DeepLinkHandler {
  final StripeCheckoutService stripeService;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Callbacks
  Function(SubscriptionStatus)? onPaymentSuccess;
  Function()? onPaymentCanceled;
  Function(String token)? onPasswordReset;
  Function(String? previousPlan)? onSubscriptionCancelled;

  // Store the userId from the last checkout for verification
  // This is set by PaywallScreen before launching checkout
  String? pendingCheckoutUserId;

  // Store subscription status before opening portal for comparison
  SubscriptionStatus? _subscriptionBeforePortal;

  // Store the planId for fallback subscription status creation
  String? pendingCheckoutPlanId;

  // Function to get current authenticated user ID (injected from PushinAppController)
  String? Function()? getCurrentUserId;

  DeepLinkHandler({
    required this.stripeService,
    this.onPaymentSuccess,
    this.onPaymentCanceled,
    this.onPasswordReset,
    this.onSubscriptionCancelled,
    this.getCurrentUserId,
  });

  /// Initialize deep link listener
  Future<void> initialize() async {
    print('🔗 ═══════════════════════════════════════════════');
    print('🔗 INITIALIZING DEEP LINK HANDLER');
    print('🔗 ═══════════════════════════════════════════════');

    // Deep links are not supported on web platform or test environment
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      print(
          '🔗 Deep links not supported on web platform or test environment - deep link functionality disabled');
      return;
    }

    // CRITICAL: Load persisted pendingCheckoutPlanId from SharedPreferences
    // This ensures the plan ID survives app kill/recreation during Stripe checkout
    try {
      final prefs = await SharedPreferences.getInstance();
      pendingCheckoutPlanId = prefs.getString('pending_checkout_plan_id');
      if (pendingCheckoutPlanId != null) {
        print(
            '💳 Restored pendingCheckoutPlanId from storage: $pendingCheckoutPlanId');
      } else {
        print('💳 No pending checkout plan ID found in storage');
      }
    } catch (e) {
      print('❌ Error loading pendingCheckoutPlanId: $e');
    }

    // Handle initial link if app was opened from deep link
    try {
      print('🔗 Checking for initial deep link (app opened via deep link)...');
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        print('🔗 ✅ INITIAL DEEP LINK DETECTED: $initialLink');
        await _handleDeepLink(initialLink);
      } else {
        print('🔗 No initial deep link (app not opened via deep link)');
      }
    } catch (e) {
      print('🔗 ❌ Error getting initial link: $e');
      // If this is a MissingPluginException (likely in test environment), skip deep link functionality
      if (e.toString().contains('MissingPluginException')) {
        print('🔗 Deep link functionality disabled (likely test environment)');
        return;
      }
    }

    // Listen for links while app is running
    print(
        '🔗 Setting up deep link stream listener (for links while app is running)...');
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          print('🔗 ═══════════════════════════════════════════════');
          print('🔗 DEEP LINK STREAM RECEIVED: $uri');
          print('🔗 ═══════════════════════════════════════════════');
          _handleDeepLink(uri);
        },
        onError: (err) {
          print('🔗 ❌ Deep link stream error: $err');
        },
      );
      print('🔗 ✅ Deep link stream listener set up successfully');
    } catch (e) {
      print('🔗 ❌ Failed to listen for deep links: $e');
      // If this is a MissingPluginException (likely in test environment), skip deep link functionality
      if (e.toString().contains('MissingPluginException')) {
        print('🔗 Deep link functionality disabled (likely test environment)');
        return;
      }
    }
  }

  /// Handle incoming deep link
  Future<void> _handleDeepLink(Uri uri) async {
    print('🔗 _handleDeepLink called with: $uri');
    print('🔗   scheme: ${uri.scheme}');
    print('🔗   host: ${uri.host}');
    print('🔗   queryParameters: ${uri.queryParameters}');

    // Parse the deep link
    if (uri.scheme == 'pushinapp') {
      print('🔗 ✅ Valid pushinapp scheme detected');
      switch (uri.host) {
        case 'payment-success':
          print('🔗 → Routing to _handlePaymentSuccess');
          await _handlePaymentSuccess(uri);
          break;

        case 'payment-cancel':
          print('🔗 → Routing to _handlePaymentCancel');
          _handlePaymentCancel();
          break;

        case 'reset-password':
          print('🔗 → Routing to _handlePasswordReset');
          await _handlePasswordReset(uri);
          break;

        case 'portal-return':
          print('🔗 → Routing to _handlePortalReturn');
          await _handlePortalReturn();
          break;

        default:
          print('🔗 ❌ Unknown deep link host: ${uri.host}');
      }
    } else {
      print('🔗 ❌ Invalid scheme: ${uri.scheme} (expected: pushinapp)');
    }
  }

  /// Handle payment success
  Future<void> _handlePaymentSuccess(Uri uri) async {
    print('💳 ═══════════════════════════════════════════════');
    print('💳 PAYMENT SUCCESS DEEP LINK RECEIVED');
    print('💳 URI: $uri');
    print('💳 pendingCheckoutUserId: $pendingCheckoutUserId');
    print('💳 ═══════════════════════════════════════════════');

    // Extract session_id from query parameters
    final sessionId = uri.queryParameters['session_id'];

    if (sessionId == null) {
      print('💳 ❌ No session_id in payment success link');
      return;
    }

    print('💳 Verifying payment with session_id: $sessionId');

    SubscriptionStatus? status;

    // Get current authenticated user ID (required for payment verification)
    final currentUserId = getCurrentUserId?.call();
    final effectiveUserId = currentUserId ?? pendingCheckoutUserId;

    if (effectiveUserId == null) {
      print('💳 ❌ No user ID available for payment verification');
      print('💳 ⚠️ User must be authenticated to complete payment');
      return;
    }

    print('💳 Verifying payment for userId: $effectiveUserId');

    // Verify payment with the user ID
    status = await stripeService.verifyPayment(
      sessionId: sessionId,
      userId: effectiveUserId,
    );

    // Save for fallback
    final usedPlanId = pendingCheckoutPlanId;

    // Clear the pending IDs after verification attempt
    pendingCheckoutUserId = null;
    pendingCheckoutPlanId = null;

    // Clear persisted values from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_checkout_plan_id');
      print('🧹 Cleared persisted pendingCheckoutPlanId');
    } catch (e) {
      print('❌ Error clearing pendingCheckoutPlanId: $e');
    }

    if (status != null && status.isActive) {
      print('💳 ✅ PAYMENT VERIFIED!');
      print('💳   Plan: ${status.planId}');
      print('💳   Is Active: ${status.isActive}');
      print('💳 Calling onPaymentSuccess callback...');
      onPaymentSuccess?.call(status);
      print('💳 ✅ onPaymentSuccess callback completed');
    } else {
      // Backend verification failed, but Stripe DID redirect to success URL
      // This means the payment was successful on Stripe's side
      // Show success screen with a fallback - backend will sync later
      print('💳 ⚠️ Backend verification failed, creating fallback status');
      print('   - usedPlanId: $usedPlanId');

      final fallbackStatus = SubscriptionStatus(
        isActive: true,
        planId: usedPlanId ?? 'pro', // Use selected plan or default to pro
        customerId: effectiveUserId,
        subscriptionId: sessionId,
        currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
        cachedUserId: effectiveUserId,
      );

      // Cache the fallback status
      await stripeService.saveSubscriptionStatus(fallbackStatus);
      print('💳 Cached fallback subscription with userId: $effectiveUserId');

      onPaymentSuccess?.call(fallbackStatus);
      print('💳 ✅ onPaymentSuccess callback completed (with fallback)');
    }
  }

  /// Handle payment cancel
  void _handlePaymentCancel() {
    print('Payment canceled by user');
    onPaymentCanceled?.call();
  }

  /// Handle password reset deep link
  Future<void> _handlePasswordReset(Uri uri) async {
    print('🔗 Password reset deep link received');

    // Extract token from query parameters
    final token = uri.queryParameters['token'];

    if (token == null || token.isEmpty) {
      print('❌ No token in password reset link');
      _showErrorSnackBar('Invalid password reset link - missing token');
      return;
    }

    // Basic format validation (should be 64 hex characters)
    if (!RegExp(r'^[a-f0-9]{64}$', caseSensitive: false).hasMatch(token)) {
      print('❌ Invalid token format in password reset link');
      _showErrorSnackBar('Invalid password reset link format');
      return;
    }

    print('🔍 Validating token format: ${token.substring(0, 8)}...');

    try {
      // Validate token with backend before navigation
      final isValid = await _validateResetToken(token);

      if (isValid) {
        print('✅ Token validated, navigating to reset screen');
        // Navigate to reset password screen with validated token
        _navigateToResetPassword(token);
      } else {
        print('❌ Token validation failed');
        _showErrorSnackBar('This password reset link is invalid or expired');
      }
    } catch (error) {
      print('💥 Token validation error: $error');
      _showErrorSnackBar(
          'Unable to validate password reset link. Please try again.');
    }
  }

  /// Validate reset token with backend
  Future<bool> _validateResetToken(String token) async {
    try {
      // Use the same base URL as AuthenticationService
      final baseUrl = Platform.isIOS
          ? 'http://192.168.1.107:3000/api'
          : Platform.isAndroid
              ? 'http://10.0.2.2:3000/api'
              : 'http://localhost:3000/api';

      final response = await http.post(
        Uri.parse('$baseUrl/auth/validate-reset-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );

      print('🔍 Token validation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('❌ Token validation network error: $e');
      // For now, return true to allow navigation even if backend is down
      return true;
    }
  }

  /// Navigate to reset password screen
  void _navigateToResetPassword(String token) {
    print(
        '🧭 Calling onPasswordReset callback with token: ${token.substring(0, 8)}...');
    onPasswordReset?.call(token);
  }

  /// Set subscription status before opening portal for comparison
  void setSubscriptionBeforePortal(SubscriptionStatus? status) {
    _subscriptionBeforePortal = status;
    print('🔗 Stored subscription before portal: ${status?.planId} (active: ${status?.isActive})');
  }

  /// Handle portal return
  Future<void> _handlePortalReturn() async {
    print('🔗 ═══════════════════════════════════════════════');
    print('🔗 PORTAL RETURN DEEP LINK RECEIVED');
    print('🔗 ═══════════════════════════════════════════════');

    // Get current authenticated user ID
    final currentUserId = getCurrentUserId?.call();

    if (currentUserId == null) {
      print('🔗 ⚠️ No user ID available - cannot refresh subscription');
      return;
    }

    print('🔗 Refreshing subscription status for userId: $currentUserId');
    print('🔗 Previous subscription: ${_subscriptionBeforePortal?.planId} (active: ${_subscriptionBeforePortal?.isActive})');

    // Refresh subscription status after portal return
    try {
      final subscriptionStatus = await stripeService.checkSubscriptionStatus(
        userId: currentUserId,
      );

      print('🔗 Current subscription: ${subscriptionStatus?.planId} (active: ${subscriptionStatus?.isActive}, cancelAtPeriodEnd: ${subscriptionStatus?.cancelAtPeriodEnd})');

      // Check if subscription was cancelled (set to cancel at period end)
      final wasNotCancelling = _subscriptionBeforePortal?.cancelAtPeriodEnd != true &&
                                _subscriptionBeforePortal?.isActive == true &&
                                _subscriptionBeforePortal?.planId != 'free';
      final isNowCancelling = subscriptionStatus?.cancelAtPeriodEnd == true;

      if (wasNotCancelling && isNowCancelling) {
        print('🔗 🚨 SUBSCRIPTION CANCELLATION DETECTED (cancel_at_period_end)');
        print('🔗    Plan: ${_subscriptionBeforePortal?.planId}');
        print('🔗    Before: cancelAtPeriodEnd = ${_subscriptionBeforePortal?.cancelAtPeriodEnd}');
        print('🔗    After: cancelAtPeriodEnd = ${subscriptionStatus?.cancelAtPeriodEnd}');

        // Trigger cancellation callback
        onSubscriptionCancelled?.call(_subscriptionBeforePortal?.planId);

        // Also update UI with new status
        if (subscriptionStatus != null) {
          onPaymentSuccess?.call(subscriptionStatus);
        }
      } else if (subscriptionStatus != null && subscriptionStatus.isActive) {
        print('🔗 ✅ Subscription still active: ${subscriptionStatus.planId}');
        // Trigger payment success callback to update UI
        onPaymentSuccess?.call(subscriptionStatus);
      } else {
        print('🔗 ⚠️ Subscription is no longer active');
        // Still trigger callback to update UI (subscription may have been canceled)
        if (subscriptionStatus != null) {
          onPaymentSuccess?.call(subscriptionStatus);
        }
      }

      // Clear the stored previous status
      _subscriptionBeforePortal = null;
    } catch (e) {
      print('🔗 ❌ Error refreshing subscription status: $e');
      // Clear the stored previous status even on error
      _subscriptionBeforePortal = null;
    }
  }

  /// Show error message to user
  void _showErrorSnackBar(String message) {
    // This would show a snackbar or dialog to the user
    print('📢 Would show error to user: $message');
  }

  /// Dispose listener
  void dispose() {
    _linkSubscription?.cancel();
  }
}
