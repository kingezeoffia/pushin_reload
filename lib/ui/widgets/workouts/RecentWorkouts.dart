import 'package:flutter/material.dart';
import '../../theme/pushin_theme.dart';

/// Recent workouts list showing past workout history
class RecentWorkouts extends StatelessWidget {
  const RecentWorkouts({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workouts',
          style: PushinTheme.headline3,
        ),
        SizedBox(height: PushinTheme.spacingMd),

        // List of recent workouts
        _buildWorkoutHistoryItem(
          date: 'Today',
          workout: 'Push-ups',
          reps: 20,
          reward: '15 min',
          mode: 'Normal',
          modeColor: PushinTheme.primaryBlue,
        ),

        SizedBox(height: PushinTheme.spacingSm),

        _buildWorkoutHistoryItem(
          date: 'Yesterday',
          workout: 'Squats',
          reps: 25,
          reward: '12 min',
          mode: 'Tuff',
          modeColor: PushinTheme.warningYellow,
        ),

        SizedBox(height: PushinTheme.spacingSm),

        _buildWorkoutHistoryItem(
          date: '2 days ago',
          workout: 'Push-ups',
          reps: 15,
          reward: '10 min',
          mode: 'Cozy',
          modeColor: PushinTheme.successGreen,
        ),
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
          // Workout icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: modeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(PushinTheme.radiusSm),
            ),
            child: Icon(
              _getWorkoutIcon(workout),
              color: modeColor,
              size: 20,
            ),
          ),

          SizedBox(width: PushinTheme.spacingMd),

          // Workout details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      workout,
                      style: PushinTheme.body1.copyWith(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: PushinTheme.spacingSm),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: PushinTheme.spacingXs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: modeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(PushinTheme.radiusSm),
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

  IconData _getWorkoutIcon(String workout) {
    switch (workout.toLowerCase()) {
      case 'push-ups':
        return Icons.fitness_center;
      case 'squats':
        return Icons.airline_seat_legroom_normal;
      default:
        return Icons.sports_gymnastics;
    }
  }
}







