import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/workouts_design_tokens.dart';

class WaterGoalSetupDialog extends StatefulWidget {
  const WaterGoalSetupDialog({super.key});

  @override
  State<WaterGoalSetupDialog> createState() => _WaterGoalSetupDialogState();
}

class _WaterGoalSetupDialogState extends State<WaterGoalSetupDialog> {
  double _selectedGoal = 2.0; // Default starting point

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
        _selectedGoal = currentGoal;
      });
    } catch (e) {
      debugPrint('Error loading current water goal: $e');
    }
  }

  Future<void> _saveGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('water_daily_goal', _selectedGoal);

      if (mounted) {
        Navigator.of(context).pop();
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Daily water goal set to ${_selectedGoal.toStringAsFixed(1)}L'),
            backgroundColor: WorkoutsDesignTokens.waterCyan,
            duration: const Duration(seconds: 2),
          ),
        );
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
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WorkoutsDesignTokens.waterCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: WorkoutsDesignTokens.waterCyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unlock Water',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.6),
                    size: 20,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Current goal display
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${_selectedGoal.toStringAsFixed(1)} L',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'per day',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Slider
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1.0L',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '5.0L',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: WorkoutsDesignTokens.waterCyan,
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                    thumbColor: WorkoutsDesignTokens.waterCyan,
                    overlayColor:
                        WorkoutsDesignTokens.waterCyan.withOpacity(0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: _selectedGoal,
                    min: 1.0,
                    max: 5.0,
                    divisions: 16, // 0.25L increments
                    onChanged: (value) {
                      setState(() {
                        _selectedGoal = value;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WorkoutsDesignTokens.waterCyan,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Unlock',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
