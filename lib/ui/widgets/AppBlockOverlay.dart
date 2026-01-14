import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/pushin_theme.dart';

/// Full-screen motivational overlay shown when:
/// 1. User launches a blocked app
/// 2. User has reached daily unlock time cap
/// 3. User's unlock session has expired (after grace period)
///
/// Purpose:
/// - Motivate user to complete a workout instead of accessing blocked content
/// - UX-based blocking (not system-level enforcement)
/// - Clear call-to-action: "Start Workout" button
/// - Emergency unlock escape hatch for genuine emergencies
///
/// Design:
/// - Full-screen dark gradient background
/// - App-specific icon (80px) when blocking a specific app
/// - Headline: "Unblock [App Name]"
/// - Primary CTA: "Start Workout" (gradient pill button)
/// - Secondary CTA: "Emergency Unlock" (outlined red button)
class AppBlockOverlay extends StatefulWidget {
  /// Reason for blocking (for analytics and messaging)
  final BlockReason reason;

  /// Blocked app name (e.g., "Instagram")
  final String? blockedAppName;

  /// Blocked app icon (optional - for app-specific display)
  final IconData? blockedAppIcon;

  /// Callback when user taps "Start Workout"
  final VoidCallback onStartWorkout;

  /// Callback when user taps "Emergency Unlock"
  final VoidCallback? onEmergencyUnlock;

  /// Callback when user taps "Settings" (optional escape hatch)
  final VoidCallback? onGoToSettings;

  /// Whether emergency unlock is enabled
  final bool emergencyUnlockEnabled;

  /// Number of emergency unlocks remaining today
  final int emergencyUnlocksRemaining;

  const AppBlockOverlay({
    super.key,
    required this.reason,
    this.blockedAppName,
    this.blockedAppIcon,
    required this.onStartWorkout,
    this.onEmergencyUnlock,
    this.onGoToSettings,
    this.emergencyUnlockEnabled = true,
    this.emergencyUnlocksRemaining = 3,
  });

  @override
  State<AppBlockOverlay> createState() => _AppBlockOverlayState();
}

