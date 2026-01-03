import 'package:flutter/material.dart';
import '../../theme/workouts_design_tokens.dart';
import '../../theme/dashboard_design_tokens.dart';

// =============================================================================
// IMPROVED LARGE STEPS WIDGET (Fixed Typography & Spacing)
// =============================================================================

class ImprovedLargeStepsWidget extends StatefulWidget {
  final int steps;
  final double distance;
  final int floors;
  final int calories;
  final int delay;
  final bool compact;

  const ImprovedLargeStepsWidget({
    super.key,
    required this.steps,
    required this.distance,
    required this.floors,
    required this.calories,
    this.delay = 0,
    this.compact = false,
  });

  @override
  State<ImprovedLargeStepsWidget> createState() => _ImprovedLargeStepsWidgetState();
}

class _ImprovedLargeStepsWidgetState extends State<ImprovedLargeStepsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Responsive sizing - made more compact to fit in height
    final titleSize = widget.compact ? 32.0 : 38.0;
    final statValueSize = widget.compact ? 12.0 : 14.0;
    final statLabelSize = widget.compact ? 10.0 : 11.0;
    final iconSize = widget.compact ? 14.0 : 16.0;

    return Container(
      height: 160, // Fixed height to prevent overflow
      padding: EdgeInsets.all(widget.compact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: DashboardDesignTokens.cardGradient,
        borderRadius: BorderRadius.circular(DashboardDesignTokens.cardRadius),
        boxShadow: DashboardDesignTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large Steps Number
          Text(
            _formatNumber(widget.steps),
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: widget.compact ? 1 : 2),

          // "Steps" Label
          Row(
            children: [
              Icon(
                Icons.directions_walk,
                color: Colors.white.withOpacity(0.6),
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                'Steps',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          SizedBox(height: widget.compact ? 8 : 12),

          // Progress Bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: widget.compact ? 6 : 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            WorkoutsDesignTokens.stepsBlue,
                            WorkoutsDesignTokens.normalBlue,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: widget.compact ? 6 : 10),

          // Stats Row - FIXED LAYOUT
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                Icons.route,
                '${widget.distance.toStringAsFixed(1)}km', // Shorter distance
                'Dist',
                WorkoutsDesignTokens.distanceRed,
                iconSize,
                statValueSize,
                statLabelSize,
              ),
              _buildStatItem(
                Icons.stairs,
                '${widget.floors}',
                'Flr', // Shorter label
                Colors.yellow,
                iconSize,
                statValueSize,
                statLabelSize,
              ),
              _buildStatItem(
                Icons.local_fire_department,
                '${widget.calories}',
                'Cal', // Shorter label
                WorkoutsDesignTokens.waterCyan,
                iconSize,
                statValueSize,
                statLabelSize,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
    double iconSize,
    double valueSize,
    double labelSize,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: iconSize),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: valueSize,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: labelSize,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.visible,
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)},${(number % 1000).toString().padLeft(3, '0')}';
    }
    return number.toString();
  }
}
