import 'package:shared_preferences/shared_preferences.dart';

/// Mock Payment Service for UI Development
///
/// Completely independent of backend - perfect for:
/// - UI prototyping
/// - User flow testing
/// - Feature development without API dependencies
/// - App store submissions during legal setup
class MockPaymentService {
  static const String _mockSessionPrefix = 'mock_session_';
  static const String _subscriptionPrefix = 'mock_sub_';

  /// Simulate launching payment checkout
  ///
  /// Shows a fake "payment processing" dialog and simulates success
  Future<bool> launchMockCheckout({
    required String userId,
    required String planId, // 'pro' or 'advanced'
    required String userEmail,
    Duration processingDelay = const Duration(seconds: 3),
  }) async {
    try {
      print('MOCK: Starting checkout simulation for $planId plan');

      // Simulate payment processing delay
      await Future.delayed(processingDelay);

      // Generate mock session ID
      final sessionId =
          '$_mockSessionPrefix${DateTime.now().millisecondsSinceEpoch}';

      // Create mock subscription
      final subscription = MockSubscription(
        id: '$_subscriptionPrefix${userId}_${planId}',
        userId: userId,
        planId: planId,
        status: 'active',
        customerEmail: userEmail,
        createdAt: DateTime.now(),
        currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
        cancelAtPeriodEnd: false,
      );

      // Save to local storage
      await _saveMockSubscription(subscription);

      print('MOCK: Payment completed successfully');
      print('   Session ID: $sessionId');
      print('   Subscription: ${subscription.id}');

      return true;
    } catch (e) {
      print('MOCK: Payment simulation failed: $e');
      return false;
    }
  }

  /// Simulate payment verification after "checkout"
  Future<SubscriptionStatus?> verifyMockPayment({
    required String sessionId,
    required String userId,
  }) async {
    try {
      print('MOCK: Verifying payment for session $sessionId');

      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));

      // Get stored subscription
      final subscription = await _getMockSubscription(userId);
      if (subscription == null) {
        print('MOCK: No subscription found for user $userId');
        return null;
      }

      final status = SubscriptionStatus(
        isActive: subscription.status == 'active',
        planId: subscription.planId,
        customerId: 'cus_mock_${userId}',
        subscriptionId: subscription.id,
        currentPeriodEnd: subscription.currentPeriodEnd,
      );

      print('MOCK: Payment verified');
      return status;
    } catch (e) {
      print('MOCK: Payment verification failed: $e');
      return null;
    }
  }

  /// Get cached subscription status
  Future<SubscriptionStatus?> getCachedSubscriptionStatus({
    required String userId,
  }) async {
    try {
      final subscription = await _getMockSubscription(userId);
      if (subscription == null) return null;

      return SubscriptionStatus(
        isActive: subscription.status == 'active',
        planId: subscription.planId,
        customerId: 'cus_mock_${userId}',
        subscriptionId: subscription.id,
        currentPeriodEnd: subscription.currentPeriodEnd,
      );
    } catch (e) {
      print('MOCK: Error getting cached status: $e');
      return null;
    }
  }

  /// Simulate subscription cancellation
  Future<bool> cancelMockSubscription({
    required String userId,
    required String subscriptionId,
  }) async {
    try {
      print('MOCK: Cancelling subscription $subscriptionId');

      final subscription = await _getMockSubscription(userId);
      if (subscription == null) return false;

      // Mark as cancelled at period end
      final updatedSubscription = subscription.copyWith(
        cancelAtPeriodEnd: true,
      );

      await _saveMockSubscription(updatedSubscription);
      print('MOCK: Subscription cancelled (effective at period end)');

      return true;
    } catch (e) {
      print('MOCK: Error cancelling subscription: $e');
      return false;
    }
  }

  /// Clear all mock data (for testing)
  Future<void> clearMockData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith('mock_')) {
          await prefs.remove(key);
        }
      }

      print('MOCK: All mock data cleared');
    } catch (e) {
      print('MOCK: Error clearing data: $e');
    }
  }

  // Private helper methods

  Future<void> _saveMockSubscription(MockSubscription subscription) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mock_sub_${subscription.userId}';
    final data = subscription.toJson();
    await prefs.setString(key, data);
  }

  Future<MockSubscription?> _getMockSubscription(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'mock_sub_$userId';
    final data = prefs.getString(key);
    if (data == null) return null;

    return MockSubscription.fromJson(data);
  }
}

/// Mock subscription data model
class MockSubscription {
  final String id;
  final String userId;
  final String planId;
  final String status;
  final String customerEmail;
  final DateTime createdAt;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;

  MockSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    required this.customerEmail,
    required this.createdAt,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
  });

  MockSubscription copyWith({
    String? id,
    String? userId,
    String? planId,
    String? status,
    String? customerEmail,
    DateTime? createdAt,
    DateTime? currentPeriodEnd,
    bool? cancelAtPeriodEnd,
  }) {
    return MockSubscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planId: planId ?? this.planId,
      status: status ?? this.status,
      customerEmail: customerEmail ?? this.customerEmail,
      createdAt: createdAt ?? this.createdAt,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
    );
  }

  String toJson() {
    return '{"id":"$id","userId":"$userId","planId":"$planId","status":"$status","customerEmail":"$customerEmail","createdAt":"${createdAt.toIso8601String()}","currentPeriodEnd":"${currentPeriodEnd.toIso8601String()}","cancelAtPeriodEnd":$cancelAtPeriodEnd}';
  }

  static MockSubscription fromJson(String json) {
    final data = json
        .substring(1, json.length - 1)
        .split(',')
        .fold<Map<String, String>>({}, (map, pair) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final key = parts[0].replaceAll('"', '');
        final value = parts[1].replaceAll('"', '');
        map[key] = value;
      }
      return map;
    });

    return MockSubscription(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      planId: data['planId'] ?? '',
      status: data['status'] ?? '',
      customerEmail: data['customerEmail'] ?? '',
      createdAt:
          DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
      currentPeriodEnd: DateTime.parse(
          data['currentPeriodEnd'] ?? DateTime.now().toIso8601String()),
      cancelAtPeriodEnd: data['cancelAtPeriodEnd'] == 'true',
    );
  }
}

/// Subscription Status Model (same as in StripeCheckoutService)
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
        return 'Pro Plan';
      case 'advanced':
        return 'Advanced Plan';
      default:
        return 'Free Plan';
    }
  }
}
