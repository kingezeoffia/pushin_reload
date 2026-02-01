import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'PaymentService.dart';

/// Stripe Web Checkout Service
///
/// Handles external Stripe Checkout flow for subscriptions
/// - Creates checkout sessions via backend API
/// - Launches browser for payment
/// - Handles return deep links
/// - Stores subscription status locally
/// - Supports test mode for development
class StripeCheckoutService implements PaymentService {
  final String baseUrl;
  final bool isTestMode;

  // Backend API URLs
  // Dev: http://localhost:3000/api
  // Test: https://your-test-backend.up.railway.app/api
  // Prod: Set via environment or update this URL after deployment
  StripeCheckoutService({
    this.baseUrl =
        'https://pushin-production.up.railway.app/api', // Update with your Railway domain
    this.isTestMode = false,
  });

  /// Create Stripe Checkout session and launch browser
  ///
  /// Returns true if checkout was launched successfully
  /// Requires authenticated user - userId must be provided
  Future<bool> launchCheckout({
    required String userId,
    required String planId, // 'pro' or 'advanced'
    required String billingPeriod, // 'monthly' or 'yearly'
    required String userEmail,
  }) async {
    // TEST MODE SIMULATION: If no real Stripe keys, simulate the flow
    if (isTestMode && !baseUrl.contains('railway.app')) {
      return await _simulateTestCheckout(
          userId, planId, billingPeriod, userEmail);
    }

    // REAL STRIPE INTEGRATION
    try {
      // 1. Call your backend to create Stripe Checkout session
      final requestBody = {
        'userId': userId,
        'planId': planId,
        'billingPeriod': billingPeriod,
        'userEmail': userEmail,
        'successUrl':
            'pushinapp://payment-success?session_id={CHECKOUT_SESSION_ID}',
        'cancelUrl': 'pushinapp://payment-cancel',
      };

      print('🔵 StripeCheckoutService: Creating checkout session');
      print('   URL: $baseUrl/stripe/create-checkout-session');
      print('   Request body: $requestBody');

      http.Response response;
      try {
        print('🔵 StripeCheckoutService: Sending HTTP POST...');
        response = await http
            .post(
              Uri.parse('$baseUrl/stripe/create-checkout-session'),
              headers: {
                'Content-Type': 'application/json',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 30));
        print('🔵 StripeCheckoutService: HTTP POST completed');
      } catch (httpError) {
        print('❌ StripeCheckoutService: HTTP POST FAILED: $httpError');
        return false;
      }

      print(
          '📡 StripeCheckoutService: Response status: ${response.statusCode}');
      print('   Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final checkoutUrl = data['checkoutUrl'] as String;

        // 2. Launch Stripe Checkout in browser
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // Opens in browser
          );
          return true;
        } else {
          print('Could not launch Stripe Checkout URL');
          return false;
        }
      } else {
        print('Failed to create checkout session: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error launching Stripe Checkout: $e');
      return false;
    }
  }

  /// Verify payment after return from Stripe Checkout
  ///
  /// Called when app receives deep link: pushinapp://payment-success?session_id=...
  /// Requires authenticated user - userId must be provided
  Future<SubscriptionStatus?> verifyPayment({
    required String sessionId,
    required String userId,
  }) async {
    print('🔵 StripeCheckoutService.verifyPayment() called');
    print('   - sessionId: ${sessionId.substring(0, 20)}...');
    print('   - userId: $userId');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stripe/verify-payment'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'sessionId': sessionId,
          'userId': userId,
        }),
      );

      print('📡 verifyPayment response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ verifyPayment success data: $data');

        final status = SubscriptionStatus(
          isActive: data['isActive'] as bool,
          planId: data['planId'] as String,
          customerId: data['customerId'] as String?,
          subscriptionId: data['subscriptionId'] as String?,
          currentPeriodEnd: data['currentPeriodEnd'] != null
              ? DateTime.parse(data['currentPeriodEnd'] as String)
              : null,
          cachedUserId: userId, // Always associate with the authenticated user
          cancelAtPeriodEnd: data['cancelAtPeriodEnd'] as bool? ?? false,
        );

        // Store locally with user ID for validation
        await _saveSubscriptionStatus(status);

        print('✅ Subscription status saved with cachedUserId: $userId');

        return status;
      } else {
        print('❌ Failed to verify payment: ${response.statusCode}');
        print('   Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error verifying payment: $e');
      return null;
    }
  }

  /// Check current subscription status from backend
  /// Requires authenticated user - userId must be provided
  Future<SubscriptionStatus?> checkSubscriptionStatus({
    required String userId,
  }) async {
    print('🔵 StripeCheckoutService.checkSubscriptionStatus() called');
    print('   - userId: $userId');

    try {
      final uri = Uri.parse('$baseUrl/stripe/subscription-status')
          .replace(queryParameters: {'userId': userId});

      print('🔵 Fetching: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('📡 checkSubscriptionStatus response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ checkSubscriptionStatus data: $data');

        final status = SubscriptionStatus(
          isActive: data['isActive'] as bool,
          planId: data['planId'] as String,
          customerId: data['customerId'] as String?,
          subscriptionId: data['subscriptionId'] as String?,
          currentPeriodEnd: data['currentPeriodEnd'] != null
              ? DateTime.parse(data['currentPeriodEnd'] as String)
              : null,
          cachedUserId: userId, // Always associate with the authenticated user
          cancelAtPeriodEnd: data['cancelAtPeriodEnd'] as bool? ?? false,
        );

        // Update local cache with user ID for validation
        await _saveSubscriptionStatus(status);

        print('✅ Subscription cache updated with cachedUserId: $userId');
        print('   - cancelAtPeriodEnd: ${status.cancelAtPeriodEnd}');

        return status;
      } else if (response.statusCode == 404) {
        print('ℹ️ No subscription found for user: $userId');
        return null;
      } else {
        print('❌ Failed to check subscription status: ${response.statusCode}');
        print('   Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error checking subscription status: $e');
      return null;
    }
  }

  /// Get locally cached subscription status
  Future<SubscriptionStatus?> getCachedSubscriptionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // CRITICAL CHANGE: Check if cache actually exists before returning defaults
      // If planId is missing, we consider the cache invalid/empty
      if (!prefs.containsKey('subscription_planId')) {
        return null;
      }

      final isActive = prefs.getBool('subscription_isActive') ?? false;
      final planId = prefs.getString('subscription_planId') ?? 'free';
      final customerId = prefs.getString('subscription_customerId');
      final subscriptionId = prefs.getString('subscription_subscriptionId');
      final periodEndStr = prefs.getString('subscription_periodEnd');
      final cachedUserId = prefs.getString('subscription_cached_user_id');

      return SubscriptionStatus(
        isActive: isActive,
        planId: planId,
        customerId: customerId,
        subscriptionId: subscriptionId,
        currentPeriodEnd:
            periodEndStr != null ? DateTime.tryParse(periodEndStr) : null,
        cachedUserId: cachedUserId, // Add cached user ID for validation
      );
    } catch (e) {
      print('Error getting cached subscription: $e');
      return null;
    }
  }

  /// Save subscription status locally (public for fallback caching)
  Future<void> saveSubscriptionStatus(SubscriptionStatus status) async {
    await _saveSubscriptionStatus(status);
  }

  /// Completely wipe subscription data
  Future<void> clearSubscriptionCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('subscription_isActive');
      await prefs.remove('subscription_planId');
      await prefs.remove('subscription_customerId');
      await prefs.remove('subscription_subscriptionId');
      await prefs.remove('subscription_periodEnd');
      await prefs.remove('subscription_cached_user_id'); // Ensure ID is wiped
      print('🧹 Subscription cache completely cleared');
    } catch (e) {
      print('Error clearing subscription cache: $e');
    }
  }

  /// Save subscription status locally (internal)
  Future<void> _saveSubscriptionStatus(SubscriptionStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('subscription_isActive', status.isActive);
      await prefs.setString('subscription_planId', status.planId);

      // Set or remove customerId
      if (status.customerId != null) {
        await prefs.setString('subscription_customerId', status.customerId!);
      } else {
        await prefs.remove('subscription_customerId');
      }

      // Set or remove subscriptionId
      if (status.subscriptionId != null) {
        await prefs.setString(
            'subscription_subscriptionId', status.subscriptionId!);
      } else {
        await prefs.remove('subscription_subscriptionId');
      }

      // Set or remove periodEnd
      if (status.currentPeriodEnd != null) {
        await prefs.setString('subscription_periodEnd',
            status.currentPeriodEnd!.toIso8601String());
      } else {
        await prefs.remove('subscription_periodEnd');
      }

      // Set or remove cached user ID (for validation)
      if (status.cachedUserId != null) {
        await prefs.setString(
            'subscription_cached_user_id', status.cachedUserId!);
      } else {
        await prefs.remove('subscription_cached_user_id');
      }

      print(
          'Subscription status saved locally: planId=${status.planId}, isActive=${status.isActive}, customerId=${status.customerId}, cachedUserId=${status.cachedUserId}');
    } catch (e) {
      print('Error saving subscription status: $e');
    }
  }

  /// Cancel subscription (creates cancellation intent)
  /// Requires authenticated user - userId must be provided
  Future<bool> cancelSubscription({
    required String userId,
    required String subscriptionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stripe/cancel-subscription'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'subscriptionId': subscriptionId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error canceling subscription: $e');
      return false;
    }
  }

  /// Open Stripe Customer Portal for subscription management
  /// Requires authenticated user - userId must be provided
  Future<bool> openCustomerPortal({
    required String userId,
    String? anonymousId,
  }) async {
    try {
      print('🔵 StripeCheckoutService: Opening customer portal');
      print('   URL: $baseUrl/stripe/create-portal-session');
      print('   userId: $userId');
      if (anonymousId != null) print('   anonymousId: $anonymousId');

      final requestBody = {
        'userId': userId,
        if (anonymousId != null) 'anonymousId': anonymousId,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/stripe/create-portal-session'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      print('📡 Portal session response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final portalUrl = data['url'] as String;

        print('✅ Portal URL received, launching: $portalUrl');

        final uri = Uri.parse(portalUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        } else {
          print('❌ Could not launch portal URL');
          return false;
        }
      } else {
        print('❌ Failed to create portal session: ${response.statusCode}');
        print('   Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error opening customer portal: $e');
      return false;
    }
  }

  /// Simulate Stripe Checkout for testing without real keys
  Future<bool> _simulateTestCheckout(String userId, String planId,
      String billingPeriod, String userEmail) async {
    try {
      print(
          'TEST MODE: Simulating Stripe Checkout for $planId plan ($billingPeriod)');

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Simulate successful payment
      final simulatedStatus = SubscriptionStatus(
        isActive: true,
        planId: planId,
        customerId: 'cus_test_${userId}',
        subscriptionId:
            'sub_test_${userId}_${DateTime.now().millisecondsSinceEpoch}',
        currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
      );

      // Save simulated subscription
      await _saveSubscriptionStatus(simulatedStatus);

      print('TEST MODE: Payment simulated successfully');
      return true;
    } catch (e) {
      print('TEST MODE: Error simulating payment: $e');
      return false;
    }
  }

  /// Restore subscription by email verification
  @override
  Future<RestorePurchaseResult> restoreSubscriptionByEmail({
    required String email,
  }) async {
    try {
      print(
          '🔍 StripeCheckoutService: Restoring subscription for email: $email');

      // Validate email format
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailRegex.hasMatch(email)) {
        return RestorePurchaseResult(
          success: false,
          errorCode: 'invalid_email',
          errorMessage: 'Please enter a valid email address.',
        );
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/stripe/restore-by-email'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      print(
          '📡 StripeCheckoutService: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final subscriptionData = data['subscription'];

          final status = SubscriptionStatus(
            isActive: subscriptionData['isActive'] as bool,
            planId: subscriptionData['planId'] as String,
            customerId: subscriptionData['customerId'] as String?,
            subscriptionId: subscriptionData['subscriptionId'] as String?,
            currentPeriodEnd: subscriptionData['currentPeriodEnd'] != null
                ? DateTime.parse(subscriptionData['currentPeriodEnd'] as String)
                : null,
          );

          // Save to local cache (userId will be set later when user logs in)
          // For restore operations, cachedUserId will be null until linked to a user account
          final statusWithUserId = SubscriptionStatus(
            isActive: status.isActive,
            planId: status.planId,
            customerId: status.customerId,
            subscriptionId: status.subscriptionId,
            currentPeriodEnd: status.currentPeriodEnd,
            cachedUserId: null, // Will be validated when user logs in
          );
          await _saveSubscriptionStatus(statusWithUserId);

          print(
              '✅ StripeCheckoutService: Subscription restored - ${status.planId}');

          return RestorePurchaseResult(
            success: true,
            subscription: status,
          );
        }

        // If success is not true, treat as generic error
        return RestorePurchaseResult(
          success: false,
          errorCode: 'unknown_error',
          errorMessage: 'Unexpected response from server.',
        );
      } else if (response.statusCode == 404) {
        // No active subscription found
        final data = jsonDecode(response.body);

        final expiredSubs = (data['expiredSubscriptions'] as List<dynamic>?)
            ?.map(
                (e) => ExpiredSubscription.fromJson(e as Map<String, dynamic>))
            .toList();

        return RestorePurchaseResult(
          success: false,
          errorCode: data['error'] as String?,
          errorMessage:
              data['message'] as String? ?? 'No active subscriptions found.',
          expiredSubscriptions: expiredSubs,
        );
      } else if (response.statusCode == 429) {
        // Rate limited
        final data = jsonDecode(response.body);
        return RestorePurchaseResult(
          success: false,
          errorCode: 'rate_limit_exceeded',
          errorMessage: data['message'] as String? ??
              'Too many attempts. Please try again in a few minutes.',
        );
      } else {
        // Other error
        final data = jsonDecode(response.body);
        return RestorePurchaseResult(
          success: false,
          errorCode: data['error'] as String? ?? 'unknown_error',
          errorMessage: data['message'] as String? ??
              'Unable to restore subscription. Please try again.',
        );
      }
    } on TimeoutException {
      print('⏱️ StripeCheckoutService: Request timeout');
      return RestorePurchaseResult(
        success: false,
        errorCode: 'timeout',
        errorMessage:
            'Request timed out. Please check your connection and try again.',
      );
    } catch (e) {
      print('❌ StripeCheckoutService: Error restoring subscription: $e');
      return RestorePurchaseResult(
        success: false,
        errorCode: 'network_error',
        errorMessage:
            'Network error. Please check your connection and try again.',
      );
    }
  }
}

/// Subscription Status Model
class SubscriptionStatus {
  final bool isActive;
  final String planId; // 'free', 'pro', 'advanced'
  final String? customerId;
  final String? subscriptionId;
  final DateTime? currentPeriodEnd;
  final String? cachedUserId; // User ID this subscription belongs to
  final bool cancelAtPeriodEnd; // True if subscription is set to cancel

  SubscriptionStatus({
    required this.isActive,
    required this.planId,
    this.customerId,
    this.subscriptionId,
    this.currentPeriodEnd,
    this.cachedUserId,
    this.cancelAtPeriodEnd = false,
  });

  bool get isPaid => planId != 'free' && isActive;
  bool get isPro => planId == 'pro' && isActive;
  bool get isAdvanced => planId == 'advanced' && isActive;
  bool get isCancelling => cancelAtPeriodEnd && isActive; // Active but will cancel

  String get displayName {
    switch (planId) {
      case 'pro':
        return 'Pro Plan';
      case 'advanced':
        return 'Advanced Plan';
      default:
        return 'Free Plan';
    }
  }
}
