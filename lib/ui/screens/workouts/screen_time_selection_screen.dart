import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/models/workout_mode.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'workout_type_selection_screen.dart';

/// Screen Time Selection Screen
///
/// Clean screen matching the onboarding "Set your unlock duration" style.
/// Quick presets + slider for custom selection.
class ScreenTimeSelectionScreen extends StatefulWidget {
  final WorkoutMode selectedMode;

  const ScreenTimeSelectionScreen({
    super.key,
    required this.selectedMode,
  });

  @override
  State<ScreenTimeSelectionScreen> createState() =>
      _ScreenTimeSelectionScreenState();
}

class _ScreenTimeSelectionScreenState extends State<ScreenTimeSelectionScreen> {
  double _selectedMinutes = 15.0;

  // Quick preset options
  final List<int> _presets = [15, 30, 45, 60];

  String get _durationText {
    final minutes = _selectedMinutes.round();
    if (minutes == 60) {
      return '1 hr';
    }
    return '$minutes min';
  }

  /// Calculate required reps based on desired screen time and mode multiplier
  int _calculateRequiredReps(int desiredMinutes) {
    // Cozy (0.7x) = fewer reps needed = easier
    // Normal (1.0x) = standard
    // Tuff (1.5x) = more reps needed = harder
    return (desiredMinutes * widget.selectedMode.multiplier).ceil();
  }

  void _continue() {
    HapticFeedback.mediumImpact();
    final minutes = _selectedMinutes.round();
    final requiredReps = _calculateRequiredReps(minutes);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WorkoutTypeSelectionScreen(
          selectedMode: widget.selectedMode,
          desiredScreenTime: minutes,
          requiredReps: requiredReps,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = Curves.easeOutCubic;
          var fadeAnimation = CurvedAnimation(parent: animation, curve: curve);
          return FadeTransition(opacity: fadeAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + Mode indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    _ModeIndicator(mode: widget.selectedMode),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Heading
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How much',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          widget.selectedMode.color,
                          widget.selectedMode.color.withOpacity(0.7),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'Screen Time?',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how long you want your apps unlocked',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: -0.2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.12),

              // Large Duration Display
              Center(
                child: Column(
                  children: [
                    Text(
                      _durationText,
                      style: const TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -2,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'of screen time',
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white.withOpacity(0.5),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Slider for custom selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 8,
                        activeTrackColor: widget.selectedMode.color,
                        inactiveTrackColor: Colors.white.withOpacity(0.15),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 14,
                          elevation: 4,
                        ),
                        overlayColor: Colors.white.withOpacity(0.1),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 28,
                        ),
                      ),
                      child: Slider(
                        value: _selectedMinutes,
                        min: 5,
                        max: 60,
                        divisions: 11, // 5-minute intervals
                        onChanged: (value) {
                          final snapped = (value / 5).round() * 5.0;
                          if (snapped != _selectedMinutes) {
                            HapticFeedback.selectionClick();
                          }
                          setState(
                              () => _selectedMinutes = snapped.clamp(5, 60));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '5 min',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '1 hr',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Time buttons + Continue button
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    // Quick Presets (moved from above)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: _presets.map((minutes) {
                        final isSelected = _selectedMinutes.round() == minutes;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(
                                () => _selectedMinutes = minutes.toDouble());
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.selectedMode.color
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isSelected
                                    ? widget.selectedMode.color
                                    : Colors.white.withOpacity(0.15),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              minutes == 60 ? '1 hr' : '$minutes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Continue button
                    _ContinueButton(onTap: _continue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mode indicator pill
class _ModeIndicator extends StatelessWidget {
  final WorkoutMode mode;

  const _ModeIndicator({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, color: mode.color, size: 16),
          const SizedBox(width: 8),
          Text(
            mode.displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: mode.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Continue Button Widget
class _ContinueButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContinueButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
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
    );
  }
}
