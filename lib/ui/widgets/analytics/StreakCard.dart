import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/pushin_theme.dart';
import '../../../state/pushin_app_controller.dart';

/// Streak card showing current and best streak with progress ring
class StreakCard extends StatefulWidget {
  const StreakCard({super.key});

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  late Map<String, dynamic> _streakData;

  @override
  void initState() {
    super.initState();
    // Cache the data ONCE when widget is created
    final controller = context.read<PushinAppController>();
    _streakData = {
      'currentStreak': controller.getCurrentStreak(),
      'bestStreak': controller.getBestStreak(),
      'todayCompleted': controller.isTodayCompleted(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentStreak = _streakData['currentStreak'] as int;
    final bestStreak = _streakData['bestStreak'] as int;
    final todayCompleted = _streakData['todayCompleted'] as bool;

    return Container(
      padding: EdgeInsets.all(PushinTheme.spacingLg),
      decoration: BoxDecoration(
        color: PushinTheme.surfaceDark,
        borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        boxShadow: PushinTheme.cardShadow,
      ),
      child: Row(
        children: [
          // Progress Ring
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: todayCompleted ? 1.0 : 0.0,
                    strokeWidth: 8,
                    backgroundColor: PushinTheme.surfaceDark.withOpacity(0.5),
                    valueColor: const AlwaysStoppedAnimation(
                        PushinTheme.successGreen),
                  ),
                ),
                const Icon(
                  Icons.local_fire_department,
                  color: PushinTheme.successGreen,
                  size: 32,
                ),
              ],
            ),
          ),

          SizedBox(width: PushinTheme.spacingLg),

          // Streak Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Streak',
                  style: PushinTheme.body2,
                ),
                SizedBox(height: PushinTheme.spacingXs),
                Text(
                  '$currentStreak days',
                  style: PushinTheme.headline2.copyWith(
                    fontSize: 28,
                    color: PushinTheme.successGreen,
                  ),
                ),
                SizedBox(height: PushinTheme.spacingSm),
                Text(
                  'Best: $bestStreak days',
                  style: PushinTheme.caption.copyWith(
                    color: PushinTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Status indicator
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: PushinTheme.spacingMd,
              vertical: PushinTheme.spacingXs,
            ),
            decoration: BoxDecoration(
              color: todayCompleted
                  ? PushinTheme.successGreen.withOpacity(0.2)
                  : PushinTheme.warningYellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(PushinTheme.radiusSm),
            ),
            child: Text(
              todayCompleted ? 'Complete' : 'Incomplete',
              style: TextStyle(
                color: todayCompleted
                    ? PushinTheme.successGreen
                    : PushinTheme.warningYellow,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

