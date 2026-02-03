import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/screens/rating/RatingScreen.dart';

/// Service to handle app rating logic
class RatingService {
  static const String _prefsKeyHasRated = 'has_rated_app';
  static const String _prefsKeyLaunchCount = 'app_launch_count';
  static const String _prefsKeyWorkoutCount = 'completed_workout_count';

  final SharedPreferences _prefs;

  RatingService(this._prefs);

  static Future<RatingService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return RatingService(prefs);
  }

  // --- State Accessors ---

  bool get hasRated => _prefs.getBool(_prefsKeyHasRated) ?? false;

  int get launchCount => _prefs.getInt(_prefsKeyLaunchCount) ?? 0;

  int get workoutCount => _prefs.getInt(_prefsKeyWorkoutCount) ?? 0;

  // --- Actions ---

  /// Increment app launch count. Should be called once per app session.
  Future<void> incrementLaunchCount() async {
    final current = launchCount;
    await _prefs.setInt(_prefsKeyLaunchCount, current + 1);
    debugPrint('⭐ RatingService: Launch count incremented to ${current + 1}');
  }

  /// Increment workout count. Should be called when a workout is completed.
  Future<void> incrementWorkoutCount() async {
    final current = workoutCount;
    await _prefs.setInt(_prefsKeyWorkoutCount, current + 1);
    debugPrint('⭐ RatingService: Workout count incremented to ${current + 1}');
  }

  /// Mark the app as rated.
  Future<void> markAsRated() async {
    await _prefs.setBool(_prefsKeyHasRated, true);
    debugPrint('⭐ RatingService: App marked as rated');
  }

  // --- Triggers ---

  /// Show rating screen if user hasn't rated yet.
  /// Returns immediately if conditions aren't met.
  /// Returns a Future that completes when the dialog/screen is closed.
  Future<void> showRatingIfNeeded(BuildContext context, {bool force = false}) async {
    if (hasRated && !force) {
      debugPrint('⭐ RatingService: User already rated, skipping');
      return;
    }

    debugPrint('⭐ RatingService: Showing rating screen');
    
    // We navigate to the rating screen
    // Using push (not pushReplacement) so we can return to where we were
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RatingScreen(
          onContinue: () {
             Navigator.of(context).pop();
          },
        ),
        fullscreenDialog: true,
      ),
    );
     
    // Mark as rated after the screen is closed (regardless of whether they actually submitted or skipped, 
    // we don't want to pester them immediately again)
    // NOTE: In a more complex implementation, we might check if they actually submitted vs closed.
    // But usually "Stop asking" is safetiest UX.
    // The RatingScreen itself handles calling markAsRated(), but doing it here as a backup isn't bad.
    // For now, relies on RatingScreen to call markAsRated() on submit/skip.
  }

  /// Check conditions for "Second App Launch" trigger
  Future<void> checkAppLaunchRating(BuildContext context) async {
    debugPrint('⭐ RatingService: checkAppLaunchRating called (launchCount: $launchCount, hasRated: $hasRated)');
    if (hasRated) {
      debugPrint('⭐ RatingService: User already rated, skipping');
      return;
    }

    // Launch count is incremented *before* this check typically
    // "Second time" means launchCount == 2.
    if (launchCount == 2) {
       debugPrint('⭐ RatingService: ✅ Triggering rating due to 2nd app launch');
       await showRatingIfNeeded(context);
    } else {
      debugPrint('⭐ RatingService: Not 2nd launch (count: $launchCount), skipping');
    }
  }

  /// Check conditions for "First Workout" trigger
  Future<void> checkWorkoutRating(BuildContext context) async {
    debugPrint('⭐ RatingService: checkWorkoutRating called (workoutCount: $workoutCount, hasRated: $hasRated)');
    if (hasRated) {
      debugPrint('⭐ RatingService: User already rated, skipping');
      return;
    }

    // "First workout" means workoutCount == 1 (after increment)
    if (workoutCount == 1) {
      debugPrint('⭐ RatingService: ✅ Triggering rating due to 1st workout');
      await showRatingIfNeeded(context);
    } else {
      debugPrint('⭐ RatingService: Not the 1st workout (count: $workoutCount), skipping');
    }
  }

  /// Check conditions for "New Subscription" trigger
  /// Always ask if they just subscribed (and haven't rated), as they are happy users.
  Future<void> checkSubscriptionRating(BuildContext context) async {
    if (hasRated) return;
    
    debugPrint('⭐ RatingService: Triggering rating due to new subscription');
    await showRatingIfNeeded(context);
  }
}
