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
            'Workouts',
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
          'Workouts',
          style: PushinTheme.headline3,
        ),
        SizedBox(height: PushinTheme.spacingMd),

        // List of recent workouts
        ..._recentWorkouts.map((workout) => _buildWorkoutHistoryItem(
              workout: workout,
            )),
      ],
    );
  }

  Widget _buildWorkoutHistoryItem({
    required WorkoutHistory workout,
  }) {
    final modeColor = _getModeColor(workout.workoutMode);

    return Container(
      margin: EdgeInsets.only(bottom: PushinTheme.spacingMd),
      decoration: BoxDecoration(
        // Subtle gradient for a "glass" feel
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PushinTheme.surfaceDark,
            PushinTheme.surfaceDark.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20), // More modern, rounded corners
        // High-end hairline border
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(PushinTheme.spacingMd),
        child: Row(
          children: [
            // 1. ICON SECTION WITH AMBIENT GLOW
            _buildWorkoutIcon(workout.icon, modeColor),

            SizedBox(width: PushinTheme.spacingMd),

            // 2. PRIMARY INFO SECTION
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.displayName,
                    style: PushinTheme.body1.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildModeBadge(workout.workoutModeDisplay, modeColor),
                ],
              ),
            ),

            // 3. STATS SECTION (Right Aligned)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  workout.relativeTimeDisplay,
                  style: PushinTheme.caption.copyWith(
                    color: PushinTheme.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${workout.repsCompleted}',
                      style: PushinTheme.headline3.copyWith(
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'reps',
                      style: PushinTheme.caption.copyWith(
                        color: PushinTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  workout.earnedTimeDisplay,
                  style: PushinTheme.caption.copyWith(
                    color: PushinTheme.secondaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Modern Workout Icon with Glow Effect
  Widget _buildWorkoutIcon(IconData icon, Color modeColor) {
    return Container(
      padding: EdgeInsets.all(PushinTheme.spacingSm),
      decoration: BoxDecoration(
        color: modeColor.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        // The "Neon Glow" effect
        boxShadow: [
          BoxShadow(
            color: modeColor.withValues(alpha: 0.25),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: modeColor,
        size: 24,
      ),
    );
  }

  // Helper: Modern Pill Badge
  Widget _buildModeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: PushinTheme.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
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
