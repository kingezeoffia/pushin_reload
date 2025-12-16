import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controller/PushinAppController.dart';
import '../../domain/PushinState.dart';
import '../../services/StripeCheckoutService.dart';
import '../theme/pushin_theme.dart';
import '../widgets/AppBlockOverlay.dart';
import 'paywall/PaywallScreen.dart';

/// Home screen showing current state and actions.
///
/// Displays:
/// - LOCKED: Block status card + workout selection
/// - EARNING: Workout tracker (rep counter)
/// - UNLOCKED: Countdown timer + usage stats
/// - EXPIRED: Grace period overlay
///
/// GO Club-inspired design with dark theme, gradients, pill buttons
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Consumer<PushinAppController>(
            builder: (context, controller, _) {
              return _buildStateContent(context, controller);
            },
          ),

          // Block overlay (shown when blocked app launched or daily cap hit)
          ValueListenableBuilder<BlockOverlayState?>(
            valueListenable:
                context.watch<PushinAppController>().blockOverlayState,
            builder: (context, overlayState, _) {
              if (overlayState != null) {
                return AppBlockOverlay(
                  reason: overlayState.reason,
                  blockedAppName: overlayState.appName,
                  onStartWorkout: () {
                    context.read<PushinAppController>().dismissBlockOverlay();
                    // Navigate to workout screen
                  },
                  onGoToSettings: () {
                    // Navigate to settings
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Payment success overlay
          ValueListenableBuilder<SubscriptionStatus?>(
            valueListenable:
                context.watch<PushinAppController>().paymentSuccessState,
            builder: (context, paymentStatus, _) {
              if (paymentStatus != null) {
                return _PaymentSuccessOverlay(
                    subscriptionStatus: paymentStatus);
              }
              return const SizedBox.shrink();
            },
          ),

          // Payment cancel notification
          ValueListenableBuilder<bool>(
            valueListenable:
                context.watch<PushinAppController>().paymentCancelState,
            builder: (context, showCancel, _) {
              if (showCancel) {
                return _PaymentCancelOverlay();
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent(
      BuildContext context, PushinAppController controller) {
    final now = DateTime.now();

    switch (controller.currentState) {
      case PushinState.locked:
        return _LockedStateView(controller: controller);

      case PushinState.earning:
        return _EarningStateView(controller: controller);

      case PushinState.unlocked:
        return _UnlockedStateView(controller: controller, now: now);

      case PushinState.expired:
        return _ExpiredStateView(controller: controller, now: now);
    }
  }
}

/// LOCKED state view
class _LockedStateView extends StatelessWidget {
  final PushinAppController controller;

  const _LockedStateView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: PushinTheme.surfaceGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(PushinTheme.spacingLg),
          child: Column(
            children: [
              // Status card
              Container(
                padding: EdgeInsets.all(PushinTheme.spacingLg),
                decoration: BoxDecoration(
                  color: PushinTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
                  boxShadow: PushinTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: PushinTheme.primaryBlue,
                    ),
                    SizedBox(height: PushinTheme.spacingMd),
                    const Text(
                      'Your apps are blocked',
                      style: PushinTheme.headline3,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: PushinTheme.spacingSm),
                    const Text(
                      'Complete a workout to unlock screen time',
                      style: PushinTheme.body2,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              SizedBox(height: PushinTheme.spacingXl),

              // Workout selection
              const Text(
                'Choose Your Workout',
                style: PushinTheme.headline3,
              ),

              const SizedBox(height: PushinTheme.spacingMd),

              // Push-ups card (active for free plan)
              _WorkoutCard(
                workoutType: 'push-ups',
                reps: 20,
                isLocked: false,
                onTap: () async {
                  await controller.startWorkout('push-ups', 20);
                },
                controller: controller,
              ),

              const SizedBox(height: PushinTheme.spacingMd),

              // Squats card (locked for free plan)
              _WorkoutCard(
                workoutType: 'squats',
                reps: 30,
                isLocked: true,
                badgeText: 'Standard Plan',
                onTap: () {
                  // Show paywall
                  _showPaywall(context);
                },
                controller: controller,
              ),

              SizedBox(height: PushinTheme.spacingXl),

              // Test Paywall Button (for development)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PushinTheme.primaryBlue,
                  side: const BorderSide(color: PushinTheme.primaryBlue),
                  padding: const EdgeInsets.symmetric(
                    horizontal: PushinTheme.spacingLg,
                    vertical: PushinTheme.spacingMd,
                  ),
                ),
                onPressed: () => _showPaywall(context),
                icon: const Icon(Icons.payment),
                label: const Text('Test Stripe Payment →'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaywallScreen(),
      ),
    );
  }
}

/// Workout card widget
class _WorkoutCard extends StatelessWidget {
  final String workoutType;
  final int reps;
  final bool isLocked;
  final String? badgeText;
  final VoidCallback onTap;
  final PushinAppController controller;

  const _WorkoutCard({
    required this.workoutType,
    required this.reps,
    required this.isLocked,
    this.badgeText,
    required this.onTap,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final rewardDesc =
        controller.getWorkoutRewardDescription(workoutType, reps);

    return Opacity(
      opacity: isLocked ? 0.4 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          gradient: isLocked ? null : PushinTheme.primaryGradient,
          color: isLocked ? PushinTheme.surfaceDark : null,
          borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
          boxShadow: isLocked ? null : PushinTheme.buttonShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
            child: Padding(
              padding: EdgeInsets.all(PushinTheme.spacingLg),
              child: Row(
                children: [
                  Icon(
                    _getWorkoutIcon(workoutType),
                    size: 40,
                    color: Colors.white,
                  ),
                  SizedBox(width: PushinTheme.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _capitalize(workoutType),
                          style: PushinTheme.headline3.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badgeText ?? rewardDesc,
                          style: PushinTheme.body2,
                        ),
                      ],
                    ),
                  ),
                  if (isLocked)
                    const Icon(
                      Icons.lock,
                      color: Colors.white54,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getWorkoutIcon(String type) {
    switch (type.toLowerCase()) {
      case 'push-ups':
        return Icons.fitness_center;
      case 'squats':
        return Icons.airline_seat_legroom_normal;
      default:
        return Icons.sports_gymnastics;
    }
  }

  String _capitalize(String text) {
    return text.split('-').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}

/// EARNING state view (workout in progress)
class _EarningStateView extends StatelessWidget {
  final PushinAppController controller;

  const _EarningStateView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final progress = controller.getWorkoutProgress(now);

    return Container(
      decoration: const BoxDecoration(
        gradient: PushinTheme.surfaceGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _showCancelConfirmation(context);
                },
              ),
              title: const Text('Workout in Progress'),
            ),

            const Spacer(),

            // Progress ring
            Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: PushinTheme.surfaceDark,
                        valueColor: const AlwaysStoppedAnimation(
                            PushinTheme.primaryBlue),
                      ),
                    ),
                    Text(
                      '${(progress * 20).round()} / 20',
                      style: PushinTheme.headline1,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: PushinTheme.spacingLg),

            const Text(
              'Push-Ups Completed',
              style: PushinTheme.headline3,
            ),

            const Spacer(),

            // Complete button (for manual counter MVP)
            Padding(
              padding: EdgeInsets.all(PushinTheme.spacingLg),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PushinTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
                    ),
                  ),
                  onPressed: () async {
                    await controller.completeWorkout(20);
                  },
                  child: const Text(
                    'Complete Workout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Workout?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Going'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PushinAppController>().cancelWorkout();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// UNLOCKED state view
class _UnlockedStateView extends StatelessWidget {
  final PushinAppController controller;
  final DateTime now;

  const _UnlockedStateView({
    required this.controller,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final remainingSeconds = controller.getUnlockTimeRemaining(now);
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    return Container(
      decoration: const BoxDecoration(
        gradient: PushinTheme.surfaceGradient,
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(PushinTheme.spacingLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: PushinTheme.successGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: PushinTheme.successGreen,
                  ),
                ),

                SizedBox(height: PushinTheme.spacingXl),

                const Text(
                  'Apps Unlocked!',
                  style: PushinTheme.appsText,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: PushinTheme.spacingSm),

                const Text(
                  'Great work! Enjoy your screen time',
                  style: PushinTheme.body2,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: PushinTheme.spacingXl * 2),

                // Countdown timer with card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: PushinTheme.surfaceDark.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(PushinTheme.radiusLg),
                    border: Border.all(
                      color: PushinTheme.successGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: PushinTheme.headline1.copyWith(
                          fontSize: 72,
                          color: PushinTheme.successGreen,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                      SizedBox(height: PushinTheme.spacingSm),
                      Text(
                        'TIME REMAINING',
                        style: PushinTheme.body2.copyWith(
                          color: PushinTheme.textSecondary,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Earn More Time button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PushinTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PushinTheme.radiusMd),
                      ),
                    ),
                    onPressed: () async {
                      await controller.startWorkout('push-ups', 20);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Earn More Time',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: PushinTheme.spacingMd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// EXPIRED state view (grace period)
class _ExpiredStateView extends StatelessWidget {
  final PushinAppController controller;
  final DateTime now;

  const _ExpiredStateView({
    required this.controller,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final graceRemaining = controller.getGracePeriodRemaining(now);

    return Container(
      color: PushinTheme.errorRed.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.timer_off,
              size: 64,
              color: PushinTheme.warningYellow,
            ),
            const SizedBox(height: PushinTheme.spacingMd),
            const Text(
              "Time's Up!",
              style: PushinTheme.headline2,
            ),
            const SizedBox(height: PushinTheme.spacingMd),
            Text(
              'Grace period: $graceRemaining seconds',
              style: PushinTheme.body1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment success overlay
class _PaymentSuccessOverlay extends StatelessWidget {
  final SubscriptionStatus subscriptionStatus;

  const _PaymentSuccessOverlay({
    required this.subscriptionStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PushinTheme.successGreen.withOpacity(0.9),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(PushinTheme.spacingXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: PushinTheme.spacingXl),
                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: PushinTheme.spacingMd),
                Text(
                  'Welcome to ${subscriptionStatus.displayName}!',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: PushinTheme.spacingSm),
                const Text(
                  'Your premium features are now unlocked.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: PushinTheme.spacingXl * 2),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: PushinTheme.successGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PushinTheme.radiusLg),
                    ),
                  ),
                  onPressed: () {
                    // Dismiss the overlay
                    context
                        .read<PushinAppController>()
                        .paymentSuccessState
                        .value = null;
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

/// Payment cancel overlay
class _PaymentCancelOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: PushinTheme.warningYellow.withOpacity(0.9),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(PushinTheme.spacingXl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: PushinTheme.spacingXl),
                const Text(
                  'Payment Canceled',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: PushinTheme.spacingMd),
                const Text(
                  'No charges were made to your card.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: PushinTheme.spacingXl * 2),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: PushinTheme.warningYellow,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PushinTheme.radiusLg),
                    ),
                  ),
                  onPressed: () {
                    // Dismiss the overlay
                    context
                        .read<PushinAppController>()
                        .paymentCancelState
                        .value = false;
                  },
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
