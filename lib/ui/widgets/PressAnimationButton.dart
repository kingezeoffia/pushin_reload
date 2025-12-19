import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable button widget with press animation feedback
/// Maintains all existing button behavior while adding consistent press animations
class PressAnimationButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration animationDuration;
  final double pressedScale;
  final Alignment transformAlignment;

  const PressAnimationButton({
    super.key,
    required this.child,
    this.onTap,
    this.animationDuration = const Duration(milliseconds: 150),
    this.pressedScale = 0.98,
    this.transformAlignment = Alignment.center,
  });

  @override
  State<PressAnimationButton> createState() => _PressAnimationButtonState();
}

class _PressAnimationButtonState extends State<PressAnimationButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _isPressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _isPressed = false)
          : null,
      onTap: widget.onTap != null
          ? () {
              HapticFeedback.mediumImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: widget.animationDuration,
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..scale(_isPressed ? widget.pressedScale : 1.0),
        transformAlignment: widget.transformAlignment,
        child: widget.child,
      ),
    );
  }
}











