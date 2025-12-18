import 'StripeCheckoutService.dart';
import 'MockPaymentService.dart';

/// Unified Payment Service Interface
///
/// Supports multiple payment backends:
/// - Real Stripe (production)
/// - Stripe Test Mode (development)
/// - Mock Service (UI development)
abstract class PaymentService {
  Future<bool> launchCheckout({
    required String userId,
    required String planId,
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
        );

      case PaymentMode.stripeTest:
        return StripeCheckoutService(
          baseUrl: backendUrl ?? 'https://your-test-backend.up.railway.app/api',
          isTestMode: true,
        );

      case PaymentMode.mock:
        return MockPaymentServiceAdapter();
    }
  }
}

/// Payment Configuration Modes
enum PaymentMode {
  stripeLive,    // Production Stripe
  stripeTest,    // Stripe Test Mode
  mock,         // Mock service for development
}

/// Adapter to make MockPaymentService compatible with PaymentService interface
class MockPaymentServiceAdapter implements PaymentService {
  final MockPaymentService _mockService = MockPaymentService();

  @override
  Future<bool> launchCheckout({
    required String userId,
    required String planId,
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
}

/// Configuration Helper
class PaymentConfig {
  static PaymentMode get currentMode {
    // You can read this from environment variables, shared preferences, etc.
    const modeString = String.fromEnvironment('PAYMENT_MODE', defaultValue: 'mock');
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



















