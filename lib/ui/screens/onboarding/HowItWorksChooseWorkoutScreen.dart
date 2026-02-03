import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../state/auth_state_provider.dart';
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

/// How It Works: Choose Your Workout Screen
///
/// Renamed from HowItWorksExerciseSelectionScreen to match user preference.
/// Supports both authenticated and guest flows.
class HowItWorksChooseWorkoutScreen extends StatefulWidget {
  final String? fitnessLevel;
  final List<String>? goals;
  final String? otherGoal;
  final String? workoutHistory;
  final List<String> blockedApps;

  const HowItWorksChooseWorkoutScreen({
    super.key,
    this.fitnessLevel,
    this.goals,
    this.otherGoal,
    this.workoutHistory,
    required this.blockedApps,
  });

  @override
  State<HowItWorksChooseWorkoutScreen> createState() =>
      _HowItWorksChooseWorkoutScreenState();
}

class _HowItWorksChooseWorkoutScreenState
    extends State<HowItWorksChooseWorkoutScreen> {
  String? _selectedWorkout;

  // Workouts list - all unlocked (matching guest mode design)
  final List<_WorkoutInfo> _workouts = [
    _WorkoutInfo(
      name: 'Push-Ups',
      iconPath: 'assets/icons/pushup_icon.png',
      fallbackIcon: Icons.fitness_center,
    ),
    _WorkoutInfo(
      name: 'Squats',
      iconPath: 'assets/icons/squats_icon.png',
      fallbackIcon: Icons.airline_seat_legroom_normal,
    ),
    _WorkoutInfo(
      name: 'Jumping Jacks',
      iconPath: 'assets/icons/jumping_jacks_icon.png',
      fallbackIcon: Icons.sports_gymnastics,
    ),
    _WorkoutInfo(
      name: 'Plank',
      iconPath: 'assets/icons/plank_icon.png',
      fallbackIcon: Icons.self_improvement,
    ),
    _WorkoutInfo(
      name: 'Glute Bridge',
      iconPath: 'assets/icons/glutebridge_icon.png',
      fallbackIcon: Icons.accessibility_new,
    ),
  ];

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
              SizedBox(height: screenHeight * 0.04),

              // Header - matching guest mode design
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exercise to Unlock',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'Screen Time',
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
                      'Choose your Workout',
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

              // Workout Grid - exact copy of guest mode design
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
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedWorkout = workout.name);
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // More workouts coming soon - matching guest mode
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

              // Continue button - navigate to appropriate test screen
              Container(
                padding: const EdgeInsets.all(24),
                child: _ContinueButton(
                  enabled: _selectedWorkout != null,
                  onTap: () {
                    if (_selectedWorkout != null) {
                      // Save selected workout to auth provider
                      final authProvider = Provider.of<AuthStateProvider>(
                          context,
                          listen: false);
                      authProvider.setSelectedWorkout(_selectedWorkout!);

                      // Advance step - AppRouter will detect this and show next screen (the selected workout test)
                      if (authProvider.isGuestMode) {
                        debugPrint('🔄 HowItWorksChooseWorkoutScreen: Advancing guest setup step...');
                        authProvider.advanceGuestSetupStep();
                      } else {
                        debugPrint('🔄 HowItWorksChooseWorkoutScreen: Advancing onboarding step...');
                        authProvider.advanceOnboardingStep();
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Workout info model - exact copy from guest mode
class _WorkoutInfo {
  final String name;
  final String iconPath;
  final IconData fallbackIcon;

  const _WorkoutInfo({
    required this.name,
    required this.iconPath,
    required this.fallbackIcon,
  });
}

/// Workout Card Widget - exact copy from guest mode
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
    const Color modeColor = Color(0xFF6060FF); // Purple/blue

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.10),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon container - exact copy from guest mode
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? modeColor.withOpacity(0.12)
                        : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset(
                    workout.iconPath,
                    color:
                        isSelected ? modeColor : Colors.white.withOpacity(0.9),
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        workout.fallbackIcon,
                        color: isSelected
                            ? modeColor
                            : Colors.white.withOpacity(0.9),
                        size: 40,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Workout name - exact copy from guest mode
              Text(
                workout.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? modeColor : Colors.white,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(
                  height: 28), // Space where "Premium feature" used to be
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Continue Button Widget - exact copy from guest mode
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
              color: enabled
                  ? const Color(0xFF2A2A6A)
                  : Colors.white.withOpacity(0.4),
              letterSpacing: -0.3,
            ),
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }
}
