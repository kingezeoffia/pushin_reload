import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'HowItWorksPushUpTestScreen.dart';
import 'HowItWorksSquatTestScreen.dart';
import 'HowItWorksGluteBridgeTestScreen.dart';
import 'HowItWorksPlankTestScreen.dart';
import 'HowItWorksJumpingJackTestScreen.dart';
import 'HowItWorksEmergencyUnlockScreen.dart';

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

/// Step 2: Exercise to Unlock Screen Time
///
/// Matches the main app's WorkoutSelectionScreen layout:
/// - Vertical list of row-style workout cards
/// - All workouts available for selection
class HowItWorksExerciseScreen extends StatefulWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;
  final String workoutHistory;
  final List<String> blockedApps;

  const HowItWorksExerciseScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
    required this.workoutHistory,
    required this.blockedApps,
  });

  @override
  State<HowItWorksExerciseScreen> createState() =>
      _HowItWorksExerciseScreenState();
}

class _HowItWorksExerciseScreenState extends State<HowItWorksExerciseScreen> {
  String? _selectedWorkout;

  // All workouts available
  final List<_WorkoutInfo> _workouts = [
    _WorkoutInfo('Push-Ups', 'assets/icons/pushup_icon.png',
        Icons.fitness_center, '20 reps = 10 minutes'),
    _WorkoutInfo('Squats', 'assets/icons/squats_icon.png',
        Icons.airline_seat_legroom_normal, '30 reps = 15 minutes'),
    _WorkoutInfo('Jumping Jacks', 'assets/icons/jumping_jacks_icon.png',
        Icons.sports_gymnastics, '40 reps = 16 minutes'),
    _WorkoutInfo('Plank', 'assets/icons/plank_icon.png', Icons.self_improvement,
        '60 sec = 15 minutes'),
    _WorkoutInfo('Glute Bridge', 'assets/icons/glutebridge_icon.png',
        Icons.accessibility_new, '15 reps = 12 minutes'),
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.20,
        child: Stack(
          children: [
            SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenHeight * 0.04),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exercise to Unlock',
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
                        colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'Screen Time',
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
                      'Choose your workout to earn screen time',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.04),

              // Workout Cards - Vertical List (matching main app)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      ..._workouts.map((workout) {
                        final isSelected = _selectedWorkout == workout.name;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _WorkoutCard(
                            workout: workout,
                            isSelected: isSelected,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedWorkout = workout.name);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
            ),

            // Continue Button - positioned like Complete Setup button
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _ContinueButton(
                  enabled: _selectedWorkout != null,
                  onTap: () {
                    // Navigate to appropriate try-out screen for each workout
                    debugPrint('Selected workout: $_selectedWorkout');
                    Widget testScreen;
                    switch (_selectedWorkout) {
                      case 'Push-Ups':
                        debugPrint('Creating Push-Up Test Screen');
                        testScreen = HowItWorksPushUpTestScreen(
                          fitnessLevel: widget.fitnessLevel,
                          goals: widget.goals,
                          otherGoal: widget.otherGoal,
                          workoutHistory: widget.workoutHistory,
                          blockedApps: widget.blockedApps,
                        );
                        break;
                      case 'Squats':
                        debugPrint('Creating Squat Test Screen');
                        testScreen = HowItWorksSquatTestScreen(
                          fitnessLevel: widget.fitnessLevel,
                          goals: widget.goals,
                          otherGoal: widget.otherGoal,
                          workoutHistory: widget.workoutHistory,
                          blockedApps: widget.blockedApps,
                        );
                        break;
                      case 'Glute Bridge':
                        debugPrint('Creating Glute Bridge Test Screen');
                        testScreen = HowItWorksGluteBridgeTestScreen(
                          fitnessLevel: widget.fitnessLevel,
                          goals: widget.goals,
                          otherGoal: widget.otherGoal,
                          workoutHistory: widget.workoutHistory,
                          blockedApps: widget.blockedApps,
                        );
                        break;
                      case 'Plank':
                        debugPrint('Creating Plank Test Screen');
                        testScreen = HowItWorksPlankTestScreen(
                          fitnessLevel: widget.fitnessLevel,
                          goals: widget.goals,
                          otherGoal: widget.otherGoal,
                          workoutHistory: widget.workoutHistory,
                          blockedApps: widget.blockedApps,
                        );
                        break;
                      case 'Jumping Jacks':
                        debugPrint('Creating Jumping Jacks Test Screen');
                        testScreen = HowItWorksJumpingJackTestScreen(
                          fitnessLevel: widget.fitnessLevel,
                          goals: widget.goals,
                          otherGoal: widget.otherGoal,
                          workoutHistory: widget.workoutHistory,
                          blockedApps: widget.blockedApps,
                        );
                        break;
                      default:
                        // Fallback to emergency unlock for any unknown workouts
                        debugPrint(
                            'Falling back to emergency unlock for workout: $_selectedWorkout');
                        testScreen = HowItWorksEmergencyUnlockScreen(
                          fitnessLevel: widget.fitnessLevel,
                          goals: widget.goals,
                          otherGoal: widget.otherGoal,
                          workoutHistory: widget.workoutHistory,
                          blockedApps: widget.blockedApps,
                          selectedWorkout: _selectedWorkout!,
                          unlockDuration: 15, // Default 15 minutes
                        );
                    }

                    Navigator.push(
                      context,
                      _NoSwipeBackRoute(builder: (context) => testScreen),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
    );
  }
}

/// Workout info model
class _WorkoutInfo {
  final String name;
  final String iconPath;
  final IconData fallbackIcon;
  final String subtitle;

  const _WorkoutInfo(
      this.name, this.iconPath, this.fallbackIcon, this.subtitle);
}

/// Row-style Workout Card (matching main app)
class _WorkoutCard extends StatelessWidget {
  final _WorkoutInfo workout;
  final bool isSelected;
  final VoidCallback onTap;

  const _WorkoutCard({
    required this.workout,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3535A0).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.asset(
                workout.iconPath,
                width: 28,
                height: 28,
                color: isSelected ? const Color(0xFF3535A0) : Colors.white,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    workout.fallbackIcon,
                    size: 28,
                    color: isSelected ? const Color(0xFF3535A0) : Colors.white,
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? const Color(0xFF3535A0) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    workout.subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? const Color(0xFF3535A0).withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Checkmark or arrow icon
            Icon(
              isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
              size: 20,
              color: isSelected
                  ? const Color(0xFF3535A0)
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Continue Button Widget
class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.enabled,
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
        height: 52,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
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
              color: enabled
                  ? const Color(0xFF2A2A6A)
                  : Colors.white.withValues(alpha: 0.4),
              letterSpacing: -0.3,
            ),
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }
}
