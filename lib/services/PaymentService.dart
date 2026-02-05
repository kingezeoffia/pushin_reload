import 'StripeCheckoutService.dart';
import 'MockPaymentService.dart';

/// Unified Payment Service Interface
///
/// Supports multiple payment backends:
/// - Real Stripe (production)
/// - Stripe Test Mode (development)
/// - Mock Service (UI development)
///
/// Note: All payment methods require authenticated user (userId required)
abstract class PaymentService {
  Future<PaymentResult> launchCheckout({
    required String userId,
    required String planId,
    required String billingPeriod, // 'monthly' or 'yearly'
    required String userEmail,
  });

  Future<SubscriptionStatus?> verifyPayment({
    required String sessionId,
    required String userId,
  });

  Future<SubscriptionStatus?> checkSubscriptionStatus({
    required String userId,
  });

  Future<SubscriptionStatus?> getCachedSubscriptionStatus({String? userId});

  Future<bool> cancelSubscription({
    required String userId,
    required String subscriptionId,
  });

  /// Restore subscription by email verification
  ///
  /// Returns RestorePurchaseResult with subscription if active subscription found
  Future<RestorePurchaseResult> restoreSubscriptionByEmail({
    required String email,
  });

  /// Save subscription status to local cache
  Future<void> saveSubscriptionStatus(SubscriptionStatus status);

  /// Open external customer portal for subscription management
  Future<bool> openCustomerPortal({required String userId});

  /// Reactivate a cancelled subscription
  Future<bool> reactivateSubscription({
    required String userId,
    required String subscriptionId,
  });
}

/// Payment Service Factory
///
/// Creates the appropriate payment service based on configuration
class PaymentServiceFactory {
  static PaymentService create({
    required PaymentMode mode,
    required String backendUrl, // Backend URL is now REQUIRED
  }) {
    switch (mode) {
      case PaymentMode.stripeLive:
        return StripeCheckoutService(
          baseUrl: backendUrl,
          isTestMode: false,
        );

      case PaymentMode.stripeTest:
        return StripeCheckoutService(
          baseUrl: backendUrl,
          isTestMode: true,
        );

      case PaymentMode.mock:
        return MockPaymentServiceAdapter();
    }
  }
}

/// Payment Configuration Modes
enum PaymentMode {
  stripeLive, // Production Stripe
  stripeTest, // Stripe Test Mode
  mock, // Mock service for development
}

/// Result of a payment attempt
sealed class PaymentResult {
  const PaymentResult();
}

class PaymentSuccess extends PaymentResult {
  const PaymentSuccess();
}

class PaymentFailure extends PaymentResult {
  final String message;
  final String? code;
  
  const PaymentFailure({
    required this.message,
    this.code,
  });
}

class PaymentCancelled extends PaymentResult {
  const PaymentCancelled();
}


/// Adapter to make MockPaymentService compatible with PaymentService interface
class MockPaymentServiceAdapter implements PaymentService {
  final MockPaymentService _mockService = MockPaymentService();

  @override
  Future<PaymentResult> launchCheckout({
    required String userId,
    required String planId,
    required String billingPeriod,
    required String userEmail,
  }) async {
    final success = await _mockService.launchMockCheckout(
      userId: userId,
      planId: planId,
      userEmail: userEmail,
    );
    
    if (success) {
      return const PaymentSuccess();
    } else {
      return const PaymentFailure(message: 'Mock payment failed');
    }
  }

  @override
  Future<SubscriptionStatus?> verifyPayment({
    required String sessionId,
    required String userId,
  }) {
    return _mockService.verifyMockPayment(
      sessionId: sessionId,
      userId: userId,
    );
  }

  @override
  Future<SubscriptionStatus?> checkSubscriptionStatus({
    required String userId,
  }) {
    return _mockService.getCachedSubscriptionStatus(userId: userId);
  }

  @override
  Future<SubscriptionStatus?> getCachedSubscriptionStatus({String? userId}) {
    // Mock service needs userId, so this is not directly supported
    // In real usage, you'd pass userId through the app state
    // But we can try to return if mock service has a way, else null
    if (userId != null) {
       return _mockService.getCachedSubscriptionStatus(userId: userId);
    }
    return Future.value(null);
  }

  @override
  Future<bool> cancelSubscription({
    required String userId,
    required String subscriptionId,
  }) {
    return _mockService.cancelMockSubscription(
      userId: userId,
      subscriptionId: subscriptionId,
    );
  }
  
  @override
  Future<void> saveSubscriptionStatus(SubscriptionStatus status) async {
     // Mock service likely handles this internally or we can just ignore
     // OR ideally implement it if we want consistency.
     // For now, no-op or simple print
     print('MockPaymentServiceAdapter: saveSubscriptionStatus called (no-op)');
  }

  @override
  Future<RestorePurchaseResult> restoreSubscriptionByEmail({
    required String email,
  }) {
    return _mockService.restoreMockSubscriptionByEmail(email: email);
  }

  @override
  Future<bool> openCustomerPortal({required String userId}) async {
    print('MockPaymentServiceAdapter: openCustomerPortal called (simulated)');
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  @override
  Future<bool> reactivateSubscription({
    required String userId,
    required String subscriptionId,
  }) async {
    print('MockPaymentServiceAdapter: reactivateSubscription called (simulated)');
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }
}

/// Configuration Helper
class PaymentConfig {
  static PaymentMode get currentMode {
    const modeString =
        String.fromEnvironment('PAYMENT_MODE', defaultValue: 'stripe_test');
    switch (modeString) {
      case 'stripe_live':
        return PaymentMode.stripeLive;
      case 'stripe_test':
        return PaymentMode.stripeTest;
      case 'mock':
      default:
        return PaymentMode.mock;
    }
  }

  static String get backendUrl {
    // Default to production URL if not specified, BUT force user to check this
    // for production builds.
    const url = String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'https://pushin-production.up.railway.app/api',
    );
    
    if (url.isEmpty) {
       // Fallback or throw error depending on strictness
       return 'https://pushin-production.up.railway.app/api'; 
    }
    return url;
  }

  static PaymentService createService() {
    return PaymentServiceFactory.create(
      mode: currentMode,
      backendUrl: backendUrl,
    );
  }
}

/// Result of restore purchase attempt
class RestorePurchaseResult {
  final bool success;
  final SubscriptionStatus? subscription;
  final String?
      errorCode; // 'invalid_email', 'no_active_subscription', 'rate_limit_exceeded', etc.
  final String? errorMessage;
  final List<ExpiredSubscription>? expiredSubscriptions;

  RestorePurchaseResult({
    required this.success,
    this.subscription,
    this.errorCode,
    this.errorMessage,
    this.expiredSubscriptions,
  });

  bool get hasActiveSubscription => success && subscription != null;
  bool get hasExpiredSubscriptions =>
      expiredSubscriptions != null && expiredSubscriptions!.isNotEmpty;
}

/// Expired subscription information
class ExpiredSubscription {
  final String planId;
  final DateTime expiredOn;

  ExpiredSubscription({
    required this.planId,
    required this.expiredOn,
  });

  factory ExpiredSubscription.fromJson(Map<String, dynamic> json) {
    return ExpiredSubscription(
      planId: json['planId'] as String,
      expiredOn: DateTime.parse(json['expiredOn'] as String),
    );
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
