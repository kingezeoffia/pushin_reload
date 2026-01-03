import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'improved_water_intake_widget.dart';

// =============================================================================
// SOPHISTICATED DESIGN SYSTEM - Clean & Minimal
// =============================================================================

class _SophisticatedCardStyle {
  // Clean, minimal card styling matching GreetingCard aesthetic
  static BoxDecoration cleanCard() {
    return BoxDecoration(
      // Subtle background matching GreetingCard
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
        width: 1,
      ),
    );
  }
}

// =============================================================================
// WORKOUT DATA MODEL
// =============================================================================

class WorkoutData {
  final String type;
  final int duration;
  final IconData icon;

  const WorkoutData({
    required this.type,
    required this.duration,
    required this.icon,
  });
}

// =============================================================================
// STATS WIDGETS GRID - Main Container
// =============================================================================

class StatsWidgetsGrid extends StatelessWidget {
  const StatsWidgetsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      final mediaQuery = MediaQuery.of(context);
      final screenWidth = mediaQuery.size.width;
      final isSmallScreen = screenWidth < 375;

      final cardSpacing = isSmallScreen ? 10.0 : 12.0;
      final verticalSpacing = isSmallScreen ? 10.0 : 12.0;

      return Column(
        children: [
          // Row 1: Most Used Apps + Screen Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: MostUsedAppsWidget(
                  apps: const [
                    AppUsageData(
                        name: 'Instagram',
                        usageTime: 2.5,
                        icon: Icons.camera_alt),
                    AppUsageData(
                        name: 'YouTube',
                        usageTime: 1.8,
                        icon: Icons.play_circle_filled),
                    AppUsageData(
                        name: 'TikTok', usageTime: 1.2, icon: Icons.music_note),
                  ],
                  delay: 0,
                  compact: isSmallScreen,
                ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                flex: 1,
                child: ScreentimeWidget(
                  hoursUsed: 3.5,
                  dailyLimit: 8.0,
                  delay: 100,
                  compact: isSmallScreen,
                ),
              ),
            ],
          ),

          SizedBox(height: verticalSpacing),

          // Row 2: Steps Bar (Full Width)
          StepsBarWidget(
            steps: 7079,
            delay: 200,
            compact: isSmallScreen,
          ),

          SizedBox(height: verticalSpacing),

          // Row 3: Water Intake + Workouts
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 3,
                fit: FlexFit.tight,
                child: ImprovedWaterIntakeWidget(
                  current: 2.08,
                  target: 2.5,
                  delay: 400,
                  compact: isSmallScreen,
                ),
              ),
              SizedBox(width: cardSpacing),
              Flexible(
                flex: 4,
                fit: FlexFit.tight,
                child: WorkoutsWidget(
                  workouts: const [
                    WorkoutData(
                        type: 'Running',
                        duration: 45,
                        icon: Icons.directions_run),
                    WorkoutData(
                        type: 'Cycling',
                        duration: 30,
                        icon: Icons.directions_bike),
                    WorkoutData(
                        type: 'Strength',
                        duration: 35,
                        icon: Icons.fitness_center),
                  ],
                  delay: 300,
                  compact: isSmallScreen,
                ),
              ),
            ],
          ),
        ],
      );
    } catch (e, stackTrace) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.red,
        child: Text('Error: $e\n$stackTrace',
            style: const TextStyle(color: Colors.white)),
      );
    }
  }
}

// =============================================================================
// MOST USED APPS WIDGET - Premium Design
// =============================================================================

class AppUsageData {
  final String name;
  final double usageTime;
  final IconData icon;

  const AppUsageData({
    required this.name,
    required this.usageTime,
    required this.icon,
  });
}

class MostUsedAppsWidget extends StatefulWidget {
  final List<AppUsageData> apps;
  final int delay;
  final bool compact;

  const MostUsedAppsWidget({
    super.key,
    required this.apps,
    this.delay = 0,
    this.compact = false,
  });

  @override
  State<MostUsedAppsWidget> createState() => _MostUsedAppsWidgetState();
}

