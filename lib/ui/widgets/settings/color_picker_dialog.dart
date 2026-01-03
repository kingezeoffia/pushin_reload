import 'package:flutter/material.dart';
import '../../theme/enhanced_settings_design_tokens.dart';

class ColorPickerDialog extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  const ColorPickerDialog({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;

  final List<Color> _presetColors = [
    EnhancedSettingsDesignTokens.primaryPurple,
    const Color(0xFFEC4899), // Pink
    const Color(0xFF10B981), // Mint
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEF4444), // Red
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFF97316), // Orange
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF84CC16), // Lime
    const Color(0xFFF59E0B), // Yellow
    const Color(0xFF6366F1), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EnhancedSettingsDesignTokens.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            EnhancedSettingsDesignTokens.borderRadiusLarge),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(EnhancedSettingsDesignTokens.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Choose Accent Color',
                  style: EnhancedSettingsDesignTokens.tileTitle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: EnhancedSettingsDesignTokens.spacingLarge),

            // Color Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _presetColors.length,
              itemBuilder: (context, index) {
                final color = _presetColors[index];
                final isSelected = color == _selectedColor;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = color);
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient:
                          EnhancedSettingsDesignTokens.getGradientForColor(
                              color),
                      borderRadius: BorderRadius.circular(
                          EnhancedSettingsDesignTokens.borderRadiusMedium),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.2),
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? EnhancedSettingsDesignTokens.glowShadow(color)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          )
                        : null,
                  ),
                );
              },
            ),

            const SizedBox(height: EnhancedSettingsDesignTokens.spacingLarge),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onColorSelected(_selectedColor);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          EnhancedSettingsDesignTokens.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          EnhancedSettingsDesignTokens.borderRadiusMedium,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

