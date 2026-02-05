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
    required this.baseUrl,
    required this.isTestMode,
  });

  /// Create Stripe Checkout session and launch browser
  ///
  /// Returns PaymentResult based on launch status
  /// Requires authenticated user - userId must be provided
  @override
  Future<PaymentResult> launchCheckout({
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
         return PaymentFailure(
            message: 'Network error. Please check your connection.',
            code: 'network_error');
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
          // Return success indicating the flow started. 
          // Actual payment confirmation happens via deep link.
          return const PaymentSuccess(); 
        } else {
          print('Could not launch Stripe Checkout URL');
           return const PaymentFailure(
              message: 'Could not open payment page. Please try again.',
              code: 'launch_error');
        }
      } else {
        print('Failed to create checkout session: ${response.statusCode}');
        print('Response: ${response.body}');
        
        String errorMessage = 'Failed to initialize checkout.';
        try {
            final errorData = jsonDecode(response.body);
            if (errorData['message'] != null) {
                errorMessage = errorData['message'];
            }
        } catch (_) {}

        return PaymentFailure(
            message: errorMessage,
            code: 'server_error_${response.statusCode}');
      }
    } catch (e) {
      print('Error launching Stripe Checkout: $e');
      return const PaymentFailure(
          message: 'An unexpected error occurred.', code: 'unknown_error');
    }
  }
  
  // ... other methods ...

  /// Verify payment session with backend
  @override
  Future<SubscriptionStatus?> verifyPayment({
    required String sessionId,
    required String userId,
  }) async {
    try {
      print('🔵 StripeCheckoutService: Verifying payment session: $sessionId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/stripe/verify-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': sessionId,
          'userId': userId,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📡 StripeCheckoutService: Verify response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
         final status = SubscriptionStatus(
          isActive: data['isActive'] ?? false,
          planId: data['planId'] ?? 'free',
          customerId: data['customerId'],
          subscriptionId: data['subscriptionId'],
          currentPeriodEnd: data['currentPeriodEnd'] != null 
              ? DateTime.parse(data['currentPeriodEnd']) 
              : null,
          cachedUserId: userId,
          cancelAtPeriodEnd: data['cancelAtPeriodEnd'] ?? false,
        );
        
        await saveSubscriptionStatus(status);
        return status;
      }
    } catch (e) {
      print('❌ StripeCheckoutService: Error verifying payment: $e');
    }
    return null;
  }

  /// Check subscription status from backend
  @override
  Future<SubscriptionStatus?> checkSubscriptionStatus({
    required String userId,
  }) async {
    if (isTestMode && !baseUrl.contains('railway.app')) {
       // Return cached status in mock/test mode
       return await getCachedSubscriptionStatus(userId: userId);
    }
    
    try {
      // Use configured backend URL
      final response = await http.get(
        Uri.parse('$baseUrl/stripe/subscription-status/$userId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = SubscriptionStatus(
          isActive: data['isActive'] ?? false,
          planId: data['planId'] ?? 'free',
          customerId: data['customerId'],
          subscriptionId: data['subscriptionId'],
          currentPeriodEnd: data['currentPeriodEnd'] != null 
              ? DateTime.parse(data['currentPeriodEnd']) 
              : null,
          cachedUserId: userId,
          cancelAtPeriodEnd: data['cancelAtPeriodEnd'] ?? false,
        );

        print('📡 Server Subscription Status Detail:');
        print('   - isActive: ${status.isActive}');
        print('   - planId: ${status.planId}');
        print('   - expiry: ${status.currentPeriodEnd}');
        print('   - cancelAtPeriodEnd: ${status.cancelAtPeriodEnd}');
        
        // Update cache
        await saveSubscriptionStatus(status);
        return status;
      }
    } catch (e) {
      print('Error checking subscription status: $e');
      // Fallback to cache on error
      return await getCachedSubscriptionStatus(userId: userId);
    }
    return null;
  }

  @override
  Future<SubscriptionStatus?> getCachedSubscriptionStatus({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonStr;
      
      // Try user-specific cache first if userId provided
      if (userId != null) {
        jsonStr = prefs.getString('cached_subscription_status_$userId');
      }
      
      // Fallback to general cache
      jsonStr ??= prefs.getString('cached_subscription_status');
      
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr);
        return SubscriptionStatus(
          isActive: data['isActive'] ?? false,
          planId: data['planId'] ?? 'free',
          customerId: data['customerId'],
          subscriptionId: data['subscriptionId'],
          currentPeriodEnd: data['currentPeriodEnd'] != null 
              ? DateTime.parse(data['currentPeriodEnd']) 
              : null,
          cachedUserId: data['cachedUserId'],
          cancelAtPeriodEnd: data['cancelAtPeriodEnd'] ?? false,
        );
      }
      return null;
    } catch (e) {
      print('Error reading cached subscription: $e');
      return null;
    }
  }

  /// Cancel subscription
  @override
  Future<bool> cancelSubscription({
    required String userId,
    required String subscriptionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stripe/cancel-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'subscriptionId': subscriptionId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error cancelling subscription: $e');
      return false;
    }
  }
  
  /// Save subscription status to local cache (PUBLIC)
  Future<void> saveSubscriptionStatus(SubscriptionStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Serialize status to JSON
      final jsonMap = {
        'isActive': status.isActive,
        'planId': status.planId,
        'customerId': status.customerId,
        'subscriptionId': status.subscriptionId,
        'currentPeriodEnd': status.currentPeriodEnd?.toIso8601String(),
        'cachedUserId': status.cachedUserId,
        'cancelAtPeriodEnd': status.cancelAtPeriodEnd,
      };
      
      await prefs.setString('cached_subscription_status', jsonEncode(jsonMap));
      print('✅ StripeCheckoutService: Saved subscription status to cache (${status.planId})');
      
      // Also cache specifically for this user if userId is available
      if (status.cachedUserId != null) {
         await prefs.setString('cached_subscription_status_${status.cachedUserId}', jsonEncode(jsonMap));
      }
    } catch (e) {
      print('❌ StripeCheckoutService: Error saving subscription cache: $e');
    }
  }

  /// Simulate Stripe Checkout for testing without real keys
  Future<PaymentResult> _simulateTestCheckout(String userId, String planId,
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
      await saveSubscriptionStatus(simulatedStatus);

      print('TEST MODE: Payment simulated successfully');
      return const PaymentSuccess();
    } catch (e) {
      print('TEST MODE: Error simulating payment: $e');
      return const PaymentFailure(message: 'Simulation failed', code: 'test_error');
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
          await saveSubscriptionStatus(statusWithUserId);

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
              data['message'] as String? ?? 'No active subscription found for this email. Please check for typos.',
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

  /// Open Stripe Customer Portal
  @override
  Future<bool> openCustomerPortal({
    required String userId,
  }) async {
    // TEST MODE SIMULATION
    if (isTestMode && !baseUrl.contains('railway.app')) {
      print('TEST MODE: Simulating Customer Portal');
      await Future.delayed(const Duration(seconds: 1));
      return true; // Pretend we opened it
    }

    try {
      print('🔵 StripeCheckoutService: Opening customer portal for $userId');
      
      final response = await http.post(
        Uri.parse('$baseUrl/stripe/create-portal-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
        }),
      );

      print('📡 StripeCheckoutService: Portal response: ${response.statusCode}');
      print('   Body: ${response.body}'); // Debugging: Print full body

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend might return 'portalUrl' or just 'url'
        final url = (data['portalUrl'] ?? data['url']) as String?; // Safe nullable cast
        
        if (url != null) {
          final uri = Uri.parse(url);
          print('🔵 StripeCheckoutService: Launching portal URL: $url');
          print('   - LaunchMode: externalApplication (Platform browser)');
          
          if (await canLaunchUrl(uri)) {
             await launchUrl(uri, mode: LaunchMode.externalApplication);
             return true;
          }
        } else {
          print('❌ StripeCheckoutService: "portalUrl" is missing or null in response');
        }
      }
    } catch (e) {
      print('❌ StripeCheckoutService: Error opening portal: $e');
    }
    return false;
  }

  /// Reactivate subscription
  @override
  Future<bool> reactivateSubscription({
    required String userId,
    required String subscriptionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/stripe/reactivate-subscription'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'subscriptionId': subscriptionId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error reactivating subscription: $e');
      return false;
    }
  }
}


