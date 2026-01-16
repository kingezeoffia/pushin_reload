import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/workouts_design_tokens.dart';
import '../widgets/GOStepsBackground.dart';
import '../widgets/PressAnimationButton.dart';

// Utility class for water amount formatting
class WaterAmountFormatter {
  static String format(double amount) {
    // Convert to string with 2 decimal places
    String formatted = amount.toStringAsFixed(2);
    // Remove trailing zeros after decimal point
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'\.?0+$'), '');
    }
    return '${formatted}L';
  }
}

/// Water Intake Setup Screen
///
/// Clean screen for setting daily water intake goal.
/// Quick presets + slider for custom selection.
class WaterIntakeSetupScreen extends StatefulWidget {
  const WaterIntakeSetupScreen({super.key});

  @override
  State<WaterIntakeSetupScreen> createState() => _WaterIntakeSetupScreenState();
}

class _WaterIntakeSetupScreenState extends State<WaterIntakeSetupScreen> {
  double _selectedLiters = 2.5;

  @override
  void initState() {
    super.initState();
    _loadCurrentGoal();
  }

  Future<void> _loadCurrentGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentGoal = prefs.getDouble('water_daily_goal') ?? 2.5;
      setState(() {
        _selectedLiters = currentGoal;
      });
    } catch (e) {
      debugPrint('Error loading current water goal: $e');
    }
  }

  String get _amountText {
    return WaterAmountFormatter.format(_selectedLiters);
  }

  Future<void> _saveAndContinue() async {
    HapticFeedback.mediumImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('water_daily_goal', _selectedLiters);

      if (mounted) {
        // Navigate back to previous screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error saving water goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save water goal. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Stack(
            children: [
              // Scrollable content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
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
                              WorkoutsDesignTokens.waterCyan,
                              WorkoutsDesignTokens.waterCyan.withOpacity(0.7),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ).createShader(
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'Water?',
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
                          'Set your daily water intake goal',
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

                  SizedBox(height: screenHeight * 0.16),

                  // Large Amount Display
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _amountText,
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
                          'per day',
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
                            activeTrackColor: WorkoutsDesignTokens.waterCyan,
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
                            value: _selectedLiters,
                            min: 1.0,
                            max: 5.0,
                            divisions: 16, // 0.25L increments
                            onChanged: (value) {
                              final snapped = (value * 4).round() / 4.0; // Snap to 0.25L intervals
                              if (snapped != _selectedLiters) {
                                HapticFeedback.selectionClick();
                              }
                              setState(() =>
                                  _selectedLiters = snapped.clamp(1.0, 5.0));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '1.0L',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '5.0L',
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

                  // Add bottom padding to prevent overlap with continue button
                  const SizedBox(height: 80),
                ],
              ),

              // Continue Button - positioned below the scrollable area within GOStepsBackground
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Continue button
                        _ContinueButton(onTap: _saveAndContinue),
                      ],
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
        height: 60,
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
            'Save Goal',
            style: TextStyle(
              fontSize: 20,
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