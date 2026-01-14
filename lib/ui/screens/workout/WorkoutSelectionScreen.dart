import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../theme/pushin_theme.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'RepCounterScreen.dart';

/// Workout Selection Screen - Choose exercise to earn unlock time
///
/// Design:
/// - GO Club dark theme with blue gradients
/// - Large tappable workout cards
/// - Free users: Push-Ups unlocked, others locked
/// - Shows reward preview (reps → minutes)
///
/// Visual Reference: GO Club onboarding screens (dark bg, pill buttons)
class WorkoutSelectionScreen extends StatelessWidget {
  const WorkoutSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.20,
        child: SafeArea(
          child: Consumer<PushinAppController>(
            builder: (context, controller, _) {
              final planTier = controller.planTier;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with back button
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: Colors.white.withOpacity(0.8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose Your',
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
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'Workout',
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
                          'Complete exercises to unlock screen time',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.6),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Workout Cards - Scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          // Push-Ups (Always unlocked)
                          _OnboardingWorkoutCard(
                            icon: Icons.fitness_center,
                            title: 'Push-Ups',
                            subtitle: controller.getWorkoutRewardDescription(
                                'push-ups', 20),
                            isLocked: false,
                            onTap: () => _startWorkout(
                                context, controller, 'push-ups', 20),
                          ),

                          const SizedBox(height: 12),

                          // Squats (Standard+)
                          _OnboardingWorkoutCard(
                            icon: Icons.airline_seat_legroom_normal,
                            title: 'Squats',
                            subtitle: planTier == 'free'
                                ? 'Pro Plan'
                                : '30 reps = 15 minutes',
                            isLocked: planTier == 'free',
                            onTap: () => planTier == 'free'
                                ? _showUpgradeDialog(context, 'Squats', 'Pro')
                                : _startWorkout(
                                    context, controller, 'squats', 30),
                          ),

                          const SizedBox(height: 12),

                          // Plank (Advanced)
                          _OnboardingWorkoutCard(
                            icon: Icons.self_improvement,
                            title: 'Plank',
                            subtitle: planTier != 'advanced'
                                ? 'Advanced Plan'
                                : '60 sec = 15 minutes',
                            isLocked: planTier != 'advanced',
                            onTap: () => planTier != 'advanced'
                                ? _showUpgradeDialog(
                                    context, 'Plank', 'Advanced')
                                : _startWorkout(
                                    context, controller, 'plank', 60),
                          ),

                          const SizedBox(height: 12),

                          // Jumping Jacks (Standard+)
                          _OnboardingWorkoutCard(
                            icon: Icons.directions_run,
                            title: 'Jumping Jacks',
                            subtitle: planTier == 'free'
                                ? 'Pro Plan'
                                : '40 reps = 16 minutes',
                            isLocked: planTier == 'free',
                            onTap: () => planTier == 'free'
                                ? _showUpgradeDialog(
                                    context, 'Jumping Jacks', 'Pro')
                                : _startWorkout(
                                    context, controller, 'jumping-jacks', 40),
                          ),

                          const SizedBox(height: 12),

                          // Burpees (Advanced)
                          _OnboardingWorkoutCard(
                            icon: Icons.sports_gymnastics,
                            title: 'Burpees',
                            subtitle: planTier != 'advanced'
                                ? 'Advanced Plan'
                                : '15 reps = 12 minutes',
                            isLocked: planTier != 'advanced',
                            onTap: () => planTier != 'advanced'
                                ? _showUpgradeDialog(
                                    context, 'Burpees', 'Advanced')
                                : _startWorkout(
                                    context, controller, 'burpees', 15),
                          ),

                          const SizedBox(height: 24),

                          // Upgrade CTA for free users
                          if (planTier == 'free')
                            _OnboardingUpgradeCTA(
                              onTap: () =>
                                  Navigator.pushNamed(context, '/paywall'),
                            ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _startWorkout(
    BuildContext context,
    PushinAppController controller,
    String workoutType,
    int targetReps,
  ) {
    // Calculate screen time based on reps (30 seconds per rep / 60 = minutes)
    final desiredMinutes = (targetReps * 30 / 60).round();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepCounterScreen(
          workoutType: workoutType,
          targetReps: targetReps,
          desiredScreenTimeMinutes: desiredMinutes > 0 ? desiredMinutes : 10,
        ),
      ),
    );
  }

  void _showUpgradeDialog(
      BuildContext context, String workoutName, String planRequired) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6060FF).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Color(0xFF6060FF),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Unlock $workoutName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$workoutName is available in the $planRequired plan.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: Text(
                            'Maybe Later',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/paywall');
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Center(
                          child: Text(
                            'Upgrade',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2A2A6A),
                            ),
                          ),
                        ),
                      ),
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
}

/// Onboarding-style Workout Card
class _OnboardingWorkoutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLocked;
  final VoidCallback onTap;

  const _OnboardingWorkoutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLocked ? 0.5 : 1.0,
      child: PressAnimationButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Lock or arrow icon
              Icon(
                isLocked ? Icons.lock : Icons.arrow_forward_ios,
                size: 18,
                color: Colors.white.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Onboarding-style Upgrade CTA
class _OnboardingUpgradeCTA extends StatelessWidget {
  final VoidCallback onTap;

  const _OnboardingUpgradeCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6060FF).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6060FF).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              size: 32,
              color: Color(0xFF6060FF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unlock More Workouts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade for 5 workout types and unlimited daily usage',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          PressAnimationButton(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Center(
                child: Text(
                  'See Plans',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A2A6A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
