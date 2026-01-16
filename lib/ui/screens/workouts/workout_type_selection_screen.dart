import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/models/workout_mode.dart';
import '../../../services/WorkoutRewardCalculator.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../workout/CameraRepCounterScreen.dart';

/// Workout Type Selection Screen
///
/// Grid layout to choose workout type, similar to onboarding design.
/// Shows required reps based on previously selected screen time.
class WorkoutTypeSelectionScreen extends StatefulWidget {
  final WorkoutMode selectedMode;
  final int desiredScreenTime;
  final int requiredReps;

  const WorkoutTypeSelectionScreen({
    super.key,
    required this.selectedMode,
    required this.desiredScreenTime,
    required this.requiredReps,
  });

  @override
  State<WorkoutTypeSelectionScreen> createState() =>
      _WorkoutTypeSelectionScreenState();
}

class _WorkoutTypeSelectionScreenState
    extends State<WorkoutTypeSelectionScreen> {
  String? _selectedWorkout;

  // Workouts list - all unlocked
  final List<_WorkoutInfo> _workouts = [
    _WorkoutInfo(
      name: 'Push-Ups',
      iconPath: 'assets/icons/pushup_icon.png',
      fallbackIcon: Icons.fitness_center,
      isLocked: false,
    ),
    _WorkoutInfo(
      name: 'Squats',
      iconPath: 'assets/icons/squats_icon.png',
      fallbackIcon: Icons.airline_seat_legroom_normal,
      isLocked: false,
    ),
    _WorkoutInfo(
      name: 'Glute Bridge',
      iconPath: 'assets/icons/glutebridge_icon.png',
      fallbackIcon: Icons.accessibility_new,
      isLocked: false,
    ),
    _WorkoutInfo(
      name: 'Plank',
      iconPath: 'assets/icons/plank_icon.png',
      fallbackIcon: Icons.self_improvement,
      isLocked: false,
    ),
    _WorkoutInfo(
      name: 'Jumping Jacks',
      iconPath: 'assets/icons/jumping_jacks_icon.png',
      fallbackIcon: Icons.sports_gymnastics,
      isLocked: false,
    ),
  ];

  void _startWorkout() {
    if (_selectedWorkout == null) return;

    HapticFeedback.mediumImpact();

    // Calculate appropriate target value using the sophisticated reward calculator
    final calculator = WorkoutRewardCalculator();
    final targetSeconds =
        widget.desiredScreenTime * 60; // Convert minutes to seconds

    final targetValue = calculator.calculateRequiredReps(
      workoutType: _selectedWorkout!.toLowerCase().replaceAll(' ', '-'),
      targetSeconds: targetSeconds,
      mode: widget.selectedMode,
    );

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CameraRepCounterScreen(
          workoutType: _selectedWorkout!.toLowerCase().replaceAll(' ', '-'),
          targetReps:
              targetValue, // Uses proper calculation for each workout type
          desiredScreenTimeMinutes: widget.desiredScreenTime,
          workoutMode: widget.selectedMode.name,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = Curves.easeOutCubic;
          var fadeAnimation = CurvedAnimation(parent: animation, curve: curve);
          return FadeTransition(opacity: fadeAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Get appropriate workout description based on selected workout
  String _getWorkoutDescription() {
    if (_selectedWorkout == null) {
      return 'Choose a workout to unlock ${widget.desiredScreenTime} min of screen time';
    }

    // Calculate the actual target for the selected workout
    final calculator = WorkoutRewardCalculator();
    final targetSeconds = widget.desiredScreenTime * 60;
    final targetValue = calculator.calculateRequiredReps(
      workoutType: _selectedWorkout!.toLowerCase().replaceAll(' ', '-'),
      targetSeconds: targetSeconds,
      mode: widget.selectedMode,
    );

    // Check if this is a time-based workout
    final isTimeBased = _selectedWorkout!.toLowerCase() == 'plank';

    if (isTimeBased) {
      // Format time for planks
      final minutes = targetValue ~/ 60;
      final seconds = targetValue % 60;
      final timeString =
          minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

      return 'Hold for $timeString to unlock ${widget.desiredScreenTime} min';
    } else {
      // Rep-based workout
      return 'Complete $targetValue ${_selectedWorkout!} to unlock ${widget.desiredScreenTime} min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.22,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choose Your',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          widget.selectedMode.color,
                          widget.selectedMode.color.withOpacity(0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'Workout',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getWorkoutDescription(),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: -0.2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Workout Grid
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: _workouts.length,
                        itemBuilder: (context, index) {
                          final workout = _workouts[index];
                          final isSelected = _selectedWorkout == workout.name;
                          return _WorkoutCard(
                            workout: workout,
                            isSelected: isSelected,
                            modeColor: widget.selectedMode.color,
                            onTap: workout.isLocked
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    setState(
                                        () => _selectedWorkout = workout.name);
                                  },
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // More workouts coming soon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Colors.white.withOpacity(0.4),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'More workouts coming soon!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Start button
              Container(
                padding: const EdgeInsets.all(24),
                child: _StartButton(
                  enabled: _selectedWorkout != null,
                  modeColor: widget.selectedMode.color,
                  onTap: _startWorkout,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Workout info model
class _WorkoutInfo {
  final String name;
  final String iconPath;
  final IconData fallbackIcon;
  final bool isLocked;

  const _WorkoutInfo({
    required this.name,
    required this.iconPath,
    required this.fallbackIcon,
    required this.isLocked,
  });
}

/// Workout Card Widget
class _WorkoutCard extends StatelessWidget {
  final _WorkoutInfo workout;
  final bool isSelected;
  final Color modeColor;
  final VoidCallback? onTap;

  const _WorkoutCard({
    required this.workout,
    required this.isSelected,
    required this.modeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLocked = workout.isLocked;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : isLocked
                  ? Colors.white.withOpacity(0.04)
                  : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Icon container
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? modeColor.withOpacity(0.12)
                            : isLocked
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Image.asset(
                        workout.iconPath,
                        color: isSelected
                            ? modeColor
                            : isLocked
                                ? Colors.white.withOpacity(0.25)
                                : Colors.white.withOpacity(0.9),
                        width: 40,
                        height: 40,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            workout.fallbackIcon,
                            color: isSelected
                                ? modeColor
                                : isLocked
                                    ? Colors.white.withOpacity(0.25)
                                    : Colors.white.withOpacity(0.9),
                            size: 40,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Workout name
                  Text(
                    workout.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? modeColor
                          : isLocked
                              ? Colors.white.withOpacity(0.25)
                              : Colors.white,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Premium label for locked items
                  SizedBox(
                    height: 20,
                    child: isLocked
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Coming soon',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.35),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const Spacer(),
                ],
              ),
            ),

            // Lock icon
            if (isLocked)
              Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  Icons.lock_rounded,
                  color: Colors.white.withOpacity(0.2),
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Start Button Widget
class _StartButton extends StatelessWidget {
  final bool enabled;
  final Color modeColor;
  final VoidCallback onTap;

  const _StartButton({
    required this.enabled,
    required this.modeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(100),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: enabled ? Colors.black : Colors.white.withOpacity(0.4),
              letterSpacing: -0.3,
            ),
            child: const Text("LET'S GO!"),
          ),
        ),
      ),
    );
  }
}
