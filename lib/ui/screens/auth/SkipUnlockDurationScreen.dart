import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'SkipEmergencyUnlockScreen.dart';

/// Skip Flow: Unlock Duration Screen
///
/// Context-free version for users who skip onboarding
/// Simplified unlock duration selection
class SkipUnlockDurationScreen extends StatefulWidget {
  final List<String> blockedApps;
  final String selectedWorkout;

  const SkipUnlockDurationScreen({
    super.key,
    required this.blockedApps,
    required this.selectedWorkout,
  });

  @override
  State<SkipUnlockDurationScreen> createState() =>
      _SkipUnlockDurationScreenState();
}

class _SkipUnlockDurationScreenState extends State<SkipUnlockDurationScreen> {
  double _unlockDuration = 5.0; // Start at minimum (5 minutes)

  String get _durationText {
    final minutes = _unlockDuration.round();
    if (minutes == 60) {
      return '1 hr';
    }
    return '$minutes min';
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
              // Back Button (no step indicator for skip flow)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16, top: 8),
                child: _BackButton(onTap: () => Navigator.pop(context)),
              ),

              SizedBox(height: screenHeight * 0.08),

              // Heading - consistent with other screens
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set your',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: const Text(
                        'Unlock Duration',
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
                      'How long should your apps be unlocked after a workout?',
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

              SizedBox(height: screenHeight * 0.06),

              // Duration Display
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

              SizedBox(height: screenHeight * 0.06),

              // Custom Slider - Max 1 hour
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // Slider
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 8,
                        activeTrackColor: const Color(0xFF6060FF),
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
                        value: _unlockDuration,
                        min: 5,
                        max: 60, // Max 1 hour
                        divisions:
                            11, // 5-minute intervals (5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60)
                        onChanged: (value) {
                          // Snap to nearest 5 minutes
                          final snapped = (value / 5).round() * 5.0;
                          if (snapped != _unlockDuration) {
                            HapticFeedback.selectionClick();
                          }
                          setState(
                              () => _unlockDuration = snapped.clamp(5, 60));
                        },
                      ),
                    ),
                    // Labels
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

              // Continue Button
              Padding(
                padding: const EdgeInsets.all(32),
                child: _ContinueButton(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SkipEmergencyUnlockScreen(
                          blockedApps: widget.blockedApps,
                          selectedWorkout: widget.selectedWorkout,
                          unlockDuration: _unlockDuration.round(),
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
  final VoidCallback onTap;

  const _ContinueButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
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





