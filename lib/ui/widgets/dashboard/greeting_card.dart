import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/streak_tracker.dart';

/// Sleek, minimal GreetingCard matching onboarding aesthetic
/// - Clean typography
/// - Subtle container styling
/// - No heavy gradients or shadows
class GreetingCard extends StatefulWidget {
  final String userName;
  final int streakDays;
  final VoidCallback? onNameTap;

  const GreetingCard({
    super.key,
    required this.userName,
    required this.streakDays,
    this.onNameTap,
  });

  @override
  State<GreetingCard> createState() => _GreetingCardState();
}

class _GreetingCardState extends State<GreetingCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Stats animation
  late AnimationController _statsController;
  late Animation<double> _statsAnimation;

  // Stats data
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalWorkouts = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();

    // Main card animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // Stats entrance animation
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _statsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statsController, curve: Curves.easeOut),
    );

    _controller.forward().then((_) {
      if (mounted) {
        _statsController.forward();
      }
    });

    _loadStats();
  }

  @override
  void dispose() {
    _controller.dispose();
    _statsController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final currentStreak = await StreakTracker.getCurrentStreak();
      final longestStreak = await StreakTracker.getLongestStreak();
      final totalWorkouts = await StreakTracker.getTotalWorkouts();

      if (mounted) {
        setState(() {
          _currentStreak = currentStreak;
          _longestStreak = longestStreak;
          _totalWorkouts = totalWorkouts;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error loading streak stats: $e');
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
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          // Subtle, clean background - matching onboarding/settings
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting text - clean, elegant
            _buildGreeting(),

            const SizedBox(height: 14),

            // Motivational message - subtle styling
            _buildMotivationalMessage(),

            const SizedBox(height: 20),

            // Subtle divider
            Container(
              height: 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Stats row - clean, minimal
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final greeting = _getGreeting();
    final hasCustomName =
        widget.userName != 'Your Name' && widget.userName.isNotEmpty;

    final displayText = hasCustomName
        ? '$greeting, ${widget.userName}!'
        : '$greeting!';

    return Text(
      displayText,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.5,
        height: 1.2,
      ),
    );
  }

  Widget _buildMotivationalMessage() {
    return Row(
      children: [
        Icon(
          Icons.fitness_center_rounded,
          size: 16,
          color: const Color(0xFF4ADE80).withOpacity(0.9),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Complete a workout to unlock your apps',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.55),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    if (_isLoadingStats) {
      return SizedBox(
        height: 70,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.5),
              ),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _statsAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _statsAnimation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - _statsAnimation.value)),
            child: child,
          ),
        );
      },
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              value: _currentStreak,
              label: 'Current',
              accentColor: const Color(0xFF7C8CFF),
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _StatItem(
              value: _longestStreak,
              label: 'Best',
              accentColor: const Color(0xFFFFB347),
            ),
          ),
          _buildVerticalDivider(),
          Expanded(
            child: _StatItem(
              value: _totalWorkouts,
              label: 'Total',
              accentColor: const Color(0xFF4ADE80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

/// Individual stat item - clean, minimal design
class _StatItem extends StatelessWidget {
  final int value;
  final String label;
  final Color accentColor;

  const _StatItem({
    required this.value,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Value with subtle accent color
        Text(
          '$value',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        // Label - subtle
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.45),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
