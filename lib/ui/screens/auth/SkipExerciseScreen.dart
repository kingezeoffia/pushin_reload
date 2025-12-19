import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'SkipUnlockDurationScreen.dart';
import 'SkipPushUpTestScreen.dart';

/// Skip Flow: Exercise to Unlock Screen Time
///
/// Context-free version for users who skip onboarding
/// Simplified workout selection with direct navigation to unlock duration
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

  // Workouts list - only Push-Ups is unlocked
  final List<_WorkoutInfo> _workouts = [
    _WorkoutInfo('Push-Ups', Icons.fitness_center, false),
    _WorkoutInfo('Squats', Icons.accessibility_new, true),
    _WorkoutInfo('Glute Bridge', Icons.call_to_action, true),
    _WorkoutInfo('Plank', Icons.view_stream, true),
    _WorkoutInfo('Jumping Jacks', Icons.directions_run, true),
  ];

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button (no step indicator for skip flow)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16, top: 8),
                child: _BackButton(onTap: () => Navigator.pop(context)),
              ),

              SizedBox(height: screenHeight * 0.08),

              // Heading - consistent with other screens
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
                      child: Text(
                        'Screen Time',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                          decoration: TextDecoration.none,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose your workout',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.06),

              // Workout Selection
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Cards Grid - 2 columns
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
                            onTap: workout.isLocked
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    setState(
                                        () => _selectedWorkout = workout.name);
                                  },
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // More exercises coming soon reminder
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: Colors.white.withOpacity(0.4),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'More exercises coming soon!',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Continue Button
              Padding(
                padding: const EdgeInsets.all(32),
                child: _ContinueButton(
                  enabled: _selectedWorkout != null,
                  onTap: () {
                    if (_selectedWorkout != null) {
                      // If Push-Ups selected, go to test screen first
                      if (_selectedWorkout == 'Push-Ups') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SkipPushUpTestScreen(
                              blockedApps: widget.blockedApps,
                              selectedWorkout: _selectedWorkout!,
                            ),
                          ),
                        );
                      } else {
                        // For other workouts, skip test and go directly to duration
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SkipUnlockDurationScreen(
                              blockedApps: widget.blockedApps,
                              selectedWorkout: _selectedWorkout!,
                            ),
                          ),
                        );
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

/// Workout info model
class _WorkoutInfo {
  final String name;
  final IconData icon;
  final bool isLocked;

  const _WorkoutInfo(this.name, this.icon, this.isLocked);
}

/// Duolingo-style Workout Card
class _WorkoutCard extends StatelessWidget {
  final _WorkoutInfo workout;
  final bool isSelected;
  final VoidCallback? onTap;

  const _WorkoutCard({
    required this.workout,
    required this.isSelected,
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
          // Subtle shadow for depth
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Spacer to push content to center
                  const Spacer(),
                  // Icon container centered in card
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF3535A0).withOpacity(0.12)
                            : isLocked
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        workout.icon,
                        color: isSelected
                            ? const Color(0xFF3535A0)
                            : isLocked
                                ? Colors.white.withOpacity(0.25)
                                : Colors.white.withOpacity(0.9),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Workout name sleek right under icon
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      workout.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF3535A0)
                            : isLocked
                                ? Colors.white.withOpacity(0.25)
                                : Colors.white,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Premium feature label area - consistent space for all cards
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 20, // Fixed height to maintain consistent spacing
                    child: Center(
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
                                'Premium feature',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.35),
                                ),
                              ),
                            )
                          : null, // Invisible when not locked
                    ),
                  ),
                  // Spacer to balance the layout
                  const Spacer(),
                ],
              ),
            ),

            // Lock icon overlay for locked items
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

/// Back Button Widget
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 22,
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
              ? Colors.white.withOpacity(0.95)
              : Colors.white.withOpacity(0.12),
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
          child: Text(
            'Continue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? const Color(0xFF2A2A6A)
                  : Colors.white.withOpacity(0.4),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}







