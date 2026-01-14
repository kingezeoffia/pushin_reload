import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../state/auth_state_provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';

/// Skip Flow: Exercise to Unlock Screen Time
///
/// Matches workout_type_selection_screen.dart layout exactly
class SkipExerciseScreen extends StatefulWidget {
  final List<String> blockedApps;

  const SkipExerciseScreen({
    super.key,
    required this.blockedApps,
  });

  @override
  State<SkipExerciseScreen> createState() => _SkipExerciseScreenState();
}

class _SkipExerciseScreenState extends State<SkipExerciseScreen> {
  String? _selectedWorkout;

  // Workouts list - all unlocked (matching main app)
  final List<_WorkoutInfo> _workouts = [
    _WorkoutInfo(
      name: 'Push-Ups',
      iconPath: 'assets/icons/pushups.png',
      fallbackIcon: Icons.fitness_center,
    ),
    _WorkoutInfo(
      name: 'Squats',
      iconPath: 'assets/icons/squats.png',
      fallbackIcon: Icons.airline_seat_legroom_normal,
    ),
    _WorkoutInfo(
      name: 'Glute Bridge',
      iconPath: 'assets/icons/glute_bridge.png',
      fallbackIcon: Icons.accessibility_new,
    ),
    _WorkoutInfo(
      name: 'Plank',
      iconPath: 'assets/icons/plank.png',
      fallbackIcon: Icons.self_improvement,
    ),
    _WorkoutInfo(
      name: 'Jumping Jacks',
      iconPath: 'assets/icons/jumping_jacks.png',
      fallbackIcon: Icons.directions_run,
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

              // Header
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
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedWorkout = workout.name);
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
                  onTap: () {
                    if (_selectedWorkout != null) {
                      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
                      authProvider.setSelectedWorkout(_selectedWorkout!);
                      authProvider.advanceGuestSetupStep();
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

/// Workout info model
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

/// Workout Card Widget
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
          color: isSelected
              ? Colors.white
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
        child: Padding(
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
                        : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset(
                    workout.iconPath,
                    color: isSelected
                        ? modeColor
                        : Colors.white.withOpacity(0.9),
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
              // Workout name
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
              const SizedBox(height: 28), // Space where "Premium feature" used to be
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Start Button Widget
class _StartButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _StartButton({
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
              color: enabled ? const Color(0xFF2A2A6A) : Colors.white.withOpacity(0.4),
              letterSpacing: -0.3,
            ),
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }
}
