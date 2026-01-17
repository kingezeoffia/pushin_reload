import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/dashboard_design_tokens.dart';
import '../../screens/paywall/PaywallScreen.dart';

class CustomWorkoutCard extends StatefulWidget {
  const CustomWorkoutCard({super.key});

  @override
  State<CustomWorkoutCard> createState() => _CustomWorkoutCardState();
}

class _CustomWorkoutCardState extends State<CustomWorkoutCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;


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

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _navigateToPaywall(context);
        },
        child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          // Clean glassmorphism - matching home screen widgets
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Coming soon icon - sparkle/star with gradient
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFD700), // Gold
                      Color(0xFFFFA500), // Orange
                    ],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // "COMING SOON" text - clearly visible
              const Text(
                'COMING SOON',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _navigateToPaywall(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PaywallScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
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

