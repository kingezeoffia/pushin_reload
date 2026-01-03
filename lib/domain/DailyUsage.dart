import 'package:hive/hive.dart';

part 'DailyUsage.g.dart';

/// Domain model for tracking daily unlock time usage.
///
/// Stores:
/// - Date of usage (for daily reset at midnight)
/// - Total unlocked seconds earned (from workouts)
/// - Total unlocked seconds consumed (actual screen time used)
/// - Plan tier (for enforcing daily caps)
///
/// Usage:
/// - Free plan: 1 hour (3600s) daily cap
/// - Pro plan: 3 hours (10800s) daily cap
/// - Advanced plan: Unlimited
@HiveType(typeId: 0)
class DailyUsage extends HiveObject {
  /// Date of this usage record (YYYY-MM-DD format, local timezone)
  @HiveField(0)
  final String date;

  /// Total seconds earned from completed workouts today
  @HiveField(1)
  int earnedSeconds;

  /// Total seconds consumed (actual unlock time used)
  @HiveField(2)
  int consumedSeconds;

  /// User's plan tier (free, standard, advanced)
  @HiveField(3)
  final String planTier;

  /// Timestamp of last update (for debugging/analytics)
  @HiveField(4)
  DateTime lastUpdated;

  DailyUsage({
    required this.date,
    this.earnedSeconds = 0,
    this.consumedSeconds = 0,
    required this.planTier,
    required this.lastUpdated,
  });

  /// Remaining unlocked seconds available to use
  int get remainingSeconds => earnedSeconds - consumedSeconds;

  /// Daily cap in seconds based on plan tier
  int get dailyCapSeconds {
    switch (planTier.toLowerCase()) {
      case 'free':
        return 3600; // 1 hour
      case 'pro':
        return 10800; // 3 hours
      case 'advanced':
        return -1; // Unlimited
      default:
        return 3600; // Default to free tier
    }
  }

  /// Whether user has reached their daily cap
  bool get hasReachedDailyCap {
    if (dailyCapSeconds == -1) return false; // Unlimited
    return consumedSeconds >= dailyCapSeconds;
  }

  /// Percentage of daily cap consumed (0.0 to 1.0)
  /// Returns 0.0 for unlimited plans
  double get dailyCapProgress {
    if (dailyCapSeconds == -1) return 0.0; // Unlimited
    return (consumedSeconds / dailyCapSeconds).clamp(0.0, 1.0);
  }

  /// Add earned seconds from a completed workout
  void addEarnedTime(int seconds) {
    earnedSeconds += seconds;
    lastUpdated = DateTime.now();
  }

  /// Consume unlock time (track actual usage)
  void consumeTime(int seconds) {
    consumedSeconds += seconds;
    lastUpdated = DateTime.now();
  }

  /// Create today's usage record for a given plan
  factory DailyUsage.today(String planTier) {
    final now = DateTime.now();
    final dateString =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return DailyUsage(
      date: dateString,
      planTier: planTier,
      lastUpdated: now,
    );
  }

  @override
  String toString() {
    return 'DailyUsage(date: $date, earned: $earnedSeconds, consumed: $consumedSeconds, plan: $planTier)';
  }
}


































