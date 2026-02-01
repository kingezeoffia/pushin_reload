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
  Future<bool> launchCheckout({
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

  Future<SubscriptionStatus?> getCachedSubscriptionStatus();

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
}

/// Payment Service Factory
///
/// Creates the appropriate payment service based on configuration
class PaymentServiceFactory {
  static PaymentService create({
    required PaymentMode mode,
    String? backendUrl,
  }) {
    switch (mode) {
      case PaymentMode.stripeLive:
        return StripeCheckoutService(
          baseUrl: backendUrl ?? 'https://api.pushinapp.com/api',
          isTestMode: false,
        ) as PaymentService;

      case PaymentMode.stripeTest:
        return StripeCheckoutService(
          baseUrl: backendUrl ?? 'https://your-test-backend.up.railway.app/api',
          isTestMode: true,
        ) as PaymentService;

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

/// Adapter to make MockPaymentService compatible with PaymentService interface
class MockPaymentServiceAdapter implements PaymentService {
  final MockPaymentService _mockService = MockPaymentService();

  @override
  Future<bool> launchCheckout({
    required String userId,
    required String planId,
    required String billingPeriod,
    required String userEmail,
  }) {
    return _mockService.launchMockCheckout(
      userId: userId,
      planId: planId,
      userEmail: userEmail,
    );
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
  Future<SubscriptionStatus?> getCachedSubscriptionStatus() {
    // Mock service needs userId, so this is not directly supported
    // In real usage, you'd pass userId through the app state
    throw UnimplementedError('Use checkSubscriptionStatus with userId instead');
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
  Future<RestorePurchaseResult> restoreSubscriptionByEmail({
    required String email,
  }) {
    return _mockService.restoreMockSubscriptionByEmail(email: email);
  }
}

/// Configuration Helper
class PaymentConfig {
  static PaymentMode get currentMode {
    // You can read this from environment variables, shared preferences, etc.
    const modeString =
        String.fromEnvironment('PAYMENT_MODE', defaultValue: 'mock');
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
    return const String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'https://pushin-production.up.railway.app/api',
    );
  }

  static PaymentService createService() {
    return PaymentServiceFactory.create(
      mode: currentMode,
      backendUrl: backendUrl,
    );
  }
}

/* USAGE EXAMPLES:

// 1. Using Configuration (Recommended)
final paymentService = PaymentConfig.createService();

// 2. Manual Configuration
final paymentService = PaymentServiceFactory.create(
  mode: PaymentMode.mock, // or PaymentMode.stripeTest
  backendUrl: 'https://your-backend-url/api',
);

// 3. Flutter Build Configuration
flutter run --dart-define=PAYMENT_MODE=stripe_test --dart-define=BACKEND_URL=https://test-api.example.com/api

// 4. Switch modes easily
// - Development: PaymentMode.mock or PaymentMode.stripeTest
// - Production: PaymentMode.stripeLive

*/

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
