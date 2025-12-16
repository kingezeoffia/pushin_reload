import 'package:flutter/material.dart';
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
/// - Cannot be dismissed without taking action (tap outside disabled)
///
/// Design:
/// - Full-screen dark overlay (85% opacity)
/// - GO Club-inspired gradient card with lock icon
/// - Animated pulsing effect on lock icon
/// - Single primary CTA button
class AppBlockOverlay extends StatefulWidget {
  /// Reason for blocking (for analytics and messaging)
  final BlockReason reason;
  
  /// Blocked app name (e.g., "Instagram")
  final String? blockedAppName;
  
  /// Callback when user taps "Start Workout"
  final VoidCallback onStartWorkout;
  
  /// Callback when user taps "Settings" (optional escape hatch)
  final VoidCallback? onGoToSettings;

  const AppBlockOverlay({
    super.key,
    required this.reason,
    this.blockedAppName,
    required this.onStartWorkout,
    this.onGoToSettings,
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
            ? '${widget.blockedAppName} is blocked'
            : 'This app is blocked';
      case BlockReason.dailyCapReached:
        return 'Daily limit reached!';
      case BlockReason.sessionExpired:
        return 'Unlock time expired';
    }
  }

  String get _body {
    switch (widget.reason) {
      case BlockReason.appBlocked:
        return 'Complete a workout to unlock access. Transform screen time into fitness gains!';
      case BlockReason.dailyCapReached:
        return "You've used your daily unlock time. Do a quick workout to earn more!";
      case BlockReason.sessionExpired:
        return 'Your unlock session has ended. Ready for another workout?';
    }
  }

  IconData get _icon {
    switch (widget.reason) {
      case BlockReason.appBlocked:
        return Icons.lock_outline;
      case BlockReason.dailyCapReached:
        return Icons.timelapse_rounded;
      case BlockReason.sessionExpired:
        return Icons.timer_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PushinTheme.backgroundDark.withOpacity(0.95),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(PushinTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Lock Icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: PushinTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: PushinTheme.primaryBlue.withOpacity(0.4),
                        blurRadius: 32,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    _icon,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
              
              SizedBox(height: PushinTheme.spacingXl),
              
              // Headline
              Text(
                _headline,
                style: PushinTheme.headline2.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: PushinTheme.spacingMd),
              
              // Body Text
              Text(
                _body,
                style: PushinTheme.body1.copyWith(
                  color: PushinTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: PushinTheme.spacingXxl),
              
              // Primary CTA: Start Workout
              _GradientButton(
                onPressed: widget.onStartWorkout,
                text: 'Start Workout',
                icon: Icons.fitness_center,
              ),
              
              SizedBox(height: PushinTheme.spacingMd),
              
              // Secondary Action: Go to Settings (optional)
              if (widget.onGoToSettings != null)
                TextButton(
                  onPressed: widget.onGoToSettings,
                  child: Text(
                    'Manage Blocked Apps',
                    style: PushinTheme.body2.copyWith(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              
              const Spacer(),
              
              // Motivational Quote (optional branding)
              Text(
                '"Transform phone addiction into fitness motivation"',
                style: PushinTheme.caption.copyWith(
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
        gradient: PushinTheme.primaryGradient,
        borderRadius: BorderRadius.circular(PushinTheme.radiusPill),
        boxShadow: PushinTheme.buttonShadow,
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
}









