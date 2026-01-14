import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Emergency Unlock Dialog
///
/// Shown when user taps "Emergency Unlock" on the app block screen.
/// Displays:
/// - Warning icon
/// - App name and duration info
/// - Remaining unlocks count
/// - Confirm/Cancel buttons
class EmergencyUnlockDialog extends StatefulWidget {
  final String appName;
  final int unlockMinutes;
  final int unlocksRemaining;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const EmergencyUnlockDialog({
    super.key,
    required this.appName,
    required this.unlockMinutes,
    required this.unlocksRemaining,
    required this.onConfirm,
    required this.onCancel,
  });

  /// Show the emergency unlock dialog
  static Future<bool> show({
    required BuildContext context,
    required String appName,
    required int unlockMinutes,
    required int unlocksRemaining,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      barrierDismissible: false,
      builder: (context) => EmergencyUnlockDialog(
        appName: appName,
        unlockMinutes: unlockMinutes,
        unlocksRemaining: unlocksRemaining,
        onConfirm: () => Navigator.pop(context, true),
        onCancel: () => Navigator.pop(context, false),
      ),
    );
    return result ?? false;
  }

  @override
  State<EmergencyUnlockDialog> createState() => _EmergencyUnlockDialogState();
}

class _EmergencyUnlockDialogState extends State<EmergencyUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasUnlocks = widget.unlocksRemaining > 0;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated warning icon
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFEF4444).withOpacity(0.25),
                      const Color(0xFFDC2626).withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 36,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'Emergency Unlock',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Body text
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.65),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'This will give you direct access to '),
                  TextSpan(
                    text: widget.appName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const TextSpan(text: ' for '),
                  TextSpan(
                    text: '${widget.unlockMinutes} minutes',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const TextSpan(text: ' without completing a workout.'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Remaining unlocks indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: hasUnlocks
                    ? const Color(0xFFFFB347).withOpacity(0.12)
                    : const Color(0xFFEF4444).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasUnlocks
                      ? const Color(0xFFFFB347).withOpacity(0.25)
                      : const Color(0xFFEF4444).withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasUnlocks
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    size: 18,
                    color: hasUnlocks
                        ? const Color(0xFFFFB347)
                        : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasUnlocks
                        ? '${widget.unlocksRemaining} emergency unlock${widget.unlocksRemaining == 1 ? '' : 's'} remaining today'
                        : 'No emergency unlocks remaining',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasUnlocks
                          ? const Color(0xFFFFB347)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Buttons
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: _DialogButton(
                    label: 'Cancel',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onCancel();
                    },
                    isPrimary: false,
                  ),
                ),
                const SizedBox(width: 12),
                // Unlock button
                Expanded(
                  child: _DialogButton(
                    label: 'Unlock Now',
                    icon: Icons.flash_on_rounded,
                    onTap: hasUnlocks
                        ? () {
                            HapticFeedback.mediumImpact();
                            widget.onConfirm();
                          }
                        : null,
                    isPrimary: true,
                    primaryColor: const Color(0xFFEF4444),
                    disabled: !hasUnlocks,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Footer text
            Text(
              'Emergency unlocks reset daily at midnight',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.35),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog Button Widget
class _DialogButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  final Color? primaryColor;
  final bool disabled;

  const _DialogButton({
    required this.label,
    this.icon,
    required this.onTap,
    required this.isPrimary,
    this.primaryColor,
    this.disabled = false,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor ?? Colors.white;
    final isDisabled = widget.disabled || widget.onTap == null;
    final opacity = isDisabled ? 0.4 : 1.0;

    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
        onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
        onTapCancel:
            isDisabled ? null : () => setState(() => _isPressed = false),
        onTap: isDisabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: widget.isPrimary && !isDisabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(_isPressed ? 0.85 : 1.0),
                      color.withOpacity(_isPressed ? 0.7 : 0.85),
                    ],
                  )
                : null,
            color: widget.isPrimary
                ? null
                : Colors.white.withOpacity(_isPressed ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.isPrimary && !isDisabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 18,
                    color: widget.isPrimary
                        ? Colors.white
                        : Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.isPrimary
                        ? Colors.white
                        : Colors.white.withOpacity(0.8),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
