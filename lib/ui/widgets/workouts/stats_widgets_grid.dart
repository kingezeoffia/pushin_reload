import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'improved_water_intake_widget.dart';
import '../../../services/HealthKitService.dart';
import '../../../services/WorkoutHistoryService.dart';
import '../../../services/platform/ScreenTimeMonitor.dart';
import '../../../domain/WorkoutHistory.dart';
import '../../../state/pushin_app_controller.dart';

class _SophisticatedCardStyle {
  static BoxDecoration cleanCard() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
        width: 1,
      ),
    );
  }
}

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

class StatsWidgetsGrid extends StatefulWidget {
  const StatsWidgetsGrid({super.key});

  @override
  State<StatsWidgetsGrid> createState() => _StatsWidgetsGridState();
}

class _StatsWidgetsGridState extends State<StatsWidgetsGrid> {
  final HealthKitService _healthKit = HealthKitService();
  final WorkoutHistoryService _workoutHistoryService = WorkoutHistoryService();
  final ScreenTimeService _screenTimeService = ScreenTimeService();
  late HealthStats _healthStats = HealthStats.empty();
  List<WorkoutHistory> _recentWorkouts = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _workoutsLoading = true;
  late PushinAppController _controller;

  // Screen time data
  double _totalScreenTimeMinutes = 210.0; // Default 3.5 hours
  List<AppUsageInfo> _mostUsedApps = [];
  bool _screenTimeLoading = true;
  bool _screenTimeIsMockData = false;

  @override
  void initState() {
    super.initState();
    _controller = context.read<PushinAppController>();
    _controller.addListener(_onWorkoutCompleted);
    _checkPermissionAndLoad();
    _loadWorkoutHistory();
    _loadScreenTimeData();
  }

  @override
  void dispose() {
    _controller.removeListener(_onWorkoutCompleted);
    super.dispose();
  }

  void _onWorkoutCompleted() {
    // Reload workout history when controller notifies of changes
    _loadWorkoutHistory();
  }

