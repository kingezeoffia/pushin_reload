import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/pushin_app_controller.dart';
import '../../state/auth_state_provider.dart';
import '../widgets/dashboard/greeting_card.dart';
import '../widgets/workouts/stats_widgets_grid.dart';
import '../widgets/GOStepsBackground.dart';
import 'settings/EditNameScreen.dart';
import 'paywall/PaywallScreen.dart';
import '../../services/rating_service.dart';

class EnhancedDashboardScreen extends StatefulWidget {
  const EnhancedDashboardScreen({super.key});

  @override
  State<EnhancedDashboardScreen> createState() =>
      _EnhancedDashboardScreenState();
}

class _EnhancedDashboardScreenState extends State<EnhancedDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _activityAnimationController;
  late Animation<double> _activitySlideAnimation;
  late AnimationController _advancedBadgeAnimationController;
  late Animation<double> _advancedBadgeSlideAnimation;
  late Animation<double> _advancedBadgeFadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeActivityAnimation();
    _checkRating();
  }

  Future<void> _checkRating() async {
    // Wait a short delay to ensure UI is ready
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      final s = await RatingService.create();
      if (mounted) {
        await s.checkWorkoutRating(context);
      }
    }
  }

  void _initializeActivityAnimation() {
    _activityAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _activitySlideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _activityAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _activityAnimationController.forward();

    // Initialize advanced badge animation
    _advancedBadgeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _advancedBadgeSlideAnimation = Tween<double>(
      begin: -20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _advancedBadgeAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _advancedBadgeFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _advancedBadgeAnimationController,
      curve: Curves.easeOut,
    ));

    // Start the advanced badge animation after a short delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _advancedBadgeAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _activityAnimationController.dispose();
    _advancedBadgeAnimationController.dispose();
    super.dispose();
  }

  void _navigateToEditName() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const EditNameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Smooth slide transition from right
          const begin = Offset(1.0, 0.0);
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
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.28,
        child: SafeArea(
          bottom: false,
          child: Consumer2<PushinAppController, AuthStateProvider>(
            builder: (context, controller, authProvider, _) {
              final userName = authProvider.currentUser?.name ?? 'Your Name';
              final streakDays = controller.getCurrentStreak();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Home title section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Home',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Track your progress and stay motivated',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Greeting Card - "Good morning" widget
                  SliverToBoxAdapter(
                    child: GreetingCard(
                      userName: userName,
                      streakDays: streakDays,
                      onNameTap: _navigateToEditName,
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

                  // Today's Activity section with 5 widgets
                  SliverToBoxAdapter(
                    child: controller.planTier == 'advanced'
                        ? AnimatedBuilder(
                            animation: _activityAnimationController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset:
                                    Offset(0, _activitySlideAnimation.value),
                                child: child,
                              );
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        "Today's Activity",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Upgrade badge - shows "ADVANCED" in orange for non-advanced users
                                      // Disappears when user upgrades to ADVANCED
                                      if (controller.planTier != 'advanced')
                                        AnimatedBuilder(
                                          animation:
                                              _advancedBadgeAnimationController,
                                          builder: (context, child) {
                                            return Transform.translate(
                                              offset: Offset(
                                                  _advancedBadgeSlideAnimation
                                                      .value,
                                                  0),
                                              child: Opacity(
                                                opacity:
                                                    _advancedBadgeFadeAnimation
                                                        .value,
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: GestureDetector(
                                            onTap: () {
                                              HapticFeedback.mediumImpact();
                                              _navigateToPaywall(context);
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'ADVANCED',
                                                style: TextStyle(
                                                  color: Color(
                                                      0xFFFFB347), // Orange for upgrade CTA
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Stats Widgets Grid containing 5 widgets including Apple Health connectable steps widget
                                  const StatsWidgetsGrid(),
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      "Today's Activity",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Upgrade badge - shows "ADVANCED" in orange for non-advanced users
                                    // Disappears when user upgrades to ADVANCED
                                    if (controller.planTier != 'advanced')
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          _navigateToPaywall(context);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: const Text(
                                            'ADVANCED',
                                            style: TextStyle(
                                              color: Color(
                                                  0xFFFFB347), // Orange for upgrade CTA
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Stats Widgets Grid containing 5 widgets including Apple Health connectable steps widget
                                const StatsWidgetsGrid(),
                              ],
                            ),
                          ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // New features coming soon - small and sleek
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'New features coming soon',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  const SliverToBoxAdapter(
                      child: SizedBox(height: 64 + 8 + 40)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _navigateToPaywall(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PaywallScreen(preSelectedPlan: 'advanced'),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }
}
