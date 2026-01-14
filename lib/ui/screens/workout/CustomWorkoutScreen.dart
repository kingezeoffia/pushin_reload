import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/GOStepsBackground.dart';

class CustomWorkoutScreen extends StatefulWidget {
  const CustomWorkoutScreen({super.key});

  @override
  State<CustomWorkoutScreen> createState() => _CustomWorkoutScreenState();
}

class _CustomWorkoutScreenState extends State<CustomWorkoutScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final List<CustomExercise> _exercises = [
    CustomExercise(
      name: 'Push-ups',
      icon: Icons.fitness_center,
      pointsPerRep: 5,
      color: const Color(0xFF4CAF50),
      isSelected: false,
    ),
    CustomExercise(
      name: 'Squats',
      icon: Icons.accessibility,
      pointsPerRep: 3,
      color: const Color(0xFF2196F3),
      isSelected: false,
    ),
    CustomExercise(
      name: 'Plank',
      icon: Icons.self_improvement,
      pointsPerRep: 6,
      color: const Color(0xFF9C27B0),
      isSelected: false,
    ),
    CustomExercise(
      name: 'Jumping Jacks',
      icon: Icons.directions_run,
      pointsPerRep: 2,
      color: const Color(0xFFFF9800),
      isSelected: false,
    ),
    CustomExercise(
      name: 'Burpees',
      icon: Icons.sports_gymnastics,
      pointsPerRep: 8,
      color: const Color(0xFFE91E63),
      isSelected: false,
    ),
  ];

  final List<CustomExercise> _selectedExercises = [];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Stack(
                children: [
                  // Scrollable content
                  Column(
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
                              'Customize Your',
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
                                colors: [Color(0xFF8B5CF6), Color(0xFFB794F6)],
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
                              '${_selectedExercises.length} exercises selected • ${_calculateTotalPoints()} total points available',
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

                      // Exercise Grid
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
                                itemCount: _exercises.length,
                                itemBuilder: (context, index) {
                                  final exercise = _exercises[index];
                                  final isSelected = _selectedExercises.contains(exercise);
                                  return _ExerciseCard(
                                    exercise: exercise,
                                    isSelected: isSelected,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _toggleExercise(exercise));
                                    },
                                  );
                                },
                              ),

                              const SizedBox(height: 80), // Add bottom padding to prevent overlap with continue button
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Start button - positioned below the scrollable area within GOStepsBackground
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: _StartButton(
                          enabled: _selectedExercises.isNotEmpty,
                          onTap: _startCustomWorkout,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleExercise(CustomExercise exercise) {
    setState(() {
      if (_selectedExercises.contains(exercise)) {
        _selectedExercises.remove(exercise);
        exercise.isSelected = false;
      } else {
        _selectedExercises.add(exercise);
        exercise.isSelected = true;
      }
    });
  }

  int _calculateTotalPoints() {
    // Assuming 10 reps per exercise as a baseline
    return _selectedExercises.fold(0, (sum, exercise) => sum + (exercise.pointsPerRep * 10));
  }

  void _startCustomWorkout() async {
    if (_selectedExercises.isEmpty) return;

    HapticFeedback.mediumImpact();

    // Save custom workout configuration
    final prefs = await SharedPreferences.getInstance();
    final workoutData = _selectedExercises.map((e) => {
      'name': e.name,
      'pointsPerRep': e.pointsPerRep,
      'icon': e.icon.codePoint,
      'color': e.color.value,
    }).toList();

    await prefs.setString('custom_workout_config', workoutData.toString());

    // Navigate back or to workout screen
    Navigator.pop(context);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom workout configured! Start working out to earn points.'),
        backgroundColor: Color(0xFF8B5CF6),
      ),
    );
  }
}

/// Exercise Card Widget
class _ExerciseCard extends StatelessWidget {
  final CustomExercise exercise;
  final bool isSelected;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.exercise,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                        ? exercise.color.withOpacity(0.12)
                        : Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    exercise.icon,
                    color: isSelected
                        ? exercise.color
                        : Colors.white.withOpacity(0.9),
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Exercise name
              Text(
                exercise.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? exercise.color
                      : Colors.white,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // Points info
              Text(
                '${exercise.pointsPerRep} pts/rep',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? exercise.color.withOpacity(0.7)
                      : Colors.white.withOpacity(0.6),
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
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
    return GestureDetector(
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

class CustomExercise {
  final String name;
  final IconData icon;
  final Color color;
  int pointsPerRep;
  bool isSelected;

  CustomExercise({
    required this.name,
    required this.icon,
    required this.pointsPerRep,
    required this.color,
    required this.isSelected,
  });
}