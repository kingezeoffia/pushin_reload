import 'package:flutter/material.dart';
import '../../theme/settings_design_tokens.dart';
import '../../theme/dashboard_design_tokens.dart';
import '../../../services/streak_tracker.dart';

class UsageStatsCard extends StatefulWidget {
  final int delay;

  const UsageStatsCard({super.key, this.delay = 0});

  // Statische Methode um alle UsageStatsCard Instanzen zu aktualisieren
  static void refreshAllStats() {
    // Diese Methode kann von außen aufgerufen werden, um alle Cards zu aktualisieren
    // (wird über einen globalen Key oder Service implementiert)
  }

  @override
  State<UsageStatsCard> createState() => _UsageStatsCardState();
}

class _UsageStatsCardState extends State<UsageStatsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  int _totalWorkouts = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: SettingsDesignTokens.cardAnimation,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _loadStreakData();

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  /// Lädt alle Streak-Daten beim Start
  Future<void> _loadStreakData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait<int>([
        StreakTracker.getCurrentStreak(),
        StreakTracker.getLongestStreak(),
        StreakTracker.getTotalWorkouts(),
      ]);

      setState(() {
        _currentStreak = results[0];
        _longestStreak = results[1];
        _totalWorkouts = results[2];
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Streak-Daten: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Öffentliche Methode um die Daten zu aktualisieren (wird nach Workout-Completion aufgerufen)
  void refreshStats() {
    _loadStreakData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: DashboardDesignTokens.cardGradient,
            borderRadius:
                BorderRadius.circular(DashboardDesignTokens.cardRadius),
            boxShadow: DashboardDesignTokens.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      _isLoading ? '...' : '$_totalWorkouts',
                      'Workouts',
                      Icons.fitness_center,
                      DashboardDesignTokens.accentLightBlue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      _isLoading ? '...' : '$_currentStreak',
                      'Current Streak',
                      Icons.local_fire_department,
                      Colors.orange.shade400,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      _isLoading ? '...' : '$_longestStreak',
                      'Best Streak',
                      Icons.emoji_events,
                      Colors.orange.shade300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Weekly Goal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _isLoading ? '...' : '$_currentStreak/7 workouts',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value:
                      _isLoading ? 0.0 : (_currentStreak / 7).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    SettingsDesignTokens.primaryPurple,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
