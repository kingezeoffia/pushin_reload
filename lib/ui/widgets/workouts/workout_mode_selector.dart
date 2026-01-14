import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../animations/liquid_animation_utils.dart';
import '../../theme/pushin_theme.dart';
import '../../../domain/models/workout_mode.dart';

/// Premium workout mode selector with liquid motion animations
/// Features: morphing transitions, staggered animations, crossfade content,
/// glow effects, and mode-specific animation characteristics
class WorkoutModeSelector extends StatefulWidget {
  final WorkoutMode selectedMode;
  final ValueChanged<WorkoutMode> onModeChanged;

  const WorkoutModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  State<WorkoutModeSelector> createState() => _WorkoutModeSelectorState();
}

class _WorkoutModeSelectorState extends State<WorkoutModeSelector>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        children: WorkoutMode.values.asMap().entries.map((entry) {
          final index = entry.key;
          final mode = entry.value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: LiquidModeCard(
                mode: mode,
                isSelected: widget.selectedMode == mode,
                onTap: () {
                  if (widget.selectedMode != mode) {
                    ModeHaptics.selectionFeedback(mode);
                    widget.onModeChanged(mode);
                  }
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Individual mode card with liquid morphing animations
class LiquidModeCard extends StatefulWidget {
  final WorkoutMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const LiquidModeCard({
    super.key,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<LiquidModeCard> createState() => _LiquidModeCardState();
}

class _LiquidModeCardState extends State<LiquidModeCard>
    with TickerProviderStateMixin {
  // Main selection animation controller
  late AnimationController _selectionController;
  late Animation<double> _selectionAnimation;

  // Press/tap animation controller
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  // Glow pulse animation
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Staggered content animations
  late AnimationController _staggerController;
  late Animation<double> _iconAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _subtitleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    if (widget.isSelected) {
      _selectionController.value = 1.0;
      _staggerController.value = 1.0; // Set text to final position immediately
      _glowController.repeat(reverse: true);
    }
  }

  void _initializeAnimations() {
    final duration = _getModeDuration();
    final curve = _getModeCurve();

    // Selection animation
    _selectionController = AnimationController(
      vsync: this,
      duration: duration,
    );

    _selectionAnimation = CurvedAnimation(
      parent: _selectionController,
      curve: curve,
      reverseCurve: Curves.easeInCubic,
    );

    // Press animation
    _pressController = AnimationController(
      vsync: this,
      duration: ModeDurations.tapFeedback,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutCubic,
    ));

    // Glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: _getGlowDuration(),
    );

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: _getGlowCurve(),
    ));

    // Staggered content animations
    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: duration.inMilliseconds + 150),
    );

    _iconAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    );

    _titleAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.15, 0.75, curve: Curves.easeOutCubic),
    );

    _subtitleAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
    );
  }

  Duration _getModeDuration() {
    switch (widget.mode) {
      case WorkoutMode.cozy:
        return ModeDurations.cozyMain;
      case WorkoutMode.normal:
        return ModeDurations.normalMain;
      case WorkoutMode.tuff:
        return ModeDurations.tuffMain;
    }
  }

  Duration _getGlowDuration() {
    switch (widget.mode) {
      case WorkoutMode.cozy:
        return ModeDurations.cozyGlow;
      case WorkoutMode.normal:
        return ModeDurations.normalGlow;
      case WorkoutMode.tuff:
        return ModeDurations.tuffGlow;
    }
  }

  Curve _getModeCurve() {
    switch (widget.mode) {
      case WorkoutMode.cozy:
        return ModeCurves.cozyEnter;
      case WorkoutMode.normal:
        return ModeCurves.normalEnter;
      case WorkoutMode.tuff:
        return ModeCurves.tuffEnter;
    }
  }

  Curve _getGlowCurve() {
    switch (widget.mode) {
      case WorkoutMode.cozy:
        return ModeCurves.cozyGlow;
      case WorkoutMode.normal:
        return ModeCurves.normalGlow;
      case WorkoutMode.tuff:
        return ModeCurves.tuffGlow;
    }
  }

  @override
  void didUpdateWidget(LiquidModeCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _selectionController.forward();
        _staggerController.forward(from: 0);
        _glowController.repeat(reverse: true);
      } else {
        _selectionController.reverse();
        _staggerController.reverse();
        _glowController.stop();
        _glowController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _pressController.dispose();
    _glowController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
    HapticFeedback.selectionClick();
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MotionPreferences.shouldReduceMotion(context);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _selectionAnimation,
            _scaleAnimation,
            _glowAnimation,
          ]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: _buildCard(reducedMotion),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(bool reducedMotion) {
    return AnimatedBuilder(
      animation: _selectionAnimation,
      builder: (context, child) {
        final progress = _selectionAnimation.value;
        final mode = widget.mode;

        return Container(
          width: double.infinity,
          height: 140,
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      mode.gradient.colors[0],
                      mode.gradient.colors[1],
                    ],
                  )
                : null,
            color: widget.isSelected ? null : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: widget.isSelected ? null : Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: widget.isSelected ? PushinTheme.cardShadow : null,
          ),
          child: _buildContent(progress, reducedMotion),
        );
      },
    );
  }

  Widget _buildContent(double progress, bool reducedMotion) {
    return Stack(
      children: [
        // Main content with staggered animations
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with staggered animation
              _buildAnimatedIcon(progress, reducedMotion),
              const SizedBox(height: 12),

              // Title with staggered animation
              _buildAnimatedTitle(progress, reducedMotion),
              const SizedBox(height: 4),

              // Subtitle with staggered animation
              _buildAnimatedSubtitle(progress, reducedMotion),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedIcon(double progress, bool reducedMotion) {
    return AnimatedBuilder(
      animation: Listenable.merge([_iconAnimation, _scaleAnimation]),
      builder: (context, child) {
        // Only apply stagger animation to selected cards
        final iconScale = (reducedMotion || !widget.isSelected)
            ? 1.0
            : 0.8 + (0.2 * _iconAnimation.value);

        // Make icon bigger when pressed (inverse of card scale)
        final pressScale = 1.0 + ((1.0 - _scaleAnimation.value) / 0.05) * 0.1;

        return Transform.scale(
          scale: iconScale * pressScale,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? Colors.white.withValues(alpha: 0.2 * progress)
                  : widget.mode.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: ModeDurations.crossfade,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                widget.mode.icon,
                key: ValueKey('${widget.mode}_${widget.isSelected}'),
                color: widget.isSelected ? Colors.white : widget.mode.color,
                size: 28,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedTitle(double progress, bool reducedMotion) {
    return AnimatedBuilder(
      animation: _titleAnimation,
      builder: (context, child) {
        // Only apply stagger animation to selected cards
        final offset = (reducedMotion || !widget.isSelected)
            ? Offset.zero
            : Offset(0, 8 * (1 - _titleAnimation.value));

        return Transform.translate(
          offset: offset,
          child: AnimatedDefaultTextStyle(
            duration: ModeDurations.crossfade,
            style: TextStyle(
              color: widget.isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: widget.isSelected ? 0.5 : 0,
            ),
            child: Text(widget.mode.displayName),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSubtitle(double progress, bool reducedMotion) {
    return AnimatedBuilder(
      animation: _subtitleAnimation,
      builder: (context, child) {
        // Only apply stagger animation to selected cards
        final offset = (reducedMotion || !widget.isSelected)
            ? Offset.zero
            : Offset(0, 6 * (1 - _subtitleAnimation.value));

        return Transform.translate(
          offset: offset,
          child: AnimatedDefaultTextStyle(
            duration: ModeDurations.crossfade,
            style: TextStyle(
              color: widget.isSelected
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
            child: Text(
              widget.mode.description,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
