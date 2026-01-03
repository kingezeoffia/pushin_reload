import 'package:flutter/material.dart';
import '../../theme/dashboard_design_tokens.dart';
import '../../../services/streak_tracker.dart';

class SettingsGreetingCard extends StatefulWidget {
  final String userName;

  const SettingsGreetingCard({
    super.key,
    required this.userName,
  });

  @override
  State<SettingsGreetingCard> createState() => _SettingsGreetingCardState();
}

class _SettingsGreetingCardState extends State<SettingsGreetingCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Animation controllers for stats
  late AnimationController _statsEntranceController;
  late Animation<double> _statsEntranceAnimation;

  // Settings-related stats
  int _daysUsingApp = 0;
  int _settingsCustomized = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();

    // Main card animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    // Stats entrance animation - simple and fast
    _statsEntranceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _statsEntranceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statsEntranceController, curve: Curves.easeOut),
    );

    _controller.forward().then((_) {
      // Start stats entrance animation immediately after main card animation
      if (mounted) {
        _statsEntranceController.forward();
      }
    });

    // Load settings stats
    _loadSettingsStats();
  }

  @override
  void dispose() {
    _controller.dispose();
    _statsEntranceController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsStats() async {
    try {
      // For now, we'll use placeholder data
      // In a real implementation, you'd track these in your backend
      final totalWorkouts = await StreakTracker.getTotalWorkouts();

      if (mounted) {
        setState(() {
          // Mock data - in real app, this would come from user preferences/analytics
          _daysUsingApp = (totalWorkouts / 2).round().clamp(1, 365); // Estimate based on workouts
          _settingsCustomized = 3; // Mock: number of customized settings
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error loading settings stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildAnimatedStat({
    required int value,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Animated number
          AnimatedBuilder(
            animation: _statsEntranceController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 0),

          // Label
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: DashboardDesignTokens.cardGradient,
          borderRadius: BorderRadius.circular(DashboardDesignTokens.cardRadius),
          boxShadow: DashboardDesignTokens.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                children: [
                  TextSpan(
                    text: '${_getGreeting()}, ',
                    style: const TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: '${widget.userName}!',
                    style: TextStyle(
                      color: DashboardDesignTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Motivational message for settings
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  color: DashboardDesignTokens.textSecondary,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Customize your experience! '),
                  const WidgetSpan(
                    child: Icon(
                      Icons.settings,
                      size: 18,
                      color: DashboardDesignTokens.accentGreen,
                    ),
                  ),
                  const TextSpan(
                    text: ' Fine-tune your preferences to ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const WidgetSpan(
                    child: Icon(
                      Icons.star,
                      size: 18,
                      color: DashboardDesignTokens.accentGreen,
                    ),
                  ),
                  const TextSpan(
                    text: ' make Pushin truly yours',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Animated Stats Display
            _isLoadingStats
                ? Container(
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _statsEntranceAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _statsEntranceAnimation.value.clamp(0.0, 1.0),
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              // Days using app
                              Expanded(
                                child: _buildAnimatedStat(
                                  value: _daysUsingApp,
                                  label: 'Days Using App',
                                ),
                              ),

                              // Divider
                              Container(
                                width: 1,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),

                              // Settings customized
                              Expanded(
                                child: _buildAnimatedStat(
                                  value: _settingsCustomized,
                                  label: 'Settings Customized',
                                ),
                              ),

                              // Divider
                              Container(
                                width: 1,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),

                              // App version indicator
                              Expanded(
                                child: _buildAnimatedStat(
                                  value: 1,
                                  label: 'App Version',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

