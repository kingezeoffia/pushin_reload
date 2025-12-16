import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controller/PushinAppController.dart';
import '../../theme/pushin_theme.dart';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A), // Dark top
              Color(0xFF1E293B), // Lighter bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<PushinAppController>(
            builder: (context, controller, _) {
              final planTier = controller.planTier;

              return CustomScrollView(
                slivers: [
                  // Header
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    expandedHeight: 180,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Choose Your',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  PushinTheme.primaryGradient.createShader(
                                Rect.fromLTWH(
                                    0, 0, bounds.width, bounds.height * 1.3),
                              ),
                              blendMode: BlendMode.srcIn,
                              child: const Text(
                                'Workout',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Complete exercises to unlock screen time',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Workout Cards
                  SliverPadding(
                    padding: const EdgeInsets.all(24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Push-Ups (Always unlocked)
                        _WorkoutCard(
                          icon: Icons.fitness_center,
                          title: 'Push-Ups',
                          subtitle: '20 reps',
                          rewardText: controller.getWorkoutRewardDescription(
                              'push-ups', 20),
                          isLocked: false,
                          onTap: () => _startWorkout(
                              context, controller, 'push-ups', 20),
                        ),

                        const SizedBox(height: 16),

                        // Squats (Standard+)
                        _WorkoutCard(
                          icon: Icons.airline_seat_legroom_normal,
                          title: 'Squats',
                          subtitle: '30 reps',
                          rewardText: '30 reps = 15 minutes',
                          isLocked: planTier == 'free',
                          planBadge:
                              planTier == 'free' ? 'Standard Plan' : null,
                          onTap: () => planTier == 'free'
                              ? _showUpgradeDialog(
                                  context, 'Squats', 'Standard')
                              : _startWorkout(
                                  context, controller, 'squats', 30),
                        ),

                        const SizedBox(height: 16),

                        // Plank (Advanced)
                        _WorkoutCard(
                          icon: Icons.self_improvement,
                          title: 'Plank',
                          subtitle: '60 seconds',
                          rewardText: '60 sec = 15 minutes',
                          isLocked: planTier != 'advanced',
                          planBadge:
                              planTier != 'advanced' ? 'Advanced Plan' : null,
                          onTap: () => planTier != 'advanced'
                              ? _showUpgradeDialog(context, 'Plank', 'Advanced')
                              : _startWorkout(context, controller, 'plank', 60),
                        ),

                        const SizedBox(height: 16),

                        // Jumping Jacks (Standard+)
                        _WorkoutCard(
                          icon: Icons.directions_run,
                          title: 'Jumping Jacks',
                          subtitle: '40 reps',
                          rewardText: '40 reps = 16 minutes',
                          isLocked: planTier == 'free',
                          planBadge:
                              planTier == 'free' ? 'Standard Plan' : null,
                          onTap: () => planTier == 'free'
                              ? _showUpgradeDialog(
                                  context, 'Jumping Jacks', 'Standard')
                              : _startWorkout(
                                  context, controller, 'jumping-jacks', 40),
                        ),

                        const SizedBox(height: 16),

                        // Burpees (Advanced)
                        _WorkoutCard(
                          icon: Icons.sports_gymnastics,
                          title: 'Burpees',
                          subtitle: '15 reps',
                          rewardText: '15 reps = 12 minutes',
                          isLocked: planTier != 'advanced',
                          planBadge:
                              planTier != 'advanced' ? 'Advanced Plan' : null,
                          onTap: () => planTier != 'advanced'
                              ? _showUpgradeDialog(
                                  context, 'Burpees', 'Advanced')
                              : _startWorkout(
                                  context, controller, 'burpees', 15),
                        ),

                        const SizedBox(height: 32),

                        // Upgrade CTA for free users
                        if (planTier == 'free')
                          _UpgradeCTACard(
                            onTap: () =>
                                Navigator.pushNamed(context, '/paywall'),
                          ),
                      ]),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RepCounterScreen(
          workoutType: workoutType,
          targetReps: targetReps,
        ),
      ),
    );
  }

  void _showUpgradeDialog(
      BuildContext context, String workoutName, String planRequired) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: PushinTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: PushinTheme.primaryBlue,
              ),
              const SizedBox(height: 16),
              Text(
                'Unlock $workoutName',
                style: PushinTheme.headline3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$workoutName is available in the $planRequired plan. Upgrade to access more workout variety.',
                style: PushinTheme.body2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/paywall');
                      },
                      child: const Text('Upgrade'),
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

/// Workout Card Widget
class _WorkoutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String rewardText;
  final bool isLocked;
  final String? planBadge;
  final VoidCallback onTap;

  const _WorkoutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rewardText,
    required this.isLocked,
    this.planBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLocked ? 0.5 : 1.0,
      child: Container(
        height: 140, // Made taller to accommodate vertical layout
        decoration: BoxDecoration(
          gradient: isLocked
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isLocked ? PushinTheme.surfaceDark : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isLocked
              ? null
              : [
                  BoxShadow(
                    color: PushinTheme.primaryBlue.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Icon and Title vertically stacked
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          icon,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(width: 20),

                  // Content (subtitle and reward)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              planBadge ?? rewardText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Lock Icon or Arrow
                  Align(
                    alignment: Alignment.center,
                    child: Icon(
                      isLocked ? Icons.lock : Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
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
}

/// Upgrade CTA Card
class _UpgradeCTACard extends StatelessWidget {
  final VoidCallback onTap;

  const _UpgradeCTACard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: PushinTheme.primaryBlue, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.star_outline,
                  size: 48,
                  color: PushinTheme.primaryBlue,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Unlock More Workouts',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upgrade to Standard or Advanced for 5 workout types and unlimited daily usage',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    gradient: PushinTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(100),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        child: Text(
                          'See Plans',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
