import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../domain/PushinState.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../domain/models/workout_mode.dart';
import '../../screens/workouts/screen_time_selection_screen.dart';
import '../../theme/workouts_design_tokens.dart';

/// Dynamic and interactive status card that shows:
/// - RED: Apps blocked/locked (tap to start workout)
/// - GREEN: Apps unlocked with circular countdown timer on right
/// - ORANGE: Workout in progress (tap to view progress)
/// - GRAY: Unlock time expired (tap to start new workout)
class CurrentStatusCard extends StatefulWidget {
  const CurrentStatusCard({super.key});

  @override
  State<CurrentStatusCard> createState() => _CurrentStatusCardState();
}

class _CurrentStatusCardState extends State<CurrentStatusCard>
    with TickerProviderStateMixin {
  Timer? _countdownTimer;
  late AnimationController _shineController;
  late Animation<double> _shineAnimation;

  @override
  void initState() {
    super.initState();

    // Shine animation for the glowing effect
    _shineController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _shineAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.easeInOut),
    );

    // Start countdown timer for live updates
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _shineController.dispose();
    super.dispose();
  }

  String _getStatusKey(PushinState state,
      {bool isEmergencyUnlockActive = false}) {
    switch (state) {
      case PushinState.locked:
        // Show emergency unlock only when apps are blocked but emergency is active
        if (isEmergencyUnlockActive) {
          return 'emergency_unlocked';
        }
        return 'locked';
      case PushinState.earning:
        return 'earning';
      case PushinState.unlocked:
        // Always show regular unlock when state is unlocked, regardless of emergency status
        return 'unlocked';
      case PushinState.expired:
        // Show emergency unlock only when apps are expired but emergency is active
        if (isEmergencyUnlockActive) {
          return 'emergency_unlocked';
        }
        return 'expired';
    }
  }

  void _handleTap(BuildContext context, PushinState state) {
    HapticFeedback.mediumImpact();

    switch (state) {
      case PushinState.locked:
        _navigateToWorkoutSelection(context);
        break;
      case PushinState.earning:
        HapticFeedback.heavyImpact();
        _showInProgressSnackbar(context);
        break;
      case PushinState.unlocked:
        _navigateToWorkoutSelection(context);
        break;
      case PushinState.expired:
        _navigateToWorkoutSelection(context);
        break;
    }
  }

  void _navigateToWorkoutSelection(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ScreenTimeSelectionScreen(selectedMode: WorkoutMode.normal),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = Curves.easeOutCubic;
          var fadeAnimation = CurvedAnimation(parent: animation, curve: curve);
          return FadeTransition(opacity: fadeAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showInProgressSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Workout in progress! Keep going!'),
        backgroundColor: WorkoutsDesignTokens.earningOrange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PushinAppController>(
      builder: (context, controller, child) {
        final state = controller.currentState;
        final now = DateTime.now();
        final remainingSeconds = controller.getUnlockTimeRemaining(now);
        final totalDuration = controller.getTotalUnlockDuration();
        final gracePeriodSeconds = controller.getGracePeriodRemaining(now);
        final isEmergencyUnlockActive = controller.isEmergencyUnlockActive;
        final emergencyUnlockTimeRemaining =
            controller.emergencyUnlockTimeRemaining;
        final emergencyUnlockTotalSeconds =
            controller.emergencyUnlockMinutes * 60;
        final statusKey = _getStatusKey(state,
            isEmergencyUnlockActive: isEmergencyUnlockActive);

        final config = _getStatusConfig(
          statusKey,
          remainingSeconds: remainingSeconds,
          gracePeriodSeconds: gracePeriodSeconds,
          emergencyUnlockTimeRemaining: emergencyUnlockTimeRemaining,
        );

        return GestureDetector(
          onTap: () => _handleTap(context, state),
          child: AnimatedBuilder(
            animation: _shineAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    // Main glow shadow
                    BoxShadow(
                      color: config.color.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                    // Secondary subtle glow
                    BoxShadow(
                      color: config.color.withOpacity(0.2),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      // Base gradient background
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: config.gradient,
                        ),
                        child: Row(
                          children: [
                            // Left icon
                            _buildIconContainer(config, state),
                            const SizedBox(width: 16),
                            // Center content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    config.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    config.description,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Right side: circular timer or action indicator
                            _buildRightWidget(
                              state,
                              config,
                              remainingSeconds,
                              totalDuration,
                              gracePeriodSeconds,
                              isEmergencyUnlockActive: isEmergencyUnlockActive,
                              emergencyUnlockTimeRemaining:
                                  emergencyUnlockTimeRemaining,
                              emergencyUnlockTotalSeconds:
                                  emergencyUnlockTotalSeconds,
                            ),
                          ],
                        ),
                      ),
                      // Full-width shimmer overlay - when unlocked or emergency unlock active
                      if ((state == PushinState.unlocked &&
                              !isEmergencyUnlockActive) ||
                          isEmergencyUnlockActive)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(
                                      -2.0 + (_shineAnimation.value * 2), -0.5),
                                  end: Alignment(
                                      -1.0 + (_shineAnimation.value * 2), 0.5),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(0.0),
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.25),
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.0),
                                    Colors.transparent,
                                  ],
                                  stops: const [
                                    0.0,
                                    0.2,
                                    0.35,
                                    0.5,
                                    0.65,
                                    0.8,
                                    1.0
                                  ],
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
          ),
        );
      },
    );
  }

  Widget _buildIconContainer(StatusConfig config, PushinState state) {
    // Use custom lock icons for locked/unlocked states
    Widget iconWidget;
    if (config.icon == Icons.lock_rounded) {
      iconWidget = Image.asset(
        'assets/icons/locked_icon.png',
        width: 26,
        height: 26,
        color: Colors.white,
      );
    } else if (config.icon == Icons.lock_open_rounded) {
      // Use unlock icon for both regular unlocked and emergency unlock states
      iconWidget = Image.asset(
        'assets/icons/unlocked_icon.png',
        width: 26,
        height: 26,
        color: Colors.white,
      );
    } else {
      // Use Material Design icon for other states
      iconWidget = Icon(
        config.icon,
        color: Colors.white,
        size: 26,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: iconWidget,
    );
  }

  Widget _buildRightWidget(
    PushinState state,
    StatusConfig config,
    int remainingSeconds,
    int totalDuration,
    int gracePeriodSeconds, {
    bool isEmergencyUnlockActive = false,
    int emergencyUnlockTimeRemaining = 0,
    int emergencyUnlockTotalSeconds = 1800,
  }) {
    // Show circular timer for emergency unlock
    if (isEmergencyUnlockActive && emergencyUnlockTimeRemaining > 0) {
      return _buildCircularTimer(
        emergencyUnlockTimeRemaining,
        emergencyUnlockTotalSeconds,
        config.color,
      );
    }

    // Show circular timer for unlocked state
    if (state == PushinState.unlocked && remainingSeconds > 0) {
      return _buildCircularTimer(remainingSeconds, totalDuration, config.color);
    }

    // Show grace period warning for expired state
    if (state == PushinState.expired && gracePeriodSeconds > 0) {
      return _buildGracePeriodCircle(gracePeriodSeconds);
    }

    // For locked state, don't show any icon on the right
    if (state == PushinState.locked) {
      return const SizedBox(width: 48, height: 48);
    }

    // Default: show action arrow with glow
    return _buildActionArrow(config);
  }

  Widget _buildCircularTimer(
      int remainingSeconds, int totalDuration, Color accentColor) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    // Calculate progress based on actual total unlock duration
    // Use totalDuration if available, otherwise default to 3600 (60 min)
    final maxSeconds = totalDuration > 0 ? totalDuration : 3600;
    final progress = (remainingSeconds / maxSeconds).clamp(0.0, 1.0);

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress ring
          SizedBox(
            width: 68,
            height: 68,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: progress,
                strokeWidth: 4,
                backgroundColor: Colors.white.withOpacity(0.2),
                progressColor: Colors.white,
              ),
            ),
          ),
          // Timer text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                minutes > 0
                    ? '$minutes:${seconds.toString().padLeft(2, '0')}'
                    : '$seconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                  height: 1.0,
                ),
              ),
              if (minutes > 0)
                Text(
                  'min',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                )
              else
                Text(
                  'sec',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGracePeriodCircle(int gracePeriodSeconds) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Warning icon background
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.white.withOpacity(0.2),
            size: 40,
          ),
          // Countdown
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$gracePeriodSeconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              Text(
                'sec',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionArrow(StatusConfig config) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.arrow_forward_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  StatusConfig _getStatusConfig(String status,
      {int remainingSeconds = 0,
      int gracePeriodSeconds = 0,
      int emergencyUnlockTimeRemaining = 0}) {
    switch (status) {
      case 'earning':
        return StatusConfig(
          title: 'Workout in Progress',
          description: 'Keep going to earn unlock time!',
          icon: Icons.fitness_center,
          color: WorkoutsDesignTokens.earningOrange,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
          ),
        );
      case 'unlocked':
        return StatusConfig(
          title: 'Apps Unlocked!',
          description: 'Enjoy your screen time',
          icon: Icons.lock_open_rounded,
          color: WorkoutsDesignTokens.unlockedGreen,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          ),
        );
      case 'emergency_unlocked':
        return StatusConfig(
          title: 'Emergency Unlock',
          description: 'Apps unlocked temporarily',
          icon: Icons.lock_open_rounded,
          color: const Color(0xFFFFB347), // Orange for emergency
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFB347), Color(0xFFFF8C00)],
          ),
        );
      case 'expired':
        return StatusConfig(
          title: 'Time Expiring',
          description: gracePeriodSeconds > 0
              ? 'Apps locking soon...'
              : 'Unlock distracting apps',
          icon: Icons.timer_off_rounded,
          color: WorkoutsDesignTokens.expiredGray,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6B7280), Color(0xFF4B5563)],
          ),
        );
      default: // locked
        return StatusConfig(
          title: 'Apps Blocked',
          description: 'Unlock distracting apps',
          icon: Icons.lock_rounded,
          color: WorkoutsDesignTokens.lockedRed,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          ),
        );
    }
  }
}

/// Custom painter for circular progress indicator
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
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
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}

class StatusConfig {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final LinearGradient gradient;

  StatusConfig({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}
