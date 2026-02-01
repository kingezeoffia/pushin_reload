import 'package:flutter/material.dart';
import '../../theme/pushin_theme.dart';
import '../../screens/WorkoutsScreen.dart';

/// Workout mode selector with Cozy, Normal, and Tuff options
class WorkoutModeSelector extends StatelessWidget {
  final WorkoutMode selectedMode;
  final ValueChanged<WorkoutMode> onModeChanged;

  const WorkoutModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Workout Mode',
          style: PushinTheme.headline3,
        ),
        SizedBox(height: PushinTheme.spacingMd),

        // Mode cards in a row
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                mode: WorkoutMode.cozy,
                isSelected: selectedMode == WorkoutMode.cozy,
                onTap: () => onModeChanged(WorkoutMode.cozy),
              ),
            ),
            SizedBox(width: PushinTheme.spacingMd),
            Expanded(
              child: _ModeCard(
                mode: WorkoutMode.normal,
                isSelected: selectedMode == WorkoutMode.normal,
                onTap: () => onModeChanged(WorkoutMode.normal),
              ),
            ),
            SizedBox(width: PushinTheme.spacingMd),
            Expanded(
              child: _ModeCard(
                mode: WorkoutMode.tuff,
                isSelected: selectedMode == WorkoutMode.tuff,
                onTap: () => onModeChanged(WorkoutMode.tuff),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final WorkoutMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(PushinTheme.spacingMd),
        decoration: BoxDecoration(
          gradient: isSelected ? mode.colorGradient : null,
          color: isSelected ? null : PushinTheme.surfaceDark,
          borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
          border: isSelected
              ? Border.all(color: mode.color, width: 2)
              : Border.all(color: PushinTheme.surfaceDark, width: 2),
          boxShadow:
              isSelected ? PushinTheme.buttonShadow : PushinTheme.cardShadow,
        ),
        child: Column(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: mode.color.withOpacity(isSelected ? 0.3 : 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                mode.icon,
                color: mode.color,
                size: 24,
              ),
            ),

            SizedBox(height: PushinTheme.spacingSm),

            // Title
            Text(
              mode.displayName,
              style: PushinTheme.body1.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : PushinTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: PushinTheme.spacingXs),

            // Description
            Text(
              mode.description,
              style: PushinTheme.caption.copyWith(
                color: isSelected ? Colors.white70 : PushinTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

extension WorkoutModeExtension on WorkoutMode {
  LinearGradient get colorGradient {
    switch (this) {
      case WorkoutMode.cozy:
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)], // Green gradient
        );
      case WorkoutMode.normal:
        return const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)], // Blue gradient
        );
      case WorkoutMode.tuff:
        return const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFD97706)], // Yellow gradient
        );
    }
  }
}