class _MostUsedAppsWidgetState extends State<MostUsedAppsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const _accentColor = Color(0xFF7C8CFF);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          height: widget.compact ? 165 : 185,
          padding: EdgeInsets.all(widget.compact ? 14 : 18),
          decoration: _SophisticatedCardStyle.cleanCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with clean icon
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.phone_android_rounded,
                      color: _accentColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Most Used Apps',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Apps list
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.apps.length,
                  itemBuilder: (context, index) {
                    final app = widget.apps[index];
                    final isFirst = index == 0;

                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: index == widget.apps.length - 1 ? 0 : 12),
                      child: Row(
                        children: [
                          // Rank badge
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: isFirst
                                  ? LinearGradient(colors: [
                                      _accentColor,
                                      const Color(0xFF60A5FA)
                                    ])
                                  : null,
                              color: isFirst
                                  ? null
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isFirst
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // App icon
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child:
                                Icon(app.icon, color: _accentColor, size: 16),
                          ),
                          const SizedBox(width: 10),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${app.usageTime}h today',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SCREENTIME WIDGET - Clean Minimal Design
// =============================================================================

class ScreentimeWidget extends StatefulWidget {
  final double hoursUsed;
  final double dailyLimit;
  final int delay;
  final bool compact;

  const ScreentimeWidget({
    super.key,
    required this.hoursUsed,
    required this.dailyLimit,
    this.delay = 0,
    this.compact = false,
  });

  @override
  State<ScreentimeWidget> createState() => _ScreentimeWidgetState();
}

class _ScreentimeWidgetState extends State<ScreentimeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = widget.hoursUsed.floor();
    final minutes = ((widget.hoursUsed - hours) * 60).round();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: widget.compact ? 165 : 185,
        padding: EdgeInsets.all(widget.compact ? 14 : 16),
        decoration: _SophisticatedCardStyle.cleanCard(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hours - large and bold at top
            Text(
              '${hours}h',
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 36 : 44,
                fontWeight: FontWeight.w700,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),

            const SizedBox(height: 1),

            // Minutes - no outline/pill style
            Text(
              '${minutes} min',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: widget.compact ? 13 : 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),

            const SizedBox(height: 8),

            // Label at bottom
            Text(
              'Screen Time',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: widget.compact ? 10 : 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// STEPS BAR WIDGET - Premium Design (THICKER BAR - 16px height)
// =============================================================================

class StepsBarWidget extends StatefulWidget {
  final int steps;
  final int delay;
  final bool compact;

  const StepsBarWidget({
    super.key,
    required this.steps,
    this.delay = 0,
    this.compact = false,
  });

  @override
  State<StepsBarWidget> createState() => _StepsBarWidgetState();
}

class _StepsBarWidgetState extends State<StepsBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late Animation<double> _fadeAnimation;

  static const _accentColor = Color(0xFF4ADE80);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    final progress = (widget.steps / 10000.0).clamp(0.0, 1.0);
    _progressAnimation = Tween<double>(begin: 0.0, end: progress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)},${(number % 1000).toString().padLeft(3, '0')}';
    }
    return number.toString();
  }

  int _calculateCalories(int steps) => (steps * 0.045).round();

  @override
  Widget build(BuildContext context) {
    final calories = _calculateCalories(widget.steps);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: widget.compact ? 145 : 165,
        padding: EdgeInsets.all(widget.compact ? 16 : 20),
        decoration: _SophisticatedCardStyle.cleanCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Clean icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.directions_walk_rounded,
                        color: _accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatNumber(widget.steps),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          'steps today',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Calories badge - clean and minimal
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFB347).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFFB347),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$calories kcal',
                        style: const TextStyle(
                          color: Color(0xFFFFB347),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Progress bar - THICKER (16px) with gradient glow
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    // Thick progress bar with glow
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: Stack(
                        children: [
                          // Clean progress
                          FractionallySizedBox(
                            widthFactor: _progressAnimation.value,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: _accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        Text('5K',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        Text('10K',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// WORKOUTS WIDGET - Premium Design
// =============================================================================

class WorkoutsWidget extends StatefulWidget {
  final List<WorkoutData> workouts;
  final int delay;
  final bool compact;

  const WorkoutsWidget({
    super.key,
    required this.workouts,
    this.delay = 0,
    this.compact = false,
  });

  @override
  State<WorkoutsWidget> createState() => _WorkoutsWidgetState();
}

class _WorkoutsWidgetState extends State<WorkoutsWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const _accentColor = Color(0xFF4ADE80);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          height: widget.compact ? 165 : 185,
          padding: EdgeInsets.all(widget.compact ? 14 : 18),
          decoration: _SophisticatedCardStyle.cleanCard(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with clean icon
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: _accentColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Recent Workouts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Workouts list
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.workouts.length,
                  itemBuilder: (context, index) {
                    final workout = widget.workouts[index];
                    final isFirst = index == 0;

                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: index == widget.workouts.length - 1 ? 0 : 12),
                      child: Row(
                        children: [
                          // Rank badge
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              gradient: isFirst
                                  ? const LinearGradient(colors: [
                                      Color(0xFF4ADE80),
                                      Color(0xFF22C55E)
                                    ])
                                  : null,
                              color: isFirst
                                  ? null
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isFirst
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Workout icon
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(workout.icon,
                                color: _accentColor, size: 16),
                          ),
                          const SizedBox(width: 10),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  workout.type,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${workout.duration} min',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
