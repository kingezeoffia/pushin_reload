import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/pushin_app_controller.dart';
import '../../domain/PushinState.dart';
import '../../state/auth_state_provider.dart';
import '../../services/PaymentService.dart';
import '../widgets/AppBlockOverlay.dart';
import '../widgets/EmergencyUnlockDialog.dart';
import '../widgets/GOStepsBackground.dart';
import '../widgets/PressAnimationButton.dart';
import '../widgets/screentime_report_trigger.dart';
import 'enhanced_settings_screen.dart';
import 'paywall/PaywallScreen.dart';
import 'workout/RepCounterScreen.dart';
import 'workout/WorkoutSelectionScreen.dart';
import '../../services/rating_service.dart';

/// Home screen showing current state and actions.
///
/// Displays:
/// - LOCKED: Block status card + workout selection
/// - EARNING: Workout tracker (rep counter)
/// - UNLOCKED: Countdown timer + usage stats
/// - EXPIRED: Grace period overlay
///
/// GO Club-inspired design with dark theme, gradients, pill buttons
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    // Register as lifecycle observer to detect app resume
    WidgetsBinding.instance.addObserver(this);

    // Set up intent callback to auto-navigate to workout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<PushinAppController>();
      controller.onStartWorkoutFromIntent = (blockedApp) {
        print('HomeScreen: Navigating to workout from intent');
        // Navigate to workout selection screen
        _navigateWithSlideAnimation(context, const WorkoutSelectionScreen());
      };
    });

    // Set up rating check callback to be called after workout completion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<PushinAppController>();
      controller.onCheckWorkoutRating = () {
        if (context.mounted) {
          RatingService.create().then((s) => s.checkWorkoutRating(context));
        }
      };
    });

    // Check for "Second App Launch" rating trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RatingService.create().then((s) => s.checkAppLaunchRating(context));
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app comes back to foreground, check if overlay should show
    if (state == AppLifecycleState.resumed) {
      final controller = context.read<PushinAppController>();
      controller.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthStateProvider>(context);
    print('🧪 HomeScreen - justRegistered=${authProvider.justRegistered}, '
        'isGuestMode=${authProvider.isGuestMode}, '
        'guestCompletedSetup=${authProvider.guestCompletedSetup}');

    return Scaffold(
      key: const ValueKey('home_screen_marker'),
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.28,
        child: Stack(
          children: [
            // Invisible trigger for iOS Data Collection
            const ScreenTimeReportTrigger(),

            // Main content
            Consumer<PushinAppController>(
              builder: (context, controller, _) {
                return _buildStateContent(context, controller);
              },
            ),

            // Block overlay (shown when blocked app launched or daily cap hit)
            Consumer<PushinAppController>(
              builder: (context, controller, _) {
                final overlayState = controller.blockOverlayState.value;
                if (overlayState != null) {
                  final isSuccessOverlay =
                      overlayState.reason == BlockReason.workoutCompleted;

                  final emergencyEnabled = isSuccessOverlay
                      ? false
                      : controller.emergencyUnlockEnabled;
                  return AppBlockOverlay(
                    key: ValueKey(
                        'overlay_${overlayState.reason}_${emergencyEnabled}'),
                    reason: overlayState.reason,
                    blockedAppName: overlayState.appName,
                    emergencyUnlockEnabled: emergencyEnabled,
                    emergencyUnlocksRemaining:
                        controller.emergencyUnlocksRemaining,
                    onStartWorkout: () {
                      // For success overlay, just dismiss without navigation
                      if (isSuccessOverlay) {
                        controller.dismissBlockOverlay();
                      } else {
                        controller.dismissBlockOverlay();
                        _navigateWithSlideAnimation(
                            context, const WorkoutSelectionScreen());
                      }
                    },
                    onEmergencyUnlock: isSuccessOverlay
                        ? null
                        : () async {
                            // Check if user has paid subscription for emergency unlock
                            final authProvider =
                                context.read<AuthStateProvider>();
                            final paymentService = PaymentConfig.createService();

                            final currentId = authProvider.currentUser?.id;
                            if (currentId == null) {
                              // Show paywall for guest users trying to use emergency unlock
                              HapticFeedback.mediumImpact();
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PaywallScreen(),
                                  ),
                                );
                              }
                              return;
                            }

                            final subscriptionStatus =
                                await paymentService.checkSubscriptionStatus(
                              userId: currentId,
                            );

                            final isPaidUser =
                                subscriptionStatus?.isPaid ?? false;

                            if (!isPaidUser) {
                              // Show paywall for free users trying to use emergency unlock
                              HapticFeedback.mediumImpact();
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PaywallScreen(),
                                  ),
                                );
                              }
                              return;
                            }

                            HapticFeedback.mediumImpact();
                            final confirmed = await EmergencyUnlockDialog.show(
                              context: context,
                              appName: overlayState.appName ?? 'App',
                              unlockMinutes: controller.emergencyUnlockMinutes,
                              unlocksRemaining:
                                  controller.emergencyUnlocksRemaining,
                            );
                            if (confirmed) {
                              final success =
                                  await controller.useEmergencyUnlock(
                                overlayState.appName ?? 'App',
                              );
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Emergency unlock activated (${controller.emergencyUnlockMinutes} minutes)',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    backgroundColor: const Color(0xFFFFB347),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    onGoToSettings: isSuccessOverlay
                        ? null
                        : () {
                            _navigateWithSlideAnimation(
                                context, const EnhancedSettingsScreen());
                          },
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Settings button
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  _navigateWithSlideAnimation(
                      context, const EnhancedSettingsScreen());
                },
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  padding: const EdgeInsets.all(12),
                ),
              ),
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

  Future<void> _navigateWithSlideAnimation(
      BuildContext context, Widget screen,
      [RouteSettings? settings]) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );
  }
}

