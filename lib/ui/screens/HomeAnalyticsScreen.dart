import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/pushin_app_controller.dart';
import '../../domain/PushinState.dart';
import '../theme/pushin_theme.dart';
import '../widgets/analytics/StreakCard.dart';
import '../widgets/analytics/AnalyticsCards.dart';
import '../widgets/analytics/WeeklySummaryChart.dart';

/// Home/Dashboard screen with analytics and streak tracking
/// Shows streak data, usage analytics, and weekly summaries
class HomeAnalyticsScreen extends StatelessWidget {
  const HomeAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height, // At least full screen height
      ),
      decoration: const BoxDecoration(
        gradient: PushinTheme.surfaceGradient,
      ),
      child: SafeArea(
        child: Consumer<PushinAppController>(
          builder: (context, controller, _) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(PushinTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),

                  SizedBox(height: PushinTheme.spacingXl),

                  // Streak Card
                  const StreakCard(),

                  SizedBox(height: PushinTheme.spacingXl),

                  // Analytics Cards
                  const AnalyticsCards(),

                  SizedBox(height: PushinTheme.spacingXl),

                  // Weekly Summary Chart
                  const WeeklySummaryChart(),

                  SizedBox(height: PushinTheme.spacingXl),

                  // Current State Indicator (if applicable)
                  _buildCurrentStateIndicator(controller),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: PushinTheme.headline2,
        ),
        SizedBox(height: PushinTheme.spacingXs),
        Text(
          'Track your progress and habits',
          style: PushinTheme.body2,
        ),
      ],
    );
  }

  Widget _buildCurrentStateIndicator(PushinAppController controller) {
    final state = controller.currentState;
    final now = DateTime.now();

    String statusText;
    Color statusColor;

    switch (state) {
      case PushinState.locked:
        statusText = 'Apps Blocked - Complete workout to unlock';
        statusColor = PushinTheme.primaryBlue;
        break;
      case PushinState.earning:
        statusText = 'Workout in Progress';
        statusColor = PushinTheme.warningYellow;
        break;
      case PushinState.unlocked:
        final remaining = controller.getUnlockTimeRemaining(now);
        final minutes = remaining ~/ 60;
        final seconds = remaining % 60;
        statusText = 'Apps Unlocked - ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} remaining';
        statusColor = PushinTheme.successGreen;
        break;
      case PushinState.expired:
        statusText = 'Time Expired - Apps Blocked';
        statusColor = PushinTheme.errorRed;
        break;
    }

    return Container(
      padding: EdgeInsets.all(PushinTheme.spacingMd),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStateIcon(state),
            color: statusColor,
            size: 20,
          ),
          SizedBox(width: PushinTheme.spacingMd),
          Expanded(
            child: Text(
              statusText,
              style: PushinTheme.body2.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStateIcon(PushinState state) {
    switch (state) {
      case PushinState.locked:
        return Icons.lock;
      case PushinState.earning:
        return Icons.fitness_center;
      case PushinState.unlocked:
        return Icons.check_circle;
      case PushinState.expired:
        return Icons.timer_off;
    }
  }
}
