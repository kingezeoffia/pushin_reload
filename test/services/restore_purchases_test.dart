import 'package:flutter_test/flutter_test.dart';
import 'package:pushin_reload/services/MockPaymentService.dart';
import 'package:pushin_reload/services/PaymentService.dart';

void main() {
  group('Restore Purchases Tests', () {
    late MockPaymentService mockService;

    setUp(() {
      mockService = MockPaymentService();
    });

    test('Valid email with active Pro subscription', () async {
      final result = await mockService.restoreMockSubscriptionByEmail(
        email: 'pro@test.com',
      );

      expect(result.success, true);
      expect(result.subscription, isNotNull);
      expect(result.subscription!.planId, 'pro');
      expect(result.subscription!.isActive, true);
      expect(result.hasActiveSubscription, true);
    });

    test('Valid email with active Advanced subscription', () async {
      final result = await mockService.restoreMockSubscriptionByEmail(
        email: 'advanced@test.com',
      );

      expect(result.success, true);
      expect(result.subscription, isNotNull);
      expect(result.subscription!.planId, 'advanced');
      expect(result.subscription!.isActive, true);
      expect(result.hasActiveSubscription, true);
    });

    test('Valid email with no subscription', () async {
      final result = await mockService.restoreMockSubscriptionByEmail(
        email: 'nosub@test.com',
      );

      expect(result.success, false);
      expect(result.errorCode, 'no_active_subscription');
      expect(result.subscription, isNull);
      expect(result.hasActiveSubscription, false);
    });

    test('Valid email with expired subscription', () async {
      final result = await mockService.restoreMockSubscriptionByEmail(
        email: 'expired@test.com',
      );

      expect(result.success, false);
      expect(result.errorCode, 'no_active_subscription');
      expect(result.subscription, isNull);
      expect(result.expiredSubscriptions, isNotEmpty);
      expect(result.expiredSubscriptions!.first.planId, 'pro');
      expect(result.hasActiveSubscription, false);
      expect(result.hasExpiredSubscriptions, true);
    });

    test('Invalid email format', () async {
      final result = await mockService.restoreMockSubscriptionByEmail(
        email: 'notanemail',
      );

      expect(result.success, false);
      expect(result.errorCode, 'invalid_email');
      expect(result.subscription, isNull);
    });

    test('Empty email', () async {
      final result = await mockService.restoreMockSubscriptionByEmail(
        email: '',
      );

      expect(result.success, false);
      expect(result.errorCode, 'invalid_email');
      expect(result.subscription, isNull);
    });

    test('Email with spaces (trimmed)', () async {
      final result = await mockService.restoreMockSubscriptionByEmail(
        email: '  pro@test.com  ',
      );

      // Should trim and work correctly
      expect(result.success, true);
      expect(result.subscription, isNotNull);
      expect(result.subscription!.planId, 'pro');
    });

    test('Email with uppercase (normalized)', () async {
      final result = await mockService.restoreMockSubscriptionByEmail(
        email: 'PRO@TEST.COM',
      );

      // Should normalize to lowercase and work
      expect(result.success, true);
      expect(result.subscription, isNotNull);
      expect(result.subscription!.planId, 'pro');
    });

    test('Test email test@pushinapp.com returns Pro subscription', () async {
      final result = await mockService.restoreMockSubscriptionByEmail(
        email: 'test@pushinapp.com',
      );

      expect(result.success, true);
      expect(result.subscription, isNotNull);
      expect(result.subscription!.planId, 'pro');
      expect(result.subscription!.customerId, 'cus_mock_test');
    });

    test('RestorePurchaseResult getters work correctly', () async {
      // Test with successful restore
      final successResult = await mockService.restoreMockSubscriptionByEmail(
        email: 'pro@test.com',
      );

      expect(successResult.hasActiveSubscription, true);
      expect(successResult.hasExpiredSubscriptions, false);

      // Test with expired subscription
      final expiredResult = await mockService.restoreMockSubscriptionByEmail(
        email: 'expired@test.com',
      );

      expect(expiredResult.hasActiveSubscription, false);
      expect(expiredResult.hasExpiredSubscriptions, true);

      // Test with no subscription
      final noSubResult = await mockService.restoreMockSubscriptionByEmail(
        email: 'nosub@test.com',
      );

      expect(noSubResult.hasActiveSubscription, false);
      expect(noSubResult.hasExpiredSubscriptions, false);
    });
  });
}