/// LOCKED state view - Onboarding-style design
class _LockedStateView extends StatefulWidget {
  final PushinAppController controller;

  const _LockedStateView({required this.controller});

  @override
  State<_LockedStateView> createState() => _LockedStateViewState();
}

class _LockedStateViewState extends State<_LockedStateView> {
  @override
  Widget build(BuildContext context) {
    final homeState = context.findAncestorStateOfType<_HomeScreenState>()!;

    return AnimatedBuilder(
      animation: homeState._animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, homeState._slideAnimation.value),
          child: Opacity(
            opacity: homeState._fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spacer for top
            SizedBox(height: MediaQuery.of(context).size.height * 0.06),

            // Main headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Apps Are',
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
                      'Blocked',
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
                    'Complete a workout to unlock screen time',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Workout option card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _OnboardingStyleWorkoutCard(
                icon: Icons.fitness_center,
                title: 'Push-Ups',
                subtitle: widget.controller
                    .getWorkoutRewardDescription('push-ups', 20),
                onTap: () async {
                  await _navigateWithSlideAnimation(
                      context,
                      const RepCounterScreen(
                        workoutType: 'push-ups',
                        targetReps: 20,
                        desiredScreenTimeMinutes: 10,
                      ),
                      const RouteSettings(name: 'QuickStart'));
                },
              ),
            ),

            const Spacer(),

            // Start Workout Button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
              child: PressAnimationButton(
                onTap: () async {
                  await _navigateWithSlideAnimation(
                      context,
                      const WorkoutSelectionScreen(),
                      const RouteSettings(name: 'WorkoutSelection'));
                },
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
                      'Choose Workout',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A2A6A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Quick start subtitle
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: Text(
                  'Or tap the card above for quick start',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateWithSlideAnimation(
      BuildContext context, Widget screen,
      [RouteSettings? settings]) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

/// Onboarding-style workout card
class _OnboardingStyleWorkoutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OnboardingStyleWorkoutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 32,
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
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: Colors.white.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// EARNING state view (workout in progress) - Onboarding style
class _EarningStateView extends StatelessWidget {
  final PushinAppController controller;

  const _EarningStateView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final progress = controller.getWorkoutProgress(now);

    return SafeArea(
      child: Column(
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.8)),
                  onPressed: () => _showCancelConfirmation(context),
                ),
                const Spacer(),
                Text(
                  'Workout in Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),

          const Spacer(),

          // Progress ring with gradient
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
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFF6060FF)),
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
                    ).createShader(bounds),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      '${(progress * 20).round()} / 20',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Push-Ups Completed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          const Spacer(),

          // Complete button - pill style
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
            child: PressAnimationButton(
              onTap: () async {
                await controller.completeWorkout(20);
              },
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
                    'Complete Workout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A2A6A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmation(BuildContext context) {
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
              Icon(
                Icons.warning_amber_rounded,
                size: 56,
                color: Colors.amber.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Cancel Workout?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your progress will be lost.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () {
                        Navigator.pop(context);
                        context.read<PushinAppController>().cancelWorkout();
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
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
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Center(
                          child: Text(
                            'Keep Going',
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

/// UNLOCKED state view - Onboarding style
class _UnlockedStateView extends StatefulWidget {
  final PushinAppController controller;
  final DateTime now;

  const _UnlockedStateView({
    required this.controller,
    required this.now,
  });

  @override
  State<_UnlockedStateView> createState() => _UnlockedStateViewState();
}

class _UnlockedStateViewState extends State<_UnlockedStateView> {
  @override
  Widget build(BuildContext context) {
    final homeState = context.findAncestorStateOfType<_HomeScreenState>()!;
    final remainingSeconds =
        widget.controller.getUnlockTimeRemaining(widget.now);
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    return AnimatedBuilder(
      animation: homeState._animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, homeState._slideAnimation.value),
          child: Opacity(
            opacity: homeState._fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spacer for top
            SizedBox(height: MediaQuery.of(context).size.height * 0.06),

            // Main headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Apps',
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
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                    ),
                    blendMode: BlendMode.srcIn,
                    child: const Text(
                      'Unlocked!',
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
                    'Great work! Enjoy your screen time',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Countdown timer card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TIME REMAINING',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Earn More Time button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
              child: PressAnimationButton(
                onTap: () {
                  _navigateWithSlideAnimation(
                      context, const WorkoutSelectionScreen());
                },
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center,
                            size: 20, color: Color(0xFF2A2A6A)),
                        SizedBox(width: 8),
                        Text(
                          'Earn More Time',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A2A6A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
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

  Future<void> _navigateWithSlideAnimation(
      BuildContext context, Widget screen,
      [RouteSettings? settings]) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

/// EXPIRED state view (grace period) - Onboarding style
class _ExpiredStateView extends StatefulWidget {
  final PushinAppController controller;
  final DateTime now;

  const _ExpiredStateView({
    required this.controller,
    required this.now,
  });

  @override
  State<_ExpiredStateView> createState() => _ExpiredStateViewState();
}

class _ExpiredStateViewState extends State<_ExpiredStateView> {
  @override
  Widget build(BuildContext context) {
    final homeState = context.findAncestorStateOfType<_HomeScreenState>()!;
    final graceRemaining =
        widget.controller.getGracePeriodRemaining(widget.now);

    return AnimatedBuilder(
      animation: homeState._animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, homeState._slideAnimation.value),
          child: Opacity(
            opacity: homeState._fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spacer for top
            SizedBox(height: MediaQuery.of(context).size.height * 0.06),

            // Main headline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Time's",
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
                      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                    ),
                    blendMode: BlendMode.srcIn,
                    child: const Text(
                      'Up!',
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
                    'Complete a workout to continue using apps',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.6),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Grace period card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 40,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.timer_off,
                      size: 64,
                      color: Colors.amber.shade400,
                    ),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        '$graceRemaining',
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SECONDS GRACE PERIOD',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Start Workout button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
              child: PressAnimationButton(
                onTap: () {
                  _navigateWithSlideAnimation(
                      context, const WorkoutSelectionScreen());
                },
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
                      'Start Workout Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A2A6A),
                        letterSpacing: -0.3,
                      ),
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

  void _navigateWithSlideAnimation(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

/// Payment success overlay - Onboarding style
class _PaymentSuccessOverlay extends StatelessWidget {
  final SubscriptionStatus subscriptionStatus;

  const _PaymentSuccessOverlay({
    required this.subscriptionStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.28,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.06),

              // Main headline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment',
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
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'Successful!',
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
                      'Welcome to ${subscriptionStatus.displayName}!',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Success card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Your premium features are now unlocked',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Continue button
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                child: PressAnimationButton(
                  onTap: () async {
                    context
                        .read<PushinAppController>()
                        .paymentSuccessState
                        .value = null;
                        
                    // Check for rating trigger (new subscription)
                    if (context.mounted) {
                      RatingService.create().then((s) => s.checkSubscriptionRating(context));
                    }
                  },
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Payment cancel overlay - Onboarding style
class _PaymentCancelOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.28,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.06),

              // Main headline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment',
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
                        colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'Canceled',
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
                      'No charges were made to your card',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Info card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cancel,
                          size: 64,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'You can try again anytime',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Continue button
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                child: PressAnimationButton(
                  onTap: () {
                    context
                        .read<PushinAppController>()
                        .paymentCancelState
                        .value = false;
                  },
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
