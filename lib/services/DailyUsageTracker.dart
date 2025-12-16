import 'package:hive_flutter/hive_flutter.dart';
import '../domain/DailyUsage.dart';

/// Service for tracking daily unlock time usage with local persistence.
///
/// Responsibilities:
/// - Track earned time from workouts
/// - Track consumed time (actual screen time usage)
/// - Enforce daily caps based on plan tier
/// - Automatic daily reset at midnight (local timezone)
/// - Persistent storage using Hive
///
/// Usage:
/// ```dart
/// final tracker = DailyUsageTracker();
/// await tracker.initialize();
///
/// // After workout completion
/// await tracker.addEarnedTime(600); // 10 minutes
///
/// // During unlock session
/// await tracker.consumeTime(60); // 1 minute consumed
///
/// // Check status
/// final usage = await tracker.getTodayUsage();
/// print(usage.remainingSeconds); // Available time left
/// ```
class DailyUsageTracker {
  static const String _boxName = 'daily_usage';
  static const String _currentPlanKey = 'current_plan';

  late Box<DailyUsage> _usageBox;
  late Box<String> _settingsBox;

  /// Initialize Hive storage.
  /// Must be called before any other methods.
  Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DailyUsageAdapter());
    }

    _usageBox = await Hive.openBox<DailyUsage>(_boxName);
    _settingsBox = await Hive.openBox<String>('pushin_settings');
  }

  /// Get today's date key (YYYY-MM-DD) in local timezone
  ///
  /// IMPORTANT: Uses local timezone, not UTC
  /// - Reset happens at midnight LOCAL time
  /// - Timezone changes will extend/shrink the "day"
  /// - This is intentional (matches user expectations)
  ///
  /// Edge Cases:
  /// - User travels across timezones: Day boundary shifts
  /// - User manually changes timezone: Tracked in analytics
  /// - DST transitions: Handled automatically by DateTime
  String _getTodayKey() {
    final now = DateTime.now(); // Local timezone
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Check if date key represents today (for validation)
  bool _isToday(dynamic dateInput) {
    final todayKey = _getTodayKey();

    if (dateInput is String) {
      return dateInput == todayKey;
    } else if (dateInput is DateTime) {
      final dateKey =
          '${dateInput.year}-${dateInput.month.toString().padLeft(2, '0')}-${dateInput.day.toString().padLeft(2, '0')}';
      return dateKey == todayKey;
    }

    return false;
  }

  /// Detect timezone changes (for analytics)
  ///
  /// Call this periodically to track if user changed timezone
  /// Returns true if timezone differs from last recorded timezone
  Future<bool> hasTimezoneChanged() async {
    final currentOffset = DateTime.now().timeZoneOffset.inMinutes;
    final storedOffsetStr = _settingsBox.get('timezone_offset');
    final storedOffset =
        storedOffsetStr != null ? int.tryParse(storedOffsetStr) : currentOffset;

    if (currentOffset != storedOffset) {
      // Timezone changed! Track in analytics
      await _settingsBox.put('timezone_offset', currentOffset.toString());
      await _settingsBox.put(
          'timezone_change_detected_at', DateTime.now().toIso8601String());
      return true;
    }

    return false;
  }

  /// Get current plan tier from storage
  String _getCurrentPlan() {
    return _settingsBox.get(_currentPlanKey, defaultValue: 'free') ?? 'free';
  }

  /// Update plan tier (called after subscription purchase)
  Future<void> updatePlanTier(String planTier) async {
    await _settingsBox.put(_currentPlanKey, planTier);

    // Update today's record with new plan
    final todayKey = _getTodayKey();
    final existing = _usageBox.get(todayKey);
    if (existing != null) {
      final updated = DailyUsage(
        date: existing.date,
        earnedSeconds: existing.earnedSeconds,
        consumedSeconds: existing.consumedSeconds,
        planTier: planTier,
        lastUpdated: DateTime.now(),
      );
      await _usageBox.put(todayKey, updated);
    }
  }

  /// Get or create today's usage record
  ///
  /// Handles daily reset logic:
  /// - Checks if midnight has passed since last access
  /// - Creates new record if needed
  /// - Validates data integrity
  Future<DailyUsage> getTodayUsage() async {
    final todayKey = _getTodayKey();
    var usage = _usageBox.get(todayKey);

    if (usage == null) {
      // First access today - create new record
      final planTier = _getCurrentPlan();
      usage = DailyUsage.today(planTier);
      await _usageBox.put(todayKey, usage);

      // Record midnight reset event (for analytics)
      await _settingsBox.put('last_reset_date', todayKey);
    } else {
      // Validate record is actually for today
      if (!_isToday(usage.date)) {
        // Data integrity issue - this shouldn't happen
        // Create new record and preserve old data
        final planTier = _getCurrentPlan();
        final newUsage = DailyUsage.today(planTier);
        await _usageBox.put(todayKey, newUsage);
        usage = newUsage;
      }
    }

    return usage;
  }

  /// Add earned time from completed workout
  ///
  /// Returns updated DailyUsage record
  Future<DailyUsage> addEarnedTime(int seconds) async {
    final usage = await getTodayUsage();
    usage.addEarnedTime(seconds);

    final todayKey = _getTodayKey();
    await _usageBox.put(todayKey, usage);

    return usage;
  }

  /// Consume unlock time (track actual screen time usage)
  ///
  /// Returns updated DailyUsage record
  Future<DailyUsage> consumeTime(int seconds) async {
    final usage = await getTodayUsage();
    usage.consumeTime(seconds);

    final todayKey = _getTodayKey();
    await _usageBox.put(todayKey, usage);

    return usage;
  }

  /// Check if user can unlock more time (hasn't hit daily cap)
  ///
  /// Returns true if:
  /// - Advanced plan (unlimited), OR
  /// - Consumed time < daily cap
  Future<bool> canUnlockMore() async {
    final usage = await getTodayUsage();
    return !usage.hasReachedDailyCap;
  }

  /// Get remaining unlock time available (considering daily cap)
  ///
  /// Returns seconds available, capped by plan tier limits
  Future<int> getRemainingAvailableSeconds() async {
    final usage = await getTodayUsage();

    // If unlimited plan, return all remaining earned time
    if (usage.dailyCapSeconds == -1) {
      return usage.remainingSeconds;
    }

    // Calculate how much cap space is left
    final capRemaining = usage.dailyCapSeconds - usage.consumedSeconds;

    // Return lesser of: earned remaining or cap remaining
    return capRemaining.clamp(0, usage.remainingSeconds);
  }

  /// Check if user has hit their daily cap (for paywall trigger)
  Future<bool> hasHitDailyCap() async {
    final usage = await getTodayUsage();
    return usage.hasReachedDailyCap;
  }

  /// Get usage history for past N days
  ///
  /// Useful for analytics dashboard (post-MVP)
  Future<List<DailyUsage>> getUsageHistory(int days) async {
    final history = <DailyUsage>[];
    final now = DateTime.now();

    for (var i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final usage = _usageBox.get(dateKey);
      if (usage != null) {
        history.add(usage);
      }
    }

    return history;
  }

  /// Clean up old usage records (keep last 30 days only)
  ///
  /// Should be called periodically to prevent storage bloat
  Future<void> cleanupOldRecords() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    final keysToDelete = <String>[];

    for (var key in _usageBox.keys) {
      try {
        final parts = key.toString().split('-');
        if (parts.length == 3) {
          final recordDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );

          if (recordDate.isBefore(cutoffDate)) {
            keysToDelete.add(key.toString());
          }
        }
      } catch (e) {
        // Invalid key format, skip
      }
    }

    for (var key in keysToDelete) {
      await _usageBox.delete(key);
    }
  }

  /// Reset today's usage (for testing/debugging only)
  Future<void> resetToday() async {
    final todayKey = _getTodayKey();
    await _usageBox.delete(todayKey);
  }

  /// Close Hive boxes (call on app dispose)
  Future<void> dispose() async {
    await _usageBox.close();
    await _settingsBox.close();
  }
}
