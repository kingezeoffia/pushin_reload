import 'package:flutter/material.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
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

/// Generic Workout Success Screen
///
/// BMAD V6 Spec:
/// - Dedicated success confirmation screen after workout test completion
/// - Green color scheme (success, growth, progress)
/// - Large stylized checkmark as hero element
/// - Clean, modern, confident design
/// - Motivational green gradient background
/// - Manual continue button (no auto-advance)
class HowItWorksWorkoutSuccessScreen extends StatelessWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;
  final String workoutHistory;
  final List<String> blockedApps;
  final String workoutType; // 'Push-Ups', 'Squats', 'Plank', etc.

  const HowItWorksWorkoutSuccessScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
    required this.workoutHistory,
    required this.blockedApps,
    required this.workoutType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),

                  // Success Content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Large Checkmark with Glow
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF10B981), // success green
                                Color(0xFF059669), // darker green
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.4),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 80,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Success Headline
                        const Text(
                          'Great Job!',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.05,
                            letterSpacing: -1.2,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Supporting Text
                        Text(
                          _getSuccessMessage(workoutType),
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                ],
              ),
            ),

            // Continue Button - properly positioned in Stack
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _ContinueButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      _NoSwipeBackRoute(
                        builder: (context) => HowItWorksEmergencyUnlockScreen(
                          fitnessLevel: fitnessLevel,
                          goals: goals,
                          otherGoal: otherGoal,
                          workoutHistory: workoutHistory,
                          blockedApps: blockedApps,
                          selectedWorkout: workoutType,
                          unlockDuration: 15, // Default 15 minutes
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSuccessMessage(String workoutType) {
    switch (workoutType.toLowerCase()) {
      case 'push-ups':
        return 'Look at you crushing those push-ups!';
      case 'squats':
        return 'Your legs are getting stronger!';
      case 'plank':
        return 'Core strength on point!';
      case 'jumping jacks':
        return 'You\'re jumping with energy!';
      case 'glute bridge':
        return 'Those glutes are firing up!';
      default:
        return 'You\'re doing amazing!';
    }
  }
}

/// Continue Button Widget
class _ContinueButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContinueButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
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
            'Continue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A2A6A),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}
