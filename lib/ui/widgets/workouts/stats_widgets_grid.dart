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
  final String iconAsset;

  const WorkoutData({
    required this.type,
    required this.duration,
    required this.iconAsset,
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
  double _totalScreenTimeMinutes = 319.0; // Default 5.3167 hours (5h 19min)
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
        print(
            '⚠️ StatsWidgetsGrid: Could not start monitoring (may need permission): $e');
      }

      // Load screen time
      final screenTimeResponse = await _screenTimeService.getTodayScreenTime();

      // Load most used apps
      final appsResponse = await _screenTimeService.getMostUsedApps(limit: 10);

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
                        apps: (_mostUsedApps.toList()
                              ..sort((a, b) =>
                                  b.usageHours.compareTo(a.usageHours)))
                            .map((app) {
                          return AppUsageData(
                            name: app.name,
                            usageTime:
                                double.parse(app.usageHours.toStringAsFixed(1)),
                            icon: Icons.apps, // Placeholder - not used anymore
                          );
                        }).toList(),
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
                                    iconAsset: 'assets/icons/pushup_icon.png'),
                              ]
                            : _recentWorkouts
                                .map((workout) => WorkoutData(
                                      type: workout.displayName,
                                      duration: (workout.earnedTimeSeconds / 60)
                                          .round(),
                                      iconAsset: workout.iconAsset,
                                    ))
                                .toList(),
                        delay: 300,
                        compact: isSmallScreen,
                        showIcons: true, // Show workout icons
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
  late Animation<double> _progressAnimation;

  // Using your design system tokens
  static const Color accentColor = Color(0xFF3B82F6); // Bright Blue

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 1.0, curve: Curves.fastOutSlowIn)),
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

  Widget _buildAppIcon(String appName) {
    // Try to load actual app icon image
    String? assetPath = _getAppIconAssetPath(appName);

    if (assetPath != null) {
      return Container(
        width: 20,
        height: 20,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to Material Design icon if image fails to load
            return Container(
              width: 20,
              height: 20,
              child: Icon(
                _getIconForApp(appName),
                color: accentColor,
                size: 16,
              ),
            );
          },
        ),
      );
    } else {
      // No specific icon available, use Material Design
      return Container(
        width: 20,
        height: 20,
        child: Icon(
          _getIconForApp(appName),
          color: accentColor,
          size: 16,
        ),
      );
    }
  }

  String? _getAppIconAssetPath(String appName) {
    final lowerName = appName.toLowerCase();
    print('DEBUG: _getAppIconAssetPath called for: "$appName" -> "$lowerName"');
    if (lowerName.contains('instagram')) {
      print('DEBUG: Returning instagram.png');
      return 'assets/app_icons/instagram.png';
    }
    if (lowerName.contains('youtube')) {
      print('DEBUG: Returning youtube.png');
      return 'assets/app_icons/youtube.png';
    }
    if (lowerName.contains('tiktok')) {
      print('DEBUG: Returning tiktok.png');
      return 'assets/app_icons/tiktok.png';
    }
    if (lowerName.contains('twitter') || lowerName.contains('x')) {
      print('DEBUG: Returning twitter.png');
      return 'assets/app_icons/twitter.png';
    }
    if (lowerName.contains('facebook')) {
      print('DEBUG: Returning facebook.png');
      return 'assets/app_icons/facebook.png';
    }
    if (lowerName.contains('snapchat')) {
      print('DEBUG: Returning snapchat.png');
      return 'assets/app_icons/snapchat.png';
    }
    if (lowerName.contains('whatsapp') || lowerName.contains('message')) {
      print('DEBUG: Returning whatsapp.png');
      return 'assets/app_icons/whatsapp.png';
    }
    if (lowerName.contains('reddit')) {
      print('DEBUG: Returning reddit.png');
      return 'assets/app_icons/reddit.png';
    }
    if (lowerName.contains('netflix')) {
      print('DEBUG: Returning netflix.png');
      return 'assets/app_icons/netflix.png';
    }
    if (lowerName.contains('spotify')) {
      print('DEBUG: Returning spotify.png');
      return 'assets/app_icons/spotify.png';
    }
    if (lowerName.contains('chrome')) return 'assets/app_icons/chrome.png';
    if (lowerName.contains('safari')) return 'assets/app_icons/safari.png';
    if (lowerName.contains('messenger'))
      return 'assets/app_icons/messenger.png';
    if (lowerName.contains('discord')) return 'assets/app_icons/discord.png';
    if (lowerName.contains('telegram')) return 'assets/app_icons/telegram.png';
    if (lowerName.contains('signal')) return 'assets/app_icons/signal.png';
    if (lowerName.contains('github')) return 'assets/app_icons/github.png';
    if (lowerName.contains('linkedin')) return 'assets/app_icons/linkedin.png';
    if (lowerName.contains('medium')) return 'assets/app_icons/medium.png';
    if (lowerName.contains('pinterest'))
      return 'assets/app_icons/pinterest.png';
    if (lowerName.contains('threads')) return 'assets/app_icons/threads.png';
    if (lowerName.contains('tumblr')) return 'assets/app_icons/tumblr.png';
    if (lowerName.contains('twitch')) return 'assets/app_icons/twitch.png';
    if (lowerName.contains('vk')) return 'assets/app_icons/vk.png';
    if (lowerName.contains('dribbble')) return 'assets/app_icons/dribbble.png';
    if (lowerName.contains('figma')) return 'assets/app_icons/figma.png';
    if (lowerName.contains('bluesky')) return 'assets/app_icons/bluesky.png';
    if (lowerName.contains('game')) return 'assets/app_icons/game.png';
    print('DEBUG: No match found for "$lowerName", returning null');
    return null;
  }

  IconData _getIconForApp(String appName) {
    final lowerName = appName.toLowerCase();
    print('DEBUG: _getIconForApp called for: "$appName" -> "$lowerName"');
    if (lowerName.contains('instagram')) {
      print('DEBUG: Returning camera_alt for instagram');
      return Icons.camera_alt;
    }
    if (lowerName.contains('youtube')) {
      print('DEBUG: Returning play_circle_filled for youtube');
      return Icons.play_circle_filled;
    }
    if (lowerName.contains('tiktok')) {
      print('DEBUG: Returning music_note for tiktok');
      return Icons.music_note;
    }
    if (lowerName.contains('twitter') || lowerName.contains('x')) {
      print('DEBUG: Returning tag for twitter/x');
      return Icons.tag;
    }
    if (lowerName.contains('facebook')) {
      print('DEBUG: Returning facebook for facebook');
      return Icons.facebook;
    }
    if (lowerName.contains('snapchat')) {
      print('DEBUG: Returning camera for snapchat');
      return Icons.camera;
    }
    if (lowerName.contains('whatsapp') || lowerName.contains('message')) {
      print('DEBUG: Returning message for whatsapp/message');
      return Icons.message;
    }
    if (lowerName.contains('reddit')) {
      print('DEBUG: Returning forum for reddit');
      return Icons.forum;
    }
    if (lowerName.contains('netflix')) {
      print('DEBUG: Returning tv for netflix');
      return Icons.tv;
    }
    if (lowerName.contains('spotify')) return Icons.music_note;
    if (lowerName.contains('game')) return Icons.videogame_asset;
    if (lowerName.contains('safari') || lowerName.contains('chrome'))
      return Icons.public;
    if (lowerName.contains('messenger')) return Icons.message;
    if (lowerName.contains('discord')) return Icons.chat;
    if (lowerName.contains('telegram')) return Icons.send;
    if (lowerName.contains('signal')) return Icons.security;
    if (lowerName.contains('github')) return Icons.code;
    if (lowerName.contains('linkedin')) return Icons.business;
    if (lowerName.contains('medium')) return Icons.article;
    if (lowerName.contains('pinterest')) return Icons.image;
    if (lowerName.contains('threads')) return Icons.forum;
    if (lowerName.contains('tumblr')) return Icons.web;
    if (lowerName.contains('twitch')) return Icons.tv;
    if (lowerName.contains('vk')) return Icons.group;
    if (lowerName.contains('dribbble')) return Icons.palette;
    if (lowerName.contains('figma')) return Icons.design_services;
    if (lowerName.contains('bluesky')) return Icons.cloud;
    return Icons.phone_android;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate max usage to scale progress bars relatively
    final maxUsage = widget.apps.isNotEmpty
        ? widget.apps.map((e) => e.usageTime).reduce((a, b) => a > b ? a : b)
        : 1.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        height: widget.compact ? 165 : 185,
        padding: EdgeInsets.all(widget.compact ? 14 : 16),
        decoration: _SophisticatedCardStyle.cleanCard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.05, 0.99, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: widget.apps.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final app = widget.apps[index];
                    return _buildAppRow(app, index, maxUsage);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.bar_chart_rounded,
            color: accentColor,
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
    );
  }

  Widget _buildAppRow(AppUsageData app, int index, double maxUsage) {
    final bool isTop = index == 0;
    final double relativeProgress = app.usageTime / maxUsage;

    return Column(
      children: [
        Row(
          children: [
            // Numbered ranking - fixed width container for perfect alignment
            Container(
              width: 18, // Fixed width to accommodate "3." comfortably
              alignment: Alignment.centerRight, // Right-align the number
              child: Text(
                '${index + 1}.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // App icon between number and name
            _buildAppIcon(app.name),
            const SizedBox(width: 10),
            // Name and Progress Bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${app.usageTime}h',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            TextSpan(
                              text: ' today',
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
                  const SizedBox(height: 4),
                  // Animated Progress Bar
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor:
                                relativeProgress * _progressAnimation.value,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: isTop
                                    ? [
                                        BoxShadow(
                                          color: accentColor.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
          padding: EdgeInsets.fromLTRB(
            widget.compact ? 14.0 : 16.0,
            widget.compact ? 12.0 : 14.0,
            widget.compact ? 14.0 : 16.0,
            widget.compact ? 14.0 : 16.0,
          ),
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
                child: widget.workouts.length == 1 &&
                        widget.workouts[0].type == 'No workouts yet'
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
                    : ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.05, 0.95, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: widget.workouts.length,
                          itemBuilder: (context, index) {
                            final workout = widget.workouts[index];

                            return Padding(
                              padding: EdgeInsets.only(
                                  bottom: index == widget.workouts.length - 1
                                      ? 0
                                      : 12),
                              child: Row(
                                children: [
                                  // Numbered ranking - fixed width container for perfect alignment
                                  Container(
                                    width:
                                        18, // Fixed width to accommodate numbers comfortably
                                    alignment: Alignment
                                        .centerRight, // Right-align the number
                                    child: Text(
                                      '${widget.workouts.length - index}.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Workout icon
                                  Image.asset(
                                    workout.iconAsset,
                                    color: _accentColor,
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 12),
                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            color:
                                                Colors.white.withOpacity(0.4),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
