import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../state/auth_state_provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'SkipEmergencyUnlockScreen.dart';

/// Custom route that disables swipe back gesture on iOS
class _NoSwipeBackRoute<T> extends MaterialPageRoute<T> {
  _NoSwipeBackRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(builder: builder, settings: settings);

  @override
  bool get hasScopedWillPopCallback => true;

  @override
  bool get canPop => false;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // Disable the default iOS swipe back transition
    return child;
  }
}

/// Skip Flow: Push-Up Success Screen
///
/// Simplified version for users who skip onboarding
/// Shows success message after completing push-up test
/// Features:
/// - Animated confetti particles celebration
/// - Pulsing glow effects
/// - Success celebration with haptic feedback
class SkipPushUpSuccessScreen extends StatefulWidget {
  final List<String> blockedApps;
  final String selectedWorkout;

  const SkipPushUpSuccessScreen({
    super.key,
    required this.blockedApps,
    required this.selectedWorkout,
  });

  @override
  State<SkipPushUpSuccessScreen> createState() => _SkipPushUpSuccessScreenState();
}

class _SkipPushUpSuccessScreenState extends State<SkipPushUpSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _confettiController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
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
    // Capture widget properties for use in callbacks
    final blockedApps = widget.blockedApps;
    final selectedWorkout = widget.selectedWorkout;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GOStepsBackground(
            blackRatio: 0.25,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),

                  // Success Content
                  Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Large Checkmark with Glow
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF10B981), // success green
                                          Color(0xFF059669), // darker green
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withOpacity(0.4),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 80,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 32),

                            // Success Headline
                            const Text(
                              'Great Job!',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.05,
                                letterSpacing: -1.2,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Supporting Text
                            Text(
                              'Look at you!',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Action Button
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: _ContinueButton(
                      onTap: () {
                        final authProvider =
                            Provider.of<AuthStateProvider>(context, listen: false);
                        authProvider.advanceGuestSetupStep();

                        // Navigate to the next screen in the guest flow (disable swipe back)
                        Navigator.push(
                          context,
                          _NoSwipeBackRoute(
                            builder: (context) => SkipEmergencyUnlockScreen(
                              blockedApps: blockedApps,
                              selectedWorkout: selectedWorkout,
                              unlockDuration: 15, // Default 15 minutes
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confetti celebration overlay (IgnorePointer so touches pass through)
          IgnorePointer(
            child: _buildConfetti(),
          ),
        ],
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
}

/// Continue Button Widget
class _ContinueButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContinueButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
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
    );
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
