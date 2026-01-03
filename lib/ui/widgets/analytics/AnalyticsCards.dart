import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/pushin_theme.dart';
import '../../../state/pushin_app_controller.dart';

/// Analytics cards showing usage statistics
class AnalyticsCards extends StatefulWidget {
  const AnalyticsCards({super.key});

  @override
  State<AnalyticsCards> createState() => _AnalyticsCardsState();
}

class _AnalyticsCardsState extends State<AnalyticsCards> {
  late Future<UsageSummary> _usageData;

  @override
  void initState() {
    super.initState();
    // Cache the future ONCE when widget is created
    final controller = context.read<PushinAppController>();
    _usageData = controller.getTodayUsage();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UsageSummary>(
      future: _usageData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error loading analytics'));
        }

        final usage = snapshot.data!;
        final unlockedHours = (usage.earnedSeconds / 3600).toStringAsFixed(1);
        final screenTimeHours = (usage.consumedSeconds / 3600).toStringAsFixed(1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Activity',
              style: PushinTheme.headline3,
            ),
            SizedBox(height: PushinTheme.spacingMd),

            // Row of analytics cards
            Row(
              children: [
                Expanded(
                  child: _AnalyticsCard(
                    title: 'Screen Time',
                    value: '${screenTimeHours}h',
                    subtitle: usage.hasReachedCap ? 'Cap reached' : 'Within limits',
                    icon: Icons.access_time,
                    color: usage.hasReachedCap ? PushinTheme.warningYellow : PushinTheme.primaryBlue,
                  ),
                ),
                SizedBox(width: PushinTheme.spacingMd),
                Expanded(
                  child: _AnalyticsCard(
                    title: 'Unlocked Hours',
                    value: '${unlockedHours}h',
                    subtitle: 'earned today',
                    icon: Icons.lock_open,
                    color: PushinTheme.successGreen,
                  ),
                ),
              ],
            ),

            SizedBox(height: PushinTheme.spacingMd),

            Row(
              children: [
                Expanded(
                  child: _AnalyticsCard(
                    title: 'Remaining Time',
                    value: '${(usage.remainingSeconds / 60).round()}m',
                    subtitle: 'available to use',
                    icon: Icons.hourglass_empty,
                    color: PushinTheme.secondaryBlue,
                  ),
                ),
                SizedBox(width: PushinTheme.spacingMd),
                Expanded(
                  child: _AnalyticsCard(
                    title: 'Progress',
                    value: '${(usage.progress * 100).round()}%',
                    subtitle: 'of daily goal',
                    icon: Icons.trending_up,
                    color: usage.progress >= 1.0 ? PushinTheme.successGreen : PushinTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(PushinTheme.spacingMd),
      decoration: BoxDecoration(
        color: PushinTheme.surfaceDark,
        borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        boxShadow: PushinTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(PushinTheme.radiusSm),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              SizedBox(width: PushinTheme.spacingSm),
              Expanded(
                child: Text(
                  title,
                  style: PushinTheme.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: PushinTheme.spacingMd),

          // Value
          Text(
            value,
            style: PushinTheme.headline3.copyWith(
              fontSize: 24,
              color: color,
            ),
          ),

          // Subtitle
          Text(
            subtitle,
            style: PushinTheme.caption.copyWith(
              color: PushinTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

