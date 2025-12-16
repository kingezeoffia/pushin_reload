import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Selection Button with flat modern design (no outlines)
///
/// BMAD V6 Spec - Button States:
/// - Default (unpressed): White text, semi-transparent background, NO border
/// - Press down (tap active): Slightly dimmed background for feedback
/// - Selected state: Solid white background, purple/lavender text
class SelectionButton extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double? width;
  final double height;
  final bool provideHapticFeedback;

  const SelectionButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.width,
    this.height = 56,
    this.provideHapticFeedback = true,
  });

  @override
  State<SelectionButton> createState() => _SelectionButtonState();
}

class _SelectionButtonState extends State<SelectionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Colors based on state - NO BORDERS (flat modern look)
    final Color backgroundColor;
    final Color textColor;

    if (widget.isSelected) {
      // Selected state: solid white background, purple text
      backgroundColor = Colors.white;
      textColor = const Color(0xFF3535A0); // Purple/lavender
    } else if (_isPressed) {
      // Press state: dimmed/less visible background
      backgroundColor = Colors.white.withOpacity(0.06);
      textColor = Colors.white.withOpacity(0.7);
    } else {
      // Default state: semi-transparent background, white text
      backgroundColor = Colors.white.withOpacity(0.10);
      textColor = Colors.white;
    }

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        if (widget.provideHapticFeedback) {
          HapticFeedback.lightImpact();
        }
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          // NO border - flat modern design
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid-style selection button (for 2x2 layouts) - flat modern design
class SelectionButtonGrid extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isLocked;
  final String? lockedLabel;

  const SelectionButtonGrid({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.isLocked = false,
    this.lockedLabel,
  });

  @override
  State<SelectionButtonGrid> createState() => _SelectionButtonGridState();
}

class _SelectionButtonGridState extends State<SelectionButtonGrid> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final Color textColor;

    if (widget.isLocked) {
      // Locked state: grayed out
      backgroundColor = Colors.white.withOpacity(0.05);
      textColor = Colors.white.withOpacity(0.3);
    } else if (widget.isSelected) {
      // Selected state
      backgroundColor = Colors.white;
      textColor = const Color(0xFF3535A0);
    } else if (_isPressed) {
      // Press state
      backgroundColor = Colors.white.withOpacity(0.06);
      textColor = Colors.white.withOpacity(0.7);
    } else {
      // Default state
      backgroundColor = Colors.white.withOpacity(0.12);
      textColor = Colors.white;
    }

    return GestureDetector(
      onTapDown: widget.isLocked
          ? null
          : (_) {
              setState(() => _isPressed = true);
            },
      onTapUp: widget.isLocked
          ? null
          : (_) {
              setState(() => _isPressed = false);
              HapticFeedback.lightImpact();
              widget.onTap();
            },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          // NO border - flat modern design
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 32,
                color: textColor,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.isLocked && widget.lockedLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock,
                    size: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.lockedLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
