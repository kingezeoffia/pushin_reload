import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../../controller/PushinAppController.dart';
import '../../theme/pushin_theme.dart';
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

  const RepCounterScreen({
    super.key,
    required this.workoutType,
    required this.targetReps,
  });

  @override
  State<RepCounterScreen> createState() => _RepCounterScreenState();
}

class _RepCounterScreenState extends State<RepCounterScreen>
    with SingleTickerProviderStateMixin {
  int _currentReps = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Start workout in controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PushinAppController>().startWorkout(
            widget.workoutType,
            widget.targetReps,
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
    if (_currentReps < widget.targetReps) {
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
    final controller = context.read<PushinAppController>();
    await controller.completeWorkout(_currentReps);

    if (!mounted) return;

    // Navigate to completion screen
    Navigator.pushReplacement(
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
    final controller = context.read<PushinAppController>();
    final description = controller.getWorkoutRewardDescription(
      widget.workoutType,
      _currentReps,
    );
    // Parse minutes from description (e.g., "20 reps = 10 minutes")
    final match = RegExp(r'(\d+)\s+minute').firstMatch(description);
    return match != null ? int.parse(match.group(1)!) : 10;
  }

  void _cancelWorkout() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: PushinTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 56,
                color: PushinTheme.warningYellow,
              ),
              const SizedBox(height: 16),
              const Text(
                'Cancel Workout?',
                style: PushinTheme.headline3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your progress will be lost and you won\'t earn unlock time.',
                style: PushinTheme.body2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<PushinAppController>().cancelWorkout();
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Close workout screen
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Keep Going'),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _cancelWorkout,
                    ),
                    Expanded(
                      child: Text(
                        _getWorkoutDisplayName(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance close button
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
                                color: PushinTheme.surfaceDark.withOpacity(0.5),
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
                                      PushinTheme.primaryGradient.createShader(
                                    Rect.fromLTWH(0, 0, bounds.width,
                                        bounds.height * 1.3),
                                  ),
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
                                    color: Colors.white.withOpacity(0.6),
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
                padding: const EdgeInsets.all(32),
                child: !isComplete
                    ? GestureDetector(
                        onTap: _addRep,
                        child: Container(
                          width: double.infinity,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: PushinTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: PushinTheme.primaryBlue.withOpacity(0.5),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '+ Add Rep',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: double.infinity,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: PushinTheme.successGreen.withOpacity(0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.white, size: 28),
                              SizedBox(width: 8),
                              Text(
                                'Workout Complete!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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

    // Progress ring with gradient
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
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
