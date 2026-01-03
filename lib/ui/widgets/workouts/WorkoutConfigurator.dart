import 'package:flutter/material.dart';
import '../../theme/pushin_theme.dart';
import '../../screens/WorkoutsScreen.dart';

/// Workout configurator for customizing reps, duration, and pauses
class WorkoutConfigurator extends StatefulWidget {
  final WorkoutMode mode;

  const WorkoutConfigurator({super.key, required this.mode});

  @override
  State<WorkoutConfigurator> createState() => _WorkoutConfiguratorState();
}

class _WorkoutConfiguratorState extends State<WorkoutConfigurator> {
  // Default values based on mode
  late int _reps;
  late int _durationMinutes;
  late int _pauseSeconds;

  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  @override
  void didUpdateWidget(WorkoutConfigurator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _initializeDefaults();
    }
  }

  void _initializeDefaults() {
    switch (widget.mode) {
      case WorkoutMode.cozy:
        _reps = 10;
        _durationMinutes = 5;
        _pauseSeconds = 60;
        break;
      case WorkoutMode.normal:
        _reps = 20;
        _durationMinutes = 10;
        _pauseSeconds = 45;
        break;
      case WorkoutMode.tuff:
        _reps = 30;
        _durationMinutes = 15;
        _pauseSeconds = 30;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(PushinTheme.spacingLg),
      decoration: BoxDecoration(
        color: PushinTheme.surfaceDark,
        borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        boxShadow: PushinTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customize Workout',
            style: PushinTheme.headline3,
          ),
          SizedBox(height: PushinTheme.spacingMd),

          // Reps slider
          _buildSliderSetting(
            title: 'Reps',
            value: _reps.toDouble(),
            min: 5,
            max: 50,
            divisions: 45,
            onChanged: (value) => setState(() => _reps = value.round()),
            icon: Icons.repeat,
          ),

          SizedBox(height: PushinTheme.spacingLg),

          // Duration slider
          _buildSliderSetting(
            title: 'Duration (minutes)',
            value: _durationMinutes.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (value) => setState(() => _durationMinutes = value.round()),
            icon: Icons.timer,
          ),

          SizedBox(height: PushinTheme.spacingLg),

          // Pause slider
          _buildSliderSetting(
            title: 'Pause between reps (seconds)',
            value: _pauseSeconds.toDouble(),
            min: 15,
            max: 120,
            divisions: 21,
            onChanged: (value) => setState(() => _pauseSeconds = value.round()),
            icon: Icons.pause,
          ),

          SizedBox(height: PushinTheme.spacingLg),

          // Estimated reward preview
          _buildRewardPreview(),
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: PushinTheme.primaryBlue, size: 20),
            SizedBox(width: PushinTheme.spacingSm),
            Text(
              title,
              style: PushinTheme.body2.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        SizedBox(height: PushinTheme.spacingSm),
        Row(
          children: [
            Text(
              value.round().toString(),
              style: PushinTheme.headline3.copyWith(
                color: widget.mode.color,
                fontSize: 24,
              ),
            ),
            SizedBox(width: PushinTheme.spacingMd),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: widget.mode.color,
                  inactiveTrackColor: widget.mode.color.withOpacity(0.3),
                  thumbColor: widget.mode.color,
                  overlayColor: widget.mode.color.withOpacity(0.2),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRewardPreview() {
    // Calculate estimated reward based on reps and mode
    final rewardMultiplier = widget.mode == WorkoutMode.tuff ? 1.5 :
                           widget.mode == WorkoutMode.normal ? 1.0 : 0.7;
    final estimatedMinutes = (_reps * rewardMultiplier).round();

    return Container(
      padding: EdgeInsets.all(PushinTheme.spacingMd),
      decoration: BoxDecoration(
        color: widget.mode.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(PushinTheme.radiusSm),
        border: Border.all(
          color: widget.mode.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.card_giftcard,
            color: widget.mode.color,
            size: 20,
          ),
          SizedBox(width: PushinTheme.spacingMd),
          Expanded(
            child: Text(
              'Estimated reward: $estimatedMinutes minutes of screen time',
              style: PushinTheme.body2.copyWith(
                color: widget.mode.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}







