import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dashboard/greeting_card.dart';
import '../widgets/workouts/stats_widgets_grid.dart';
import '../widgets/GOStepsBackground.dart';
import '../theme/dashboard_design_tokens.dart';
import '../../../services/streak_tracker.dart';
import '../../../state/auth_state_provider.dart';
import 'paywall/PaywallScreen.dart';

class EnhancedDashboardScreen extends StatefulWidget {
  const EnhancedDashboardScreen({super.key});

  @override
  State<EnhancedDashboardScreen> createState() =>
      _EnhancedDashboardScreenState();
}

class _EnhancedDashboardScreenState extends State<EnhancedDashboardScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late AnimationController _pageLoadController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentStreak = 0;
  bool _isLoading = true;
  String _displayName = 'Your Name';

  // TODO: MVP - Temporarily disable Today's Activity section
  // Set to true to enable the activity tracking widgets
  static const bool _showTodaysActivity = false;

  @override
  void initState() {
    super.initState();
    _loadAllStreakData();
    _loadDisplayName();
    _pageLoadController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pageLoadController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageLoadController,
      curve: Curves.easeOutCubic,
    ));

    _pageLoadController.forward();
  }

  /// Lädt alle Streak-Daten beim Start
  Future<void> _loadAllStreakData() async {
    setState(() => _isLoading = true);

    try {
      final currentStreak = await StreakTracker.getCurrentStreak();

      setState(() {
        _currentStreak = currentStreak;
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Streak-Daten: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDisplayName = prefs.getString('display_name');

    // If we have a saved display name that's not the default, use it
    if (savedDisplayName != null && savedDisplayName != 'Your Name') {
      setState(() {
        _displayName = savedDisplayName;
      });
      return;
    }

    // Otherwise, try to get the account name and use it as display name
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    final accountName = authProvider.currentUser?.name;

    if (accountName != null && accountName.isNotEmpty) {
      setState(() {
        _displayName = accountName;
      });
      // Save it to SharedPreferences so it persists
      await prefs.setString('display_name', accountName);
    } else {
      // Fall back to default
      setState(() {
        _displayName = savedDisplayName ?? 'Your Name';
      });
    }
  }

  void _navigateToPaywall(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PaywallScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // Start from bottom
          const end = Offset.zero; // End at normal position
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

  @override
  void dispose() {
    _scrollController.dispose();
    _pageLoadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Navigation spacing is now handled with SafeArea(bottom: false) and explicit padding

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          bottom:
              false, // Don't include bottom safe area - navigation pill handles this
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Beautiful Header (like workouts screen)
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

                  // Greeting Card
                  SliverToBoxAdapter(
                    child: _isLoading
                        ? const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : GreetingCard(
                            userName: _displayName,
                            streakDays: _currentStreak,
                          ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 28)),

                  // Today's Activity - Bold, eye-catching section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section header - prominent but not as big as Home
                          Row(
                            children: [
                              const Text(
                                'Today\'s Activity',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Pro badge
                              GestureDetector(
                                onTap: () => _navigateToPaywall(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: Color(0xFFFFB347),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          // Activity content - wrapped in clipping container to constrain blur effect
                          Container(
                            height: 580,
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                  DashboardDesignTokens.cardRadius),
                            ),
                            child: _showTodaysActivity
                                ? const StatsWidgetsGrid()
                                : const _ComingSoonActivityPreview(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),

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

                  // Bottom spacing - account for pill navigation
                  // Since SafeArea has bottom: false, we need space for navigation pill (64px) + margin (8px) + extra spacing (40px)
                  SliverToBoxAdapter(
                    child: SizedBox(height: 64 + 8 + 40),
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

/// Coming Soon preview for Today's Activity section
class _ComingSoonActivityPreview extends StatelessWidget {
  const _ComingSoonActivityPreview();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToPaywall(context),
      child: Stack(
        children: [
          // Gaussian blurred preview of actual widgets
          Stack(
            children: [
              const Opacity(
                opacity: 0.08, // Even more subtle visibility
                child: StatsWidgetsGrid(),
              ),
              BackdropFilter(
                filter: ui.ImageFilter.blur(
                    sigmaX: 4.0, sigmaY: 4.0), // Reduced blur strength
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ],
          ),

          // Soft gradient overlay for cohesion - contained within bounds
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.05),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),

          // Content overlay - centered with clean minimal styling
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Lock icon - clean, no container
                Icon(
                  Icons.lock_outline,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 40,
                ),

                const SizedBox(height: 20),

                // Coming Soon text - bold, matches app headers
                const Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Feature description - subtle, clean
                Text(
                  'Track screen time, workout progress,\nwater intake and even steps',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Pro badge - minimal, no border
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Available in Pro',
                    style: TextStyle(
                      color: Color(0xFFFFB347),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPaywall(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PaywallScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // Start from bottom
          const end = Offset.zero; // End at normal position
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
