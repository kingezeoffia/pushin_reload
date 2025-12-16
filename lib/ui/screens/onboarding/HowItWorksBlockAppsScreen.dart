import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../theme/pushin_theme.dart';
import 'HowItWorksExerciseScreen.dart';

/// Step 1: Block Distracting Apps
///
/// BMAD V6 Spec:
/// - Display actual app icons with checkboxes
/// - Include search/filter bar at the top
/// - Show list of common distracting apps
class HowItWorksBlockAppsScreen extends StatefulWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;
  final String workoutHistory;

  const HowItWorksBlockAppsScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
    required this.workoutHistory,
  });

  @override
  State<HowItWorksBlockAppsScreen> createState() =>
      _HowItWorksBlockAppsScreenState();
}

class _HowItWorksBlockAppsScreenState extends State<HowItWorksBlockAppsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedApps = {};
  String _searchQuery = '';

  // Mock list of common distracting apps
  final List<_AppInfo> _allApps = [
    _AppInfo('Instagram', Icons.camera_alt, const Color(0xFFE4405F)),
    _AppInfo('TikTok', Icons.music_note, const Color(0xFF000000)),
    _AppInfo('Twitter/X', Icons.alternate_email, const Color(0xFF1DA1F2)),
    _AppInfo('YouTube', Icons.play_circle_filled, const Color(0xFFFF0000)),
    _AppInfo('Facebook', Icons.facebook, const Color(0xFF1877F2)),
    _AppInfo('Snapchat', Icons.photo_camera, const Color(0xFFFFFC00)),
    _AppInfo('Reddit', Icons.forum, const Color(0xFFFF4500)),
    _AppInfo('Netflix', Icons.tv, const Color(0xFFE50914)),
    _AppInfo('Discord', Icons.headset_mic, const Color(0xFF5865F2)),
    _AppInfo('Twitch', Icons.videogame_asset, const Color(0xFF9146FF)),
    _AppInfo('Pinterest', Icons.push_pin, const Color(0xFFE60023)),
    _AppInfo('Spotify', Icons.audiotrack, const Color(0xFF1DB954)),
  ];

  List<_AppInfo> get _filteredApps {
    if (_searchQuery.isEmpty) return _allApps;
    return _allApps
        .where((app) =>
            app.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button & Step Indicator
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16, top: 8),
                child: Row(
                  children: [
                    _BackButton(onTap: () => Navigator.pop(context)),
                    const Spacer(),
                    _StepIndicator(currentStep: 1, totalSteps: 6),
                  ],
                ),
              ),

              // Consistent spacing with other screens
              SizedBox(height: MediaQuery.of(context).size.height * 0.04),

              // Heading - consistent positioning
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Block',
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
                      child: Text(
                        'Distracting Apps',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                          decoration: TextDecoration.none,
                          fontFamily: 'Inter', // Explicit font family
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select apps to block until you exercise',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _SearchBar(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              const SizedBox(height: 20),

              // Apps List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  itemCount: _filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = _filteredApps[index];
                    final isSelected = _selectedApps.contains(app.name);
                    return _AppListItem(
                      app: app,
                      isSelected: isSelected,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          if (isSelected) {
                            _selectedApps.remove(app.name);
                          } else {
                            _selectedApps.add(app.name);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

              // Continue Button
              Padding(
                padding: const EdgeInsets.all(32),
                child: _ContinueButton(
                  enabled: _selectedApps.isNotEmpty,
                  selectedCount: _selectedApps.length,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HowItWorksExerciseScreen(
                          fitnessLevel: widget.fitnessLevel,
                          goals: widget.goals,
                          otherGoal: widget.otherGoal,
                          workoutHistory: widget.workoutHistory,
                          blockedApps: _selectedApps.toList(),
                        ),
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

/// App info model
class _AppInfo {
  final String name;
  final IconData icon;
  final Color color;

  const _AppInfo(this.name, this.icon, this.color);
}

/// Search bar widget - flat modern design
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(100),
        // NO border - flat modern design
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Search apps...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// App list item with checkbox - flat modern design
class _AppListItem extends StatelessWidget {
  final _AppInfo app;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppListItem({
    required this.app,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          // NO border - flat modern design
        ),
        child: Row(
          children: [
            // App Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: app.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                app.icon,
                color: app.color == const Color(0xFFFFFC00) ||
                        app.color == const Color(0xFF000000)
                    ? (app.color == const Color(0xFF000000)
                        ? Colors.white
                        : Colors.black)
                    : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // App Name
            Expanded(
              child: Text(
                app.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            // Checkbox - flat design
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6060FF)
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                // NO border
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Step indicator widget
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'Step $currentStep of $totalSteps',
        style: PushinTheme.stepIndicatorText.copyWith(
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }
}

/// Back Button Widget
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

/// Continue Button Widget
class _ContinueButton extends StatelessWidget {
  final bool enabled;
  final int selectedCount;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.enabled,
    required this.selectedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.95)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(100),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? const Color(0xFF2A2A6A)
                  : Colors.white.withOpacity(0.4),
              letterSpacing: -0.3,
            ),
            child: Text(
              enabled
                  ? 'Continue ($selectedCount selected)'
                  : 'Select apps to continue',
            ),
          ),
        ),
      ),
    );
  }
}
