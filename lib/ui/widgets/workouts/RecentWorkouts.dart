import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/pushin_theme.dart';
import '../../../services/WorkoutHistoryService.dart';
import '../../../domain/WorkoutHistory.dart';
import '../../../state/pushin_app_controller.dart';

/// Recent workouts list showing past workout history
class RecentWorkouts extends StatefulWidget {
  const RecentWorkouts({super.key});

  @override
  State<RecentWorkouts> createState() => _RecentWorkoutsState();
}

class _RecentWorkoutsState extends State<RecentWorkouts> {
  final WorkoutHistoryService _historyService = WorkoutHistoryService();
  List<WorkoutHistory> _recentWorkouts = [];
  bool _isLoading = true;
  late PushinAppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<PushinAppController>();
    _controller.addListener(_onWorkoutCompleted);
    _loadWorkoutHistory();
  }

  @override
  void dispose() {
    _controller.removeListener(_onWorkoutCompleted);
    super.dispose();
  }

  void _onWorkoutCompleted() {
    // Reload workout history when controller notifies of changes
    _loadWorkoutHistory();
  }

  Future<void> _loadWorkoutHistory() async {
    try {
      await _historyService.initialize();
      final workouts = await _historyService.getRecentWorkouts(limit: 3);
      if (mounted) {
        setState(() {
          _recentWorkouts = workouts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading workout history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_recentWorkouts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Workouts',
            style: PushinTheme.headline3,
          ),
          SizedBox(height: PushinTheme.spacingMd),
          Container(
            padding: EdgeInsets.all(PushinTheme.spacingMd),
            decoration: BoxDecoration(
              color: PushinTheme.surfaceDark,
              borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
            ),
            child: Center(
              child: Text(
                'No workouts completed yet.\nComplete your first workout to see history here!',
                style: PushinTheme.body2.copyWith(
                  color: PushinTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Workouts',
          style: PushinTheme.headline3,
        ),
        SizedBox(height: PushinTheme.spacingMd),

        // List of recent workouts
        ..._recentWorkouts.map((workout) => Padding(
              padding: EdgeInsets.only(bottom: PushinTheme.spacingSm),
              child: _buildWorkoutHistoryItem(
                date: workout.relativeTimeDisplay,
                workout: workout.displayName,
                reps: workout.repsCompleted,
                reward: workout.earnedTimeDisplay,
                mode: workout.workoutModeDisplay,
                modeColor: _getModeColor(workout.workoutMode),
              ),
            )),
      ],
    );
  }

  Widget _buildWorkoutHistoryItem({
    required String date,
    required String workout,
    required int reps,
    required String reward,
    required String mode,
    required Color modeColor,
  }) {
    return Container(
      padding: EdgeInsets.all(PushinTheme.spacingMd),
      decoration: BoxDecoration(
        color: PushinTheme.surfaceDark,
        borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        boxShadow: PushinTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Workout details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      workout,
                      style: PushinTheme.body1
                          .copyWith(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: PushinTheme.spacingSm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: PushinTheme.spacingXs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: modeColor.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(PushinTheme.radiusSm),
                      ),
                      child: Text(
                        mode,
                        style: PushinTheme.caption.copyWith(
                          color: modeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: PushinTheme.spacingXs),
                Text(
                  '$reps reps • $reward unlocked',
                  style: PushinTheme.caption.copyWith(
                    color: PushinTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Date
          Text(
            date,
            style: PushinTheme.caption.copyWith(
              color: PushinTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'cozy':
        return const Color(0xFF10B981); // Green
      case 'normal':
        return const Color(0xFF3B82F6); // Blue
      case 'tuff':
        return const Color(0xFFF59E0B); // Orange
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

}
