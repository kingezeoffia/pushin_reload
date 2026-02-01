import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/PressAnimationButton.dart';
import '../theme/workouts_design_tokens.dart';

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

class EditWaterIntakePopup extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(double) onGoalChanged;

  const EditWaterIntakePopup({
    super.key,
    required this.onCancel,
    required this.onGoalChanged,
  });

  @override
  State<EditWaterIntakePopup> createState() => _EditWaterIntakePopupState();
}

class _EditWaterIntakePopupState extends State<EditWaterIntakePopup> {
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

  Future<void> _saveGoal() async {
    HapticFeedback.mediumImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('water_daily_goal', _selectedLiters);

      // Notify parent widget of the change
      widget.onGoalChanged(_selectedLiters);

      if (mounted) {
        Navigator.of(context).pop(); // Close popup after saving
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
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: const Color(0x99000000), // Same glass color as positioning overlay
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 32), // Increased to make room for close button
                          // Water Drop Icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: WorkoutsDesignTokens.waterCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.water_drop,
                          color: WorkoutsDesignTokens.waterCyan,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 16),
                  // Title with improved typography
                  Text(
                    'Edit Water Goal',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2), // Reduced from 6 to 2
                  // Subtitle with improved styling
                  Text(
                    'Set your daily water intake target',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.4,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Large Amount Display
                  Column(
                    children: [
                      Text(
                        _amountText,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'per day',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Slider for custom selection
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 6,
                            activeTrackColor: WorkoutsDesignTokens.waterCyan,
                            inactiveTrackColor: Colors.white.withOpacity(0.15),
                            thumbColor: Colors.white,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                              elevation: 4,
                            ),
                            overlayColor: Colors.white.withOpacity(0.1),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 24,
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
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '5.0L',
                                style: TextStyle(
                                  fontSize: 12,
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
                  const SizedBox(height: 32),
                  // Save Goal Button
                  PressAnimationButton(
                    onTap: _saveGoal,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Save Goal',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2A2A6A),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Close button in top right
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: widget.onCancel,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
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