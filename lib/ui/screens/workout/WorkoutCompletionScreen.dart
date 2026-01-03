import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';

/// Workout Completion Screen - Celebrate success with stunning visuals
///
/// Features:
/// - Animated confetti particles
/// - Pulsing glow effects
/// - Staggered reveal animations
/// - Green success theme matching "Apps Unlocked" state
class WorkoutCompletionScreen extends StatefulWidget {
  final String workoutType;
  final int completedReps;
  final int earnedMinutes;

  const WorkoutCompletionScreen({
    super.key,
    required this.workoutType,
    required this.completedReps,
    required this.earnedMinutes,
  });

  @override
  State<WorkoutCompletionScreen> createState() =>
      _WorkoutCompletionScreenState();
}

class _WorkoutCompletionScreenState extends State<WorkoutCompletionScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _confettiController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Haptic feedback on success
    HapticFeedback.heavyImpact();

    // Main entrance animation
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Continuous pulse for glow effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Confetti animation
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.20,
        child: Stack(
          children: [
            // Confetti particles
            _buildConfetti(),

            // Main content
            SafeArea(
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),

                      // Main heading - onboarding style
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Workout',
                                  style: TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.05,
                                    letterSpacing: -1,
                                  ),
                                ),
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ).createShader(
                                    Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                                  ),
                                  blendMode: BlendMode.srcIn,
                                  child: const Text(
                                    'Complete!',
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.1,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${widget.completedReps} ${_getWorkoutDisplayName()}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.white.withOpacity(0.6),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Earned time card - onboarding style
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 1.3),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.lock_open_rounded,
                                        color: Colors.white.withOpacity(0.6),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'YOU EARNED',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.6),
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) => const LinearGradient(
                                          colors: [Color(0xFF10B981), Color(0xFF34D399)],
                                        ).createShader(bounds),
                                        blendMode: BlendMode.srcIn,
                                        child: Text(
                                          '${widget.earnedMinutes}',
                                          style: const TextStyle(
                                            fontSize: 80,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 14, left: 8),
                                        child: Text(
                                          'min',
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white.withOpacity(0.7),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'of screen time',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Info message
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 1.5),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.bolt,
                                      color: Color(0xFF10B981),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Your apps are now unlocked!',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Continue button - onboarding style
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value * 1.8),
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: PressAnimationButton(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.popUntil(context, (route) => route.isFirst);
                              },
                              child: Container(
                                width: double.infinity,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Continue',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2A2A6A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfetti() {
    return AnimatedBuilder(
      animation: _confettiController,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            progress: _confettiController.value,
            particleCount: 30,
          ),
        );
      },
    );
  }

  String _getWorkoutDisplayName() {
    return widget.workoutType.split('-').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}

/// Custom painter for confetti particles
class _ConfettiPainter extends CustomPainter {
  final double progress;
  final int particleCount;
  final List<_Particle> particles;

  _ConfettiPainter({
    required this.progress,
    required this.particleCount,
  }) : particles = List.generate(
          particleCount,
          (i) => _Particle(
            seed: i,
            color: [
              const Color(0xFF10B981),
              const Color(0xFF34D399),
              const Color(0xFF6EE7B7),
              const Color(0xFFFFD700),
              const Color(0xFFFF6B6B),
            ][i % 5],
          ),
        );

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final x = particle.getX(progress, size.width);
      final y = particle.getY(progress, size.height);
      final opacity = particle.getOpacity(progress);
      final rotation = particle.getRotation(progress);

      if (opacity <= 0) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = particle.color.withOpacity(opacity * 0.8)
        ..style = PaintingStyle.fill;

      // Draw different shapes
      if (particle.seed % 3 == 0) {
        // Circle
        canvas.drawCircle(Offset.zero, 4, paint);
      } else if (particle.seed % 3 == 1) {
        // Rectangle
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -2, 8, 4),
            const Radius.circular(1),
          ),
          paint,
        );
      } else {
        // Diamond
        final path = Path()
          ..moveTo(0, -5)
          ..lineTo(3, 0)
          ..lineTo(0, 5)
          ..lineTo(-3, 0)
          ..close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _Particle {
  final int seed;
  final Color color;
  final double startX;
  final double startDelay;
  final double speed;
  final double wobble;

  _Particle({required this.seed, required this.color})
      : startX = (seed * 37 % 100) / 100,
        startDelay = (seed * 17 % 30) / 100,
        speed = 0.5 + (seed * 13 % 50) / 100,
        wobble = (seed * 23 % 100) / 100 * 2 * math.pi;

  double getX(double progress, double width) {
    final adjustedProgress = ((progress - startDelay) * speed).clamp(0.0, 1.0);
    final baseX = startX * width;
    final wobbleOffset = math.sin(adjustedProgress * math.pi * 4 + wobble) * 30;
    return baseX + wobbleOffset;
  }

  double getY(double progress, double height) {
    final adjustedProgress = ((progress - startDelay) * speed).clamp(0.0, 1.0);
    return -20 + adjustedProgress * (height + 40);
  }

  double getOpacity(double progress) {
    final adjustedProgress = ((progress - startDelay) * speed).clamp(0.0, 1.0);
    if (adjustedProgress < 0.1) return adjustedProgress * 10;
    if (adjustedProgress > 0.8) return (1 - adjustedProgress) * 5;
    return 1.0;
  }

  double getRotation(double progress) {
    final adjustedProgress = ((progress - startDelay) * speed).clamp(0.0, 1.0);
    return adjustedProgress * math.pi * 4 + wobble;
  }
}
