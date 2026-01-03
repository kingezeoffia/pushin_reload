import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stripe Web Checkout Service
///
/// Handles external Stripe Checkout flow for subscriptions
/// - Creates checkout sessions via backend API
/// - Launches browser for payment
/// - Handles return deep links
/// - Stores subscription status locally
/// - Supports test mode for development
class StripeCheckoutService {
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
  /// In test mode without real keys, simulates the flow
  Future<bool> launchCheckout({
    required String userId,
    required String planId, // 'pro' or 'advanced'
    required String billingPeriod, // 'monthly' or 'yearly'
    required String userEmail,
  }) async {
    // TEST MODE SIMULATION: If no real Stripe keys, simulate the flow
    if (isTestMode && !baseUrl.contains('railway.app')) {
      return await _simulateTestCheckout(userId, planId, billingPeriod, userEmail);
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
        response = await http.post(
          Uri.parse('$baseUrl/stripe/create-checkout-session'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 30));
        print('🔵 StripeCheckoutService: HTTP POST completed');
      } catch (httpError) {
        print('❌ StripeCheckoutService: HTTP POST FAILED: $httpError');
        return false;
      }

      print('📡 StripeCheckoutService: Response status: ${response.statusCode}');
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
  Future<SubscriptionStatus?> verifyPayment({
    required String sessionId,
    required String userId,
  }) async {
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final status = SubscriptionStatus(
          isActive: data['isActive'] as bool,
          planId: data['planId'] as String,
          customerId: data['customerId'] as String?,
          subscriptionId: data['subscriptionId'] as String?,
          currentPeriodEnd: data['currentPeriodEnd'] != null
              ? DateTime.parse(data['currentPeriodEnd'] as String)
              : null,
        );

        // Store locally
        await _saveSubscriptionStatus(status);

        return status;
      } else {
        print('Failed to verify payment: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error verifying payment: $e');
      return null;
    }
  }

  /// Check current subscription status from backend
  Future<SubscriptionStatus?> checkSubscriptionStatus({
    required String userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stripe/subscription-status?userId=$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final status = SubscriptionStatus(
          isActive: data['isActive'] as bool,
          planId: data['planId'] as String,
          customerId: data['customerId'] as String?,
          subscriptionId: data['subscriptionId'] as String?,
          currentPeriodEnd: data['currentPeriodEnd'] != null
              ? DateTime.parse(data['currentPeriodEnd'] as String)
              : null,
        );

        // Update local cache
        await _saveSubscriptionStatus(status);

        return status;
      } else {
        print('Failed to check subscription status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error checking subscription status: $e');
      return null;
    }
  }

  /// Get locally cached subscription status
  Future<SubscriptionStatus?> getCachedSubscriptionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isActive = prefs.getBool('subscription_isActive') ?? false;
      final planId = prefs.getString('subscription_planId') ?? 'free';
      final customerId = prefs.getString('subscription_customerId');
      final subscriptionId = prefs.getString('subscription_subscriptionId');
      final periodEndStr = prefs.getString('subscription_periodEnd');

      return SubscriptionStatus(
        isActive: isActive,
        planId: planId,
        customerId: customerId,
        subscriptionId: subscriptionId,
        currentPeriodEnd:
            periodEndStr != null ? DateTime.tryParse(periodEndStr) : null,
      );
    } catch (e) {
      print('Error getting cached subscription: $e');
      return null;
    }
  }

  /// Save subscription status locally
  Future<void> _saveSubscriptionStatus(SubscriptionStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('subscription_isActive', status.isActive);
      await prefs.setString('subscription_planId', status.planId);

      if (status.customerId != null) {
        await prefs.setString('subscription_customerId', status.customerId!);
      }

      if (status.subscriptionId != null) {
        await prefs.setString(
            'subscription_subscriptionId', status.subscriptionId!);
      }

      if (status.currentPeriodEnd != null) {
        await prefs.setString('subscription_periodEnd',
            status.currentPeriodEnd!.toIso8601String());
      }

      print('Subscription status saved locally: ${status.planId}');
    } catch (e) {
      print('Error saving subscription status: $e');
    }
  }

  /// Cancel subscription (creates cancellation intent)
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

  /// Simulate Stripe Checkout for testing without real keys
  Future<bool> _simulateTestCheckout(
      String userId, String planId, String billingPeriod, String userEmail) async {
    try {
      print('TEST MODE: Simulating Stripe Checkout for $planId plan ($billingPeriod)');

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
}

/// Subscription Status Model
class SubscriptionStatus {
  final bool isActive;
  final String planId; // 'free', 'pro', 'advanced'
  final String? customerId;
  final String? subscriptionId;
  final DateTime? currentPeriodEnd;

  SubscriptionStatus({
    required this.isActive,
    required this.planId,
    this.customerId,
    this.subscriptionId,
    this.currentPeriodEnd,
  });

  bool get isPaid => planId != 'free' && isActive;
  bool get isPro => planId == 'pro' && isActive;
  bool get isAdvanced => planId == 'advanced' && isActive;

  String get displayName {
    switch (planId) {
      case 'pro':
      case 'pro':
        return 'Pro Plan';
      case 'advanced':
        return 'Advanced Plan';
      default:
        return 'Free Plan';
    }
  }
}
