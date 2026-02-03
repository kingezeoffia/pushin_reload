import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../../state/pushin_app_controller.dart';
import '../../theme/pushin_theme.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'WorkoutCompletionScreen.dart';

/// Rep Counter Screen - Track workout progress with manual rep counter
///
/// Design:
/// - Large rep counter with animated progress ring
/// - Big "+ Add Rep" button (easy to tap during workout)
/// - Motivational messages
/// - Clean, distraction-free UI (no bottom nav)
///
/// Visual Reference: GO Club workout screens (dark bg, big numbers, gradients)
class RepCounterScreen extends StatefulWidget {
  final String workoutType;
  final int targetReps;
  final int desiredScreenTimeMinutes;

  const RepCounterScreen({
    super.key,
    required this.workoutType,
    required this.targetReps,
    required this.desiredScreenTimeMinutes,
  });

  @override
  State<RepCounterScreen> createState() => _RepCounterScreenState();
}

class _RepCounterScreenState extends State<RepCounterScreen>
    with SingleTickerProviderStateMixin {
  int _currentReps = 0;
  bool _workoutCompleted = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Start workout in controller with desired screen time
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PushinAppController>().startWorkout(
            widget.workoutType,
            widget.targetReps,
            desiredScreenTimeMinutes: widget.desiredScreenTimeMinutes,
          );
    });

    // Pulse animation for progress ring
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _addRep() {
    if (_currentReps < widget.targetReps && !_workoutCompleted) {
      setState(() {
        _currentReps++;
      });

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Pulse animation
      _pulseController.forward().then((_) => _pulseController.reverse());

      // Complete workout if target reached
      if (_currentReps == widget.targetReps) {
        _completeWorkout();
      }
    }
  }

  void _completeWorkout() async {
    // Prevent multiple completion calls
    if (_workoutCompleted) {
      print('⚠️ _completeWorkout called but workout already completed');
      return;
    }
    _workoutCompleted = true;
    print('✅ Completing workout: ${_currentReps} reps of ${widget.workoutType}');

    final controller = context.read<PushinAppController>();
    await controller.completeWorkout(_currentReps);

    if (!mounted) return;

    // Navigate to completion screen (use push instead of pushReplacement to keep RepCounterScreen in stack)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutCompletionScreen(
          workoutType: widget.workoutType,
          completedReps: _currentReps,
          earnedMinutes: _getEarnedMinutes(),
        ),
      ),
    );
  }

  int _getEarnedMinutes() {
    // Return the user's desired screen time directly
    return widget.desiredScreenTimeMinutes;
  }

  void _cancelWorkout() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Cancel Workout?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your progress will be lost.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () {
                        context.read<PushinAppController>().cancelWorkout();
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Center(
                          child: Text(
                            'Keep Going',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2A2A6A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentReps / widget.targetReps;
    final isComplete = _currentReps >= widget.targetReps;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.white.withOpacity(0.8)),
                      onPressed: _cancelWorkout,
                    ),
                    Expanded(
                      child: Text(
                        _getWorkoutDisplayName(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const Spacer(),

              // Progress Ring with Rep Counter
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: SizedBox(
                      width: 280,
                      height: 280,
                      child: Stack(
                        children: [
                          // Background circle
                          Center(
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                            ),
                          ),

                          // Progress ring
                          Center(
                            child: SizedBox(
                              width: 280,
                              height: 280,
                              child: CustomPaint(
                                painter: _ProgressRingPainter(
                                  progress: progress,
                                  strokeWidth: 16,
                                ),
                              ),
                            ),
                          ),

                          // Rep count
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    colors: [
                                      Color(0xFF6060FF),
                                      Color(0xFF9090FF)
                                    ],
                                  ).createShader(bounds),
                                  blendMode: BlendMode.srcIn,
                                  child: Text(
                                    '$_currentReps',
                                    style: const TextStyle(
                                      fontSize: 96,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Text(
                                  'of ${widget.targetReps}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Motivational message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _getMotivationalMessage(progress),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(),

              // Add Rep Button
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                child: !isComplete
                    ? PressAnimationButton(
                        onTap: _addRep,
                        child: Container(
                          width: double.infinity,
                          height: 64,
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
                              '+ Add Rep',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A2A6A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      )
                    : PressAnimationButton(
                        onTap: () {},
                        child: Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF34D399)],
                            ),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Workout Complete!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWorkoutDisplayName() {
    return widget.workoutType.split('-').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _getMotivationalMessage(double progress) {
    if (progress >= 1.0) return 'Amazing work!';
    if (progress >= 0.75) return 'Almost there! Keep pushing!';
    if (progress >= 0.5) return 'You\'re crushing it!';
    if (progress >= 0.25) return 'Great start! Keep going!';
    return 'Let\'s do this!';
  }
}

/// Custom painter for circular progress ring
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress ring with purple gradient (matching onboarding)
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