class _AppBlockOverlayState extends State<AppBlockOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulsing animation for lock icon
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
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

  String get _headline {
    switch (widget.reason) {
      case BlockReason.appBlocked:
        return widget.blockedAppName != null
            ? 'Unblock ${widget.blockedAppName}'
            : 'Unblock App';
      case BlockReason.dailyCapReached:
        return 'Daily limit reached!';
      case BlockReason.sessionExpired:
        return 'Unlock time expired';
      case BlockReason.workoutCompleted:
        return 'Great Work!';
      case BlockReason.preWorkout:
        return 'Time to Move!';
    }
  }

  String get _body {
    switch (widget.reason) {
      case BlockReason.appBlocked:
        return 'Complete a quick workout to access this app';
      case BlockReason.dailyCapReached:
        return "You've used your daily unlock time. Do a quick workout to earn more!";
      case BlockReason.sessionExpired:
        return 'Your unlock session has ended. Ready for another workout?';
      case BlockReason.workoutCompleted:
        return 'You earned screen time! Your apps are now unlocked.';
      case BlockReason.preWorkout:
        return 'Complete a workout to unlock your apps and earn screen time.';
    }
  }

  IconData get _icon {
    // Use lock icon for blocked states, celebration for success
    if (widget.blockedAppIcon != null) {
      return widget.blockedAppIcon!;
    }
    switch (widget.reason) {
      case BlockReason.workoutCompleted:
        return Icons.celebration_rounded;
      default:
        return Icons.lock_rounded;
    }
  }

  /// Check if this is a success/congratulatory overlay
  bool get _isSuccessOverlay => widget.reason == BlockReason.workoutCompleted;

  @override
  Widget build(BuildContext context) {
    // Use green gradient for success overlay
    final iconGradient = _isSuccessOverlay
        ? const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF34D399)],
          )
        : PushinTheme.primaryGradient;

    final iconShadowColor = _isSuccessOverlay
        ? const Color(0xFF10B981).withOpacity(0.4)
        : PushinTheme.primaryBlue.withOpacity(0.4);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0A0F),
              Color(0xFF0F0F18),
              Color(0xFF12121D),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(PushinTheme.spacingLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Animated App Icon (80px circle)
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: iconGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: iconShadowColor,
                          blurRadius: 32,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      _icon,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: PushinTheme.spacingXl),

                // Headline
                Text(
                  _headline,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: PushinTheme.spacingMd),

                // Body Text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _body,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 2),

                // For success overlay, show "Continue" button instead of "Start Workout"
                if (_isSuccessOverlay)
                  _GradientButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      widget.onStartWorkout(); // This dismisses the overlay
                    },
                    text: 'Continue',
                    icon: Icons.check_circle_outline,
                  )
                else ...[
                  // Primary CTA: Start Workout
                  _GradientButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      widget.onStartWorkout();
                    },
                    text: 'Start Workout',
                    icon: Icons.fitness_center,
                  ),

                  SizedBox(height: PushinTheme.spacingMd),

                  // Emergency Unlock Button (if enabled and callback provided)
                  if (widget.emergencyUnlockEnabled &&
                      widget.onEmergencyUnlock != null)
                    _EmergencyUnlockButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onEmergencyUnlock!();
                      },
                      unlocksRemaining: widget.emergencyUnlocksRemaining,
                    ),

                  // Secondary Action: Go to Settings (optional fallback)
                  if (widget.onGoToSettings != null &&
                      (!widget.emergencyUnlockEnabled ||
                          widget.onEmergencyUnlock == null))
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onGoToSettings!();
                      },
                      child: Text(
                        'Manage Blocked Apps',
                        style: PushinTheme.body2.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],

                const Spacer(),

                // Motivational Quote (different for success)
                Text(
                  _isSuccessOverlay
                      ? '"Every rep counts towards your goals"'
                      : '"Transform phone addiction into fitness motivation"',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.35),
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: PushinTheme.spacingLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Emergency Unlock Button - Outlined red button with warning icon
class _EmergencyUnlockButton extends StatefulWidget {
  final VoidCallback onPressed;
  final int unlocksRemaining;

  const _EmergencyUnlockButton({
    required this.onPressed,
    required this.unlocksRemaining,
  });

  @override
  State<_EmergencyUnlockButton> createState() => _EmergencyUnlockButtonState();
}

class _EmergencyUnlockButtonState extends State<_EmergencyUnlockButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final hasUnlocks = widget.unlocksRemaining > 0;
    final color = const Color(0xFFFBBF24); // Elegant amber instead of harsh red

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: _isPressed ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(PushinTheme.radiusPill),
          border: Border.all(
            color: color.withOpacity(_isPressed ? 0.5 : 0.35),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Emergency Unlock',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
            if (hasUnlocks) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.unlocksRemaining}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Gradient button widget (reusable)
class _GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final IconData? icon;

  const _GradientButton({
    required this.onPressed,
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1), // Elegant indigo
            Color(0xFF8B5CF6), // Soft violet
          ],
        ),
        borderRadius: BorderRadius.circular(PushinTheme.radiusPill),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(PushinTheme.radiusPill),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white),
                  SizedBox(width: PushinTheme.spacingSm),
                ],
                Text(
                  text,
                  style: PushinTheme.buttonText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reasons for showing block overlay
enum BlockReason {
  /// User launched a blocked app
  appBlocked,

  /// User has consumed their daily unlock cap (Free plan: 1hr)
  dailyCapReached,

  /// Unlock session expired (grace period ended)
  sessionExpired,

  /// User successfully completed a workout (congratulatory)
  workoutCompleted,

  /// Pre-workout encouragement (user in locked state)
  preWorkout,
}









