import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/pushin_theme.dart';
import '../widgets/workouts/WorkoutModeSelector.dart';
import '../widgets/workouts/WorkoutConfigurator.dart';
import '../widgets/workouts/RecentWorkouts.dart';
import '../../state/pushin_app_controller.dart';

/// Workouts screen with configurable workout modes and settings
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;
  late Animation<double> _contentSlideAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<double> _buttonSlideAnimation;
  late Animation<double> _buttonFadeAnimation;

  WorkoutMode _selectedMode = WorkoutMode.normal;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Header animations (start immediately)
    _headerSlideAnimation = Tween<double>(
      begin: -30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));

    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    // Content animations (staggered slightly after header)
    _contentSlideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
    ));

    _contentFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    ));

    // Button animations (last, with nice delay)
    _buttonSlideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
    ));

    _buttonFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: PushinTheme.surfaceGradient,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(PushinTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with animation
              _buildHeader(),

              SizedBox(height: PushinTheme.spacingXl),

              // Mode Selector with animation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _contentSlideAnimation.value),
                    child: Opacity(
                      opacity: _contentFadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: WorkoutModeSelector(
                  selectedMode: _selectedMode,
                  onModeChanged: (mode) {
                    setState(() {
                      _selectedMode = mode;
                    });
                  },
                ),
              ),

              SizedBox(height: PushinTheme.spacingXl),

              // Workout Configurator with animation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _contentSlideAnimation.value),
                    child: Opacity(
                      opacity: _contentFadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: WorkoutConfigurator(mode: _selectedMode),
              ),

              SizedBox(height: PushinTheme.spacingXl),

              // Recent Workouts with animation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _contentSlideAnimation.value),
                    child: Opacity(
                      opacity: _contentFadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: const RecentWorkouts(),
              ),

              SizedBox(height: PushinTheme.spacingXl),

              // Quick Start Button with animation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _buttonSlideAnimation.value),
                    child: Opacity(
                      opacity: _buttonFadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: _buildQuickStartButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _headerSlideAnimation.value),
          child: Opacity(
            opacity: _headerFadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workouts',
            style: PushinTheme.headline2,
          ),
          SizedBox(height: PushinTheme.spacingXs),
          Text(
            'Choose your workout mode and customize settings',
            style: PushinTheme.body2,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStartButton() {
    return Consumer<PushinAppController>(
      builder: (context, controller, _) {
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              // Navigate to workout screen with selected mode
              _startWorkout(context, controller);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PushinTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, size: 24),
                SizedBox(width: PushinTheme.spacingMd),
                Text(
                  'Start ${_selectedMode.displayName} Workout',
                  style: PushinTheme.buttonText,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startWorkout(BuildContext context, PushinAppController controller) {
    // Navigate to existing workout screen or implement new workout flow
    // For now, navigate to the existing RepCounterScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const Placeholder(), // TODO: Replace with actual workout screen
      ),
    );
  }
}

/// Workout mode enum
enum WorkoutMode {
  cozy('Cozy', 'Gentle introduction to habit building', Icons.spa, PushinTheme.successGreen),
  normal('Normal', 'Pro workout for consistent progress', Icons.fitness_center, PushinTheme.primaryBlue),
  tuff('Tuff', 'Challenging workout with bigger rewards', Icons.flash_on, PushinTheme.warningYellow);

  const WorkoutMode(this.displayName, this.description, this.icon, this.color);

  final String displayName;
  final String description;
  final IconData icon;
  final Color color;
}

