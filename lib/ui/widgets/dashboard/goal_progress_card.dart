import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/dashboard_design_tokens.dart';
import '../SelectionButton.dart';

class CustomWorkoutCard extends StatefulWidget {
  const CustomWorkoutCard({super.key});

  @override
  State<CustomWorkoutCard> createState() => _CustomWorkoutCardState();
}

class _CustomWorkoutCardState extends State<CustomWorkoutCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

class _CustomWorkoutCardState extends State<CustomWorkoutCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  // Custom workout data
  final List<CustomExercise> _exercises = [
    CustomExercise(
      name: 'Push-ups',
      icon: Icons.fitness_center,
      pointsPerRep: 5,
      color: const Color(0xFF4CAF50),
    ),
    CustomExercise(
      name: 'Squats',
      icon: Icons.accessibility,
      pointsPerRep: 3,
      color: const Color(0xFF2196F3),
    ),
    CustomExercise(
      name: 'Jumping Jacks',
      icon: Icons.directions_run,
      pointsPerRep: 2,
      color: const Color(0xFFFF9800),
    ),
    CustomExercise(
      name: 'Burpees',
      icon: Icons.sports_gymnastics,
      pointsPerRep: 8,
      color: const Color(0xFFE91E63),
    ),
  ];

  CustomExercise? _selectedExercise;
  int _repCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    // Add shimmer effect like other cards
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2A3166).withOpacity(0.95),
                  const Color(0xFF1F2547).withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(28), // Match other cards
              boxShadow: [
                // Main glow shadow - similar to other cards
                BoxShadow(
                  color: DashboardDesignTokens.accentGreen.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                // Secondary subtle glow
                BoxShadow(
                  color: DashboardDesignTokens.accentGreen.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                // Base shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  child!,
                  // Shimmer overlay - similar to CurrentStatusCard
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-2.0 + (_shimmerAnimation.value * 2), -0.5),
                            end: Alignment(-1.0 + (_shimmerAnimation.value * 2), 0.5),
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.12),
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.0),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: DashboardDesignTokens.accentGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Custom Workout',
                  style: TextStyle(
                    color: DashboardDesignTokens.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Create your own workout and assign point values.',
              style: TextStyle(
                color: DashboardDesignTokens.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Exercise Selection - 2x2 Grid similar to onboarding
            Text(
              'Choose Exercise',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // 2x2 Grid of Exercise Options
            Row(
              children: [
                Expanded(
                  child: SelectionButton(
                    label: 'Push-ups',
                    isSelected: _selectedExercise?.name == 'Push-ups',
                    onTap: () => setState(() => _selectedExercise = _exercises[0]),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SelectionButton(
                    label: 'Squats',
                    isSelected: _selectedExercise?.name == 'Squats',
                    onTap: () => setState(() => _selectedExercise = _exercises[1]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SelectionButton(
                    label: 'Jumping Jacks',
                    isSelected: _selectedExercise?.name == 'Jumping Jacks',
                    onTap: () => setState(() => _selectedExercise = _exercises[2]),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SelectionButton(
                    label: 'Burpees',
                    isSelected: _selectedExercise?.name == 'Burpees',
                    onTap: () => setState(() => _selectedExercise = _exercises[3]),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Points Configuration
            if (_selectedExercise != null) ...[
              Text(
                'Point Configuration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedExercise!.icon,
                      color: _selectedExercise!.color,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedExercise!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${_selectedExercise!.pointsPerRep} points per rep',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Points per rep adjuster
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _adjustPoints(-1),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.remove,
                              color: Colors.white.withOpacity(0.7),
                              size: 16,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedExercise!.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_selectedExercise!.pointsPerRep}',
                            style: TextStyle(
                              color: _selectedExercise!.color,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _adjustPoints(1),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.white.withOpacity(0.7),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Rep Counter
              Text(
                'Track Reps',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$_repCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Reps Completed',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_repCount * _selectedExercise!.pointsPerRep} points earned',
                            style: TextStyle(
                              color: _selectedExercise!.color,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _incrementReps,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _selectedExercise!.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.add,
                            color: _selectedExercise!.color,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _resetReps,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.refresh,
                            color: Colors.white.withOpacity(0.6),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  void _adjustPoints(int delta) {
    setState(() {
      _selectedExercise!.pointsPerRep = math.max(1, _selectedExercise!.pointsPerRep + delta);
    });
  }

  void _incrementReps() {
    setState(() {
      _repCount++;
    });
  }

  void _resetReps() {
    setState(() {
      _repCount = 0;
    });
  }
}

class CustomExercise {
  final String name;
  final IconData icon;
  final Color color;
  int pointsPerRep;

  CustomExercise({
    required this.name,
    required this.icon,
    required this.pointsPerRep,
    required this.color,
  });
}

// Legacy GoalProgressCard class for backward compatibility
class GoalProgressCard extends StatefulWidget {
  final double distance; // in km
  final int calories;
  final int steps;
  final double progressPercentage; // 0.0 to 1.0

  const GoalProgressCard({
    super.key,
    required this.distance,
    required this.calories,
    required this.steps,
    required this.progressPercentage,
  });

  @override
  State<GoalProgressCard> createState() => _GoalProgressCardState();
}

class _GoalProgressCardState extends State<GoalProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.progressPercentage,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: DashboardDesignTokens.cardGradient,
        borderRadius: BorderRadius.circular(DashboardDesignTokens.cardRadius),
        boxShadow: DashboardDesignTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goal Progress',
            style: TextStyle(
              color: DashboardDesignTokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Track progress with the goal tracker.',
            style: TextStyle(
              color: DashboardDesignTokens.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              // Left side - Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatItem(
                      '${widget.distance.toStringAsFixed(2)}km',
                      'Total Distance',
                      Icons.route,
                    ),
                    const SizedBox(height: 24),
                    _buildStatItem(
                      '${widget.calories}kcal',
                      'Total Calories',
                      Icons.local_fire_department,
                    ),
                    const SizedBox(height: 24),
                    _buildStatItem(
                      _formatNumber(widget.steps),
                      'Total Steps',
                      Icons.directions_walk,
                    ),
                  ],
                ),
              ),
              // Right side - Circular Progress
              SizedBox(
                width: 180,
                height: 180,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: CircularProgressPainter(
                        progress: _progressAnimation.value,
                      ),
                      child: Center(
                        child: Text(
                          '${(_progressAnimation.value * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              icon,
              color: DashboardDesignTokens.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: DashboardDesignTokens.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)},${(number % 1000).toString().padLeft(3, '0')}';
    }
    return number.toString();
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;

  CircularProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    // Background circle
    final backgroundPaint = Paint()
      ..color = DashboardDesignTokens.accentLightBlue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          DashboardDesignTokens.accentGreen,
          DashboardDesignTokens.accentLightBlue,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