  Future<void> _checkPermissionAndLoad() async {
    try {
      final hasPermission = await _healthKit.hasPermissions();

      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
        });
      }

      if (hasPermission) {
        await _loadHealthData();
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('StatsWidgetsGrid: Error checking permission: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWorkoutHistory() async {
    try {
      await _workoutHistoryService.initialize();
      final workouts = await _workoutHistoryService.getRecentWorkouts(limit: 3);
      if (mounted) {
        setState(() {
          _recentWorkouts = workouts;
          _workoutsLoading = false;
        });
      }
    } catch (e) {
      print('StatsWidgetsGrid: Error loading workout history: $e');
      if (mounted) {
        setState(() {
          _workoutsLoading = false;
        });
      }
    }
  }

  Future<void> _loadHealthData() async {
    try {
      final stats = await _healthKit.getTodayStats();

      if (mounted) {
        setState(() {
          _healthStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('StatsWidgetsGrid: Error loading health data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final granted = await _healthKit.requestAuthorization();

      if (granted && mounted) {
        setState(() {
          _hasPermission = true;
        });
        await _loadHealthData();
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('StatsWidgetsGrid: Error requesting permission: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadScreenTimeData() async {
    // Only load on iOS
    if (!Platform.isIOS) {
      if (mounted) {
        setState(() {
          _screenTimeLoading = false;
        });
      }
      return;
    }

    try {
      // Start monitoring to collect data (safe to call multiple times)
      try {
        await _screenTimeService.startScreenTimeMonitoring();
        print('✅ StatsWidgetsGrid: Started screen time monitoring');
      } catch (e) {
        print('⚠️ StatsWidgetsGrid: Could not start monitoring (may need permission): $e');
      }

      // Load screen time
      final screenTimeResponse = await _screenTimeService.getTodayScreenTime();

      // Load most used apps
      final appsResponse = await _screenTimeService.getMostUsedApps(limit: 3);

      if (mounted) {
        setState(() {
          _totalScreenTimeMinutes = screenTimeResponse.totalMinutes;
          _mostUsedApps = appsResponse.apps;
          _screenTimeIsMockData =
              screenTimeResponse.isMockData || appsResponse.isMockData;
          _screenTimeLoading = false;
        });
      }

      if (_screenTimeIsMockData) {
        print(
            '⚠️ StatsWidgetsGrid: Using mock screen time data - DeviceActivityReport extension needs to be added to Xcode');
      } else {
        print('✅ StatsWidgetsGrid: Loaded real screen time data');
      }
    } catch (e) {
      print('StatsWidgetsGrid: Error loading screen time data: $e');
      if (mounted) {
        setState(() {
          _screenTimeLoading = false;
          // Keep default mock values
        });
      }
    }
  }

  IconData _getIconForApp(String appName) {
    final lowerName = appName.toLowerCase();
    if (lowerName.contains('instagram')) return Icons.camera_alt;
    if (lowerName.contains('youtube')) return Icons.play_circle_filled;
    if (lowerName.contains('tiktok')) return Icons.music_note;
    if (lowerName.contains('twitter') || lowerName.contains('x')) return Icons.tag;
    if (lowerName.contains('facebook')) return Icons.facebook;
    if (lowerName.contains('snapchat')) return Icons.camera;
    if (lowerName.contains('whatsapp') || lowerName.contains('message')) return Icons.message;
    if (lowerName.contains('reddit')) return Icons.forum;
    if (lowerName.contains('netflix')) return Icons.tv;
    if (lowerName.contains('spotify')) return Icons.music_note;
    if (lowerName.contains('game')) return Icons.videogame_asset;
    if (lowerName.contains('safari') || lowerName.contains('chrome')) return Icons.public;
    return Icons.phone_android;
  }

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
                child: _screenTimeLoading
                    ? Container(
                        height: isSmallScreen ? 165 : 185,
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: _SophisticatedCardStyle.cleanCard(),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7C8CFF),
                          ),
                        ),
                      )
                    : MostUsedAppsWidget(
                        apps: _mostUsedApps
                            .map((app) => AppUsageData(
                                  name: app.name,
                                  usageTime: app.usageHours,
                                  icon: _getIconForApp(app.name),
                                ))
                            .toList(),
                        delay: 0,
                        compact: isSmallScreen,
                      ),
              ),
              SizedBox(width: cardSpacing),
              Expanded(
                flex: 1,
                child: _screenTimeLoading
                    ? Container(
                        height: isSmallScreen ? 165 : 185,
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: _SophisticatedCardStyle.cleanCard(),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF7C8CFF),
                          ),
                        ),
                      )
                    : ScreentimeWidget(
                        hoursUsed: _totalScreenTimeMinutes / 60.0,
                        dailyLimit: 8.0,
                        delay: 100,
                        compact: isSmallScreen,
                      ),
              ),
            ],
          ),

          SizedBox(height: verticalSpacing),

          // Row 2: Steps Bar (Full Width) - Now using real Apple Health data
          _isLoading
              ? Container(
                  height: isSmallScreen ? 145 : 165,
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: _SophisticatedCardStyle.cleanCard(),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF4ADE80),
                    ),
                  ),
                )
              : StepsBarWidget(
                  steps: _healthStats.steps,
                  delay: 200,
                  compact: isSmallScreen,
                  hasPermission: _hasPermission,
                  onRequestPermission: _requestPermission,
                ),

          SizedBox(height: verticalSpacing),

          // Row 3: Water Intake + Workouts
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 9,
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
                flex: 11,
                fit: FlexFit.tight,
                child: _workoutsLoading
                    ? Container(
                        height: isSmallScreen ? 165 : 185,
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: _SophisticatedCardStyle.cleanCard(),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                      )
                    : WorkoutsWidget(
                        workouts: _recentWorkouts.isEmpty
                            ? [
                                WorkoutData(
                                    type: 'No workouts yet',
                                    duration: 0,
                                    icon: Icons.fitness_center),
                              ]
                            : _recentWorkouts
                                .map((workout) => WorkoutData(
                                      type: workout.displayName,
                                      duration: (workout.earnedTimeSeconds / 60)
                                          .round(),
                                      icon: workout.icon,
                                    ))
                                .toList(),
                        delay: 300,
                        compact: isSmallScreen,
                        showIcons: false, // Hide icons as requested
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

// Import the widget classes that are defined in the same file
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
                      Icons.access_time_filled,
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

class StepsBarWidget extends StatefulWidget {
  final int steps;
  final int delay;
  final bool compact;
  final bool hasPermission;
  final VoidCallback onRequestPermission;

  const StepsBarWidget({
    super.key,
    required this.steps,
    this.delay = 0,
    this.compact = false,
    required this.hasPermission,
    required this.onRequestPermission,
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
        decoration: _SophisticatedCardStyle.cleanCard(),
        child: widget.hasPermission
            ? // Show main content when permission granted
            Padding(
                padding: EdgeInsets.all(widget.compact ? 16 : 20),
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
                        // Calories badge - pill style
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB347).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
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
              )
            : // Show clean permission overlay when no permission
            Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Health icon - Apple Health style gradient
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFF3B8E), // Apple Health pink
                            Color(0xFFFF2D55), // Apple Health red
                          ],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Connect button - matching app style
                    GestureDetector(
                      onTap: widget.onRequestPermission,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Connect Apple Health',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A2A6A),
                            letterSpacing: -0.2,
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

class WorkoutsWidget extends StatefulWidget {
  final List<WorkoutData> workouts;
  final int delay;
  final bool compact;
  final bool showIcons;

  const WorkoutsWidget({
    super.key,
    required this.workouts,
    this.delay = 0,
    this.compact = false,
    this.showIcons = true,
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
                      Icons.directions_run_rounded,
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
                child: widget.workouts.length == 1 && widget.workouts[0].type == 'No workouts yet'
                    ? Center(
                        child: Text(
                          'No workouts yet',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      )
                    : ListView.builder(
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
                                // Workout icon - only show if showIcons is true
                                if (widget.showIcons) ...[
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
                                ],
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
                      )),
            ],
        ),
      ),
  ),
);
  }
}
