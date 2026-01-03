import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/pushin_theme.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../domain/DailyUsage.dart';

/// Weekly summary chart showing progress over the past 7 days
class WeeklySummaryChart extends StatefulWidget {
  const WeeklySummaryChart({super.key});

  @override
  State<WeeklySummaryChart> createState() => _WeeklySummaryChartState();
}

class _WeeklySummaryChartState extends State<WeeklySummaryChart> {
  late Future<List<DailyUsage>> _weeklyData;

  @override
  void initState() {
    super.initState();
    // Cache the future ONCE when widget is created
    final controller = context.read<PushinAppController>();
    _weeklyData = controller.getWeeklyUsage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DailyUsage>>(
      future: _weeklyData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error loading weekly data'));
        }

        final weeklyData = snapshot.data!;
        final now = DateTime.now();

        // Calculate completion stats
        int completedDays = 0;

        final chartBars = <Widget>[];

        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final dayName = _getDayName(date.weekday);
          final usage = weeklyData[i];

          // Determine progress level and color
          double progress = usage.dailyCapProgress;
          Color color;

          if (progress >= 1.0) {
            color = PushinTheme.successGreen;
            completedDays++;
          } else if (usage.earnedSeconds > 0) {
            // If they earned time but haven't reached cap, show as partial
            color = PushinTheme.primaryBlue;
          } else {
            color = PushinTheme.warningYellow;
          }

          chartBars.add(_buildChartBar(dayName, progress, color));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Summary',
              style: PushinTheme.headline3,
            ),
            SizedBox(height: PushinTheme.spacingMd),

            Container(
              padding: EdgeInsets.all(PushinTheme.spacingLg),
              decoration: BoxDecoration(
                color: PushinTheme.surfaceDark,
                borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
                boxShadow: PushinTheme.cardShadow,
              ),
              child: Column(
                children: [
                  // Chart bars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: chartBars,
                  ),

                  SizedBox(height: PushinTheme.spacingLg),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Completed', PushinTheme.successGreen),
                      SizedBox(width: PushinTheme.spacingMd),
                      _buildLegendItem('Partial', PushinTheme.primaryBlue),
                      SizedBox(width: PushinTheme.spacingMd),
                      _buildLegendItem('Missed', PushinTheme.warningYellow),
                    ],
                  ),

                  SizedBox(height: PushinTheme.spacingMd),

                  // Summary text
                  Text(
                    '$completedDays out of 7 days completed this week',
                    style: PushinTheme.body2.copyWith(
                      color: PushinTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _getDayName(int weekday) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[weekday - 1];
  }

  Widget _buildChartBar(String label, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 32,
          height: height * 120, // Max height of 120
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(PushinTheme.radiusSm),
          ),
        ),
        SizedBox(height: PushinTheme.spacingSm),
        Text(
          label,
          style: PushinTheme.caption.copyWith(
            color: PushinTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: PushinTheme.spacingXs),
        Text(
          label,
          style: PushinTheme.caption.copyWith(
            color: PushinTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

