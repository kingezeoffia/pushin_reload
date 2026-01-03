import 'package:flutter/material.dart';
import '../../../domain/models/workout_mode.dart';
import '../../screens/workouts/screen_time_selection_screen.dart';
import '../../animations/liquid_animation_utils.dart';

/// Enhanced QuickStartCard with smooth slide animations
/// Uses the same animation pattern as PaywallScreen price transitions
class QuickStartCard extends StatefulWidget {
  final WorkoutMode selectedMode;

  const QuickStartCard({
    super.key,
    required this.selectedMode,
  });

  @override
  State<QuickStartCard> createState() => _QuickStartCardState();
}

class _QuickStartCardState extends State<QuickStartCard>
    with TickerProviderStateMixin {
  // Gradient transition animation
  late AnimationController _gradientController;
  late Animation<double> _gradientTransition;

  // Text slide animation (like paywall price)
  late AnimationController _textSlideController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;

  // Glow pulse animation
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Initial entrance animations
  late AnimationController _entranceController;
  late Animation<double> _iconAnimation;
  late Animation<double> _textEntranceAnimation;
  late Animation<double> _buttonAnimation;

  // Press animation for button
  late AnimationController _pressController;
  late Animation<double> _pressScale;

  // Track mode for transitions
  Color? _fromColor;
  LinearGradient? _fromGradient;

  // Track displayed mode for text animation (like paywall _showYearly)
  late WorkoutMode _displayedMode;
  WorkoutMode? _previousMode;

  @override
  void initState() {
    super.initState();
    _displayedMode = widget.selectedMode;
    _initializeAnimations();
    _glowController.repeat(reverse: true);
    _entranceController.forward();
  }

  void _initializeAnimations() {
    // Gradient transition
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _gradientTransition = CurvedAnimation(
      parent: _gradientController,
      curve: Curves.easeOutCubic,
    );

    // Text slide animation (matching paywall exactly)
    _textSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textSlideController, curve: Curves.easeOutCubic),
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textSlideController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textSlideController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    // Glow pulse
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _glowAnimation = Tween<double>(
      begin: 0.25,
      end: 0.4,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOutSine,
    ));

    // Initial entrance animations
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _iconAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    );

    _textEntranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOutCubic),
    );

    _buttonAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
    );

    // Press animation
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _pressScale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(QuickStartCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedMode != widget.selectedMode) {
      _fromColor = oldWidget.selectedMode.color;
      _fromGradient = oldWidget.selectedMode.gradient;
      _previousMode = oldWidget.selectedMode;

      // Play gradient transition
      _gradientController.forward(from: 0);

      // Play text slide animation, then update displayed mode
      _textSlideController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _displayedMode = widget.selectedMode);
        }
      });
    }
  }

  @override
  void dispose() {
    _gradientController.dispose();
    _textSlideController.dispose();
    _glowController.dispose();
    _entranceController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _navigateToScreenTimeSelection(BuildContext context) {
    ModeHaptics.selectionFeedback(widget.selectedMode);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ScreenTimeSelectionScreen(selectedMode: widget.selectedMode),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const curve = Curves.easeOutCubic;
          var fadeAnimation = CurvedAnimation(parent: animation, curve: curve);
          var slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve));

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  /// Determines slide direction based on mode order
  int _getModeDirection(WorkoutMode from, WorkoutMode to) {
    final fromIndex = WorkoutMode.values.indexOf(from);
    final toIndex = WorkoutMode.values.indexOf(to);
    return toIndex > fromIndex ? 1 : -1; // 1 = slide left, -1 = slide right
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MotionPreferences.shouldReduceMotion(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _gradientTransition,
          _glowAnimation,
          _pressScale,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _pressScale.value,
            child: _buildCard(reducedMotion),
          );
        },
      ),
    );
  }

  Widget _buildCard(bool reducedMotion) {
    final currentMode = widget.selectedMode;
    final transitionProgress = _gradientTransition.value;

    // Interpolate gradient colors during transition
    final gradient = _buildTransitionGradient(transitionProgress);
    final glowColor = _fromColor != null
        ? Color.lerp(_fromColor, currentMode.color, transitionProgress)!
        : currentMode.color;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        _navigateToScreenTimeSelection(context);
      },
      onTapCancel: () => _pressController.reverse(),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            // Animated glow shadow
            if (!reducedMotion)
              BoxShadow(
                color: glowColor.withValues(alpha: _glowAnimation.value),
                blurRadius: 25 + (5 * _glowAnimation.value),
                offset: const Offset(0, 10),
              ),
            // Base shadow
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: _buildContent(reducedMotion),
      ),
    );
  }

  LinearGradient _buildTransitionGradient(double progress) {
    final currentMode = widget.selectedMode;

    if (_fromGradient == null || progress >= 1.0) {
      return currentMode.gradient;
    }

    // Interpolate between gradients
    final fromColors = _fromGradient!.colors;
    final toColors = currentMode.gradient.colors;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(fromColors[0], toColors[0], progress)!,
        Color.lerp(
          fromColors.length > 1 ? fromColors[1] : fromColors[0],
          toColors.length > 1 ? toColors[1] : toColors[0],
          progress,
        )!,
      ],
    );
  }

  Widget _buildContent(bool reducedMotion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Animated icon (entrance only)
            AnimatedBuilder(
              animation: _iconAnimation,
              builder: (context, child) {
                final scale =
                    reducedMotion ? 1.0 : 0.5 + (0.5 * _iconAnimation.value);
                final rotation =
                    reducedMotion ? 0.0 : (1 - _iconAnimation.value) * 0.2;

                return Transform.scale(
                  scale: scale,
                  child: Transform.rotate(
                    angle: rotation,
                    child: child,
                  ),
                );
              },
              child: _buildIconContainer(),
            ),
            const SizedBox(width: 16),
            // Animated text with slide transition
            Expanded(
              child: AnimatedBuilder(
                animation: _textEntranceAnimation,
                builder: (context, child) {
                  final offset = reducedMotion
                      ? Offset.zero
                      : Offset(20 * (1 - _textEntranceAnimation.value), 0);
                  final opacity =
                      reducedMotion ? 1.0 : _textEntranceAnimation.value;

                  return Transform.translate(
                    offset: offset,
                    child: Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                  );
                },
                child: _buildTextContent(reducedMotion),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Animated button (entrance only)
        AnimatedBuilder(
          animation: _buttonAnimation,
          builder: (context, child) {
            final offset = reducedMotion
                ? Offset.zero
                : Offset(0, 15 * (1 - _buttonAnimation.value));
            final opacity = reducedMotion ? 1.0 : _buttonAnimation.value;

            return Transform.translate(
              offset: offset,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            );
          },
          child: _buildButton(),
        ),
      ],
    );
  }

  Widget _buildIconContainer() {
    // Icon uses simple crossfade (works well for icons)
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Container(
        key: ValueKey(widget.selectedMode),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          widget.selectedMode.icon,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildTextContent(bool reducedMotion) {
    // Get current and target text
    final currentTitle = '${_displayedMode.displayName} Workout';
    final targetTitle = '${widget.selectedMode.displayName} Workout';
    final currentDescription = _displayedMode.description;
    final targetDescription = widget.selectedMode.description;

    // Determine slide direction
    final direction = _previousMode != null
        ? _getModeDirection(_previousMode!, widget.selectedMode)
        : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title with slide animation
        SizedBox(
          height: 28,
          child: AnimatedBuilder(
            animation: _textSlideController,
            builder: (context, child) {
              final isAnimating = _textSlideController.isAnimating;
              final slideOffset = _slideAnimation.value;

              if (reducedMotion || !isAnimating) {
                // Static text when not animating
                return _buildTitleText(currentTitle);
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Outgoing title (slides out)
                  Opacity(
                    opacity: _fadeOutAnimation.value,
                    child: Transform.translate(
                      offset: Offset(-30 * direction * slideOffset, 0),
                      child: _buildTitleText(currentTitle),
                    ),
                  ),
                  // Incoming title (slides in)
                  Opacity(
                    opacity: _fadeInAnimation.value,
                    child: Transform.translate(
                      offset: Offset(30 * direction * (1 - slideOffset), 0),
                      child: _buildTitleText(targetTitle),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        // Description with slide animation
        SizedBox(
          height: 20,
          child: AnimatedBuilder(
            animation: _textSlideController,
            builder: (context, child) {
              final isAnimating = _textSlideController.isAnimating;
              final slideOffset = _slideAnimation.value;

              if (reducedMotion || !isAnimating) {
                // Static text when not animating
                return _buildDescriptionText(currentDescription);
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Outgoing description (slides out)
                  Opacity(
                    opacity: _fadeOutAnimation.value,
                    child: Transform.translate(
                      offset: Offset(-30 * direction * slideOffset, 0),
                      child: _buildDescriptionText(currentDescription),
                    ),
                  ),
                  // Incoming description (slides in)
                  Opacity(
                    opacity: _fadeInAnimation.value,
                    child: Transform.translate(
                      offset: Offset(30 * direction * (1 - slideOffset), 0),
                      child: _buildDescriptionText(targetDescription),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTitleText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildDescriptionText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 14,
      ),
    );
  }

  Widget _buildButton() {
    // Determine slide direction for button text
    final direction = _previousMode != null
        ? _getModeDirection(_previousMode!, widget.selectedMode)
        : 1;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToScreenTimeSelection(context),
            borderRadius: BorderRadius.circular(28),
            splashColor: widget.selectedMode.color.withValues(alpha: 0.2),
            highlightColor: widget.selectedMode.color.withValues(alpha: 0.1),
            child: Center(
              child: AnimatedBuilder(
                animation: _textSlideController,
                builder: (context, child) {
                  final isAnimating = _textSlideController.isAnimating;
                  final slideOffset = _slideAnimation.value;

                  if (!isAnimating) {
                    // Static button text when not animating
                    return _buildButtonText(_displayedMode.color);
                  }

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Outgoing button text (slides out)
                      Opacity(
                        opacity: _fadeOutAnimation.value,
                        child: Transform.translate(
                          offset: Offset(-30 * direction * slideOffset, 0),
                          child: _buildButtonText(_displayedMode.color),
                        ),
                      ),
                      // Incoming button text (slides in)
                      Opacity(
                        opacity: _fadeInAnimation.value,
                        child: Transform.translate(
                          offset: Offset(30 * direction * (1 - slideOffset), 0),
                          child: _buildButtonText(widget.selectedMode.color),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonText(Color color) {
    return Text(
      "Start PUSHIN'",
      style: TextStyle(
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}
