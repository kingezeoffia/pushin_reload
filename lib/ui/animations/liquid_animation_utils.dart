import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium animation utilities for liquid-like motion effects
/// Optimized for 60fps performance with accessibility support

// ============================================================================
// CUSTOM ANIMATION CURVES
// ============================================================================

/// Liquid-like curve that starts fast and decelerates smoothly
/// Creates a natural, physics-based motion feel
class LiquidCurve extends Curve {
  final double tension;

  const LiquidCurve({this.tension = 0.4});

  @override
  double transformInternal(double t) {
    // Custom bezier-like curve for liquid motion
    // Uses exponential decay combined with slight overshoot
    final double decay = 1.0 - math.pow(1.0 - t, 3);
    final double overshoot = math.sin(t * math.pi) * 0.05 * (1 - tension);
    return (decay + overshoot).clamp(0.0, 1.0);
  }
}

/// Bounce curve with configurable intensity
class ResponsiveBounce extends Curve {
  final double bounciness;
  final int bounces;

  const ResponsiveBounce({
    this.bounciness = 0.3,
    this.bounces = 2,
  });

  @override
  double transformInternal(double t) {
    if (t == 1.0) return 1.0;

    // Exponential decay envelope
    final double envelope = 1.0 - math.pow(1.0 - t, 2.5).toDouble();

    // Damped oscillation
    final double frequency = bounces * math.pi;
    final double damping = math.pow(1.0 - t, 2).toDouble();
    final double oscillation = math.sin(t * frequency) * bounciness * damping;

    return (envelope + oscillation).clamp(0.0, 1.0);
  }
}

/// Elastic curve for snappy, energetic animations
class ElasticOut extends Curve {
  final double amplitude;
  final double period;

  const ElasticOut({
    this.amplitude = 1.0,
    this.period = 0.4,
  });

  @override
  double transformInternal(double t) {
    if (t == 0 || t == 1) return t;

    final double s = period / (2 * math.pi) * math.asin(1 / amplitude);
    return amplitude *
           math.pow(2, -10 * t).toDouble() *
           math.sin((t - s) * (2 * math.pi) / period) + 1;
  }
}

/// Smooth deceleration curve (ease-out quad)
class SmoothDecelerate extends Curve {
  final double intensity;

  const SmoothDecelerate({this.intensity = 2.0});

  @override
  double transformInternal(double t) {
    return 1.0 - math.pow(1.0 - t, intensity);
  }
}

// ============================================================================
// PRESET CURVES FOR DIFFERENT MODES
// ============================================================================

class ModeCurves {
  /// Cozy mode: Gentle, slow, relaxing animations
  static const Curve cozyEnter = Curves.easeOutQuart;
  static const Curve cozyExit = Curves.easeInQuad;
  static const Curve cozyScale = Curves.easeOutBack;
  static const Curve cozyGlow = Curves.easeInOutSine;

  /// Normal mode: Balanced, natural motion
  static const Curve normalEnter = Curves.easeOutCubic;
  static const Curve normalExit = Curves.easeInCubic;
  static const Curve normalScale = Curves.easeOutBack;
  static const Curve normalGlow = Curves.easeInOutQuad;

  /// Tuff mode: Dynamic, energetic, bouncy
  static const Curve tuffEnter = ElasticOut(amplitude: 1.0, period: 0.5);
  static const Curve tuffExit = Curves.easeInBack;
  static const Curve tuffScale = ResponsiveBounce(bounciness: 0.15);
  static const Curve tuffGlow = Curves.easeInOutQuart;

  /// Liquid morphing curve for container transitions
  static const Curve liquidMorph = LiquidCurve(tension: 0.3);

  /// Quick snap for immediate feedback
  static const Curve quickSnap = Curves.easeOutExpo;
}

// ============================================================================
// ANIMATION DURATIONS
// ============================================================================

class ModeDurations {
  /// Cozy mode: Slower, more relaxed
  static const Duration cozyMain = Duration(milliseconds: 500);
  static const Duration cozyStagger = Duration(milliseconds: 80);
  static const Duration cozyGlow = Duration(milliseconds: 1500);

  /// Normal mode: Balanced timing
  static const Duration normalMain = Duration(milliseconds: 380);
  static const Duration normalStagger = Duration(milliseconds: 60);
  static const Duration normalGlow = Duration(milliseconds: 1200);

  /// Tuff mode: Faster, more energetic
  static const Duration tuffMain = Duration(milliseconds: 280);
  static const Duration tuffStagger = Duration(milliseconds: 40);
  static const Duration tuffGlow = Duration(milliseconds: 800);

  /// Common durations
  static const Duration tapFeedback = Duration(milliseconds: 120);
  static const Duration crossfade = Duration(milliseconds: 250);
  static const Duration morphTransition = Duration(milliseconds: 350);
  static const Duration liquidFlow = Duration(milliseconds: 400);
}

// ============================================================================
// STAGGERED ANIMATION HELPER
// ============================================================================

class StaggeredAnimationController {
  final TickerProvider vsync;
  final Duration totalDuration;
  final Duration staggerDelay;
  final int itemCount;
  final Curve curve;

  late AnimationController _controller;
  late List<Animation<double>> _animations;

  StaggeredAnimationController({
    required this.vsync,
    required this.totalDuration,
    required this.staggerDelay,
    required this.itemCount,
    this.curve = Curves.easeOutCubic,
  }) {
    final totalMs = totalDuration.inMilliseconds +
                    (staggerDelay.inMilliseconds * (itemCount - 1));

    _controller = AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: totalMs),
    );

    _animations = List.generate(itemCount, (index) {
      final startPercent = (staggerDelay.inMilliseconds * index) / totalMs;
      final endPercent = startPercent + (totalDuration.inMilliseconds / totalMs);

      return CurvedAnimation(
        parent: _controller,
        curve: Interval(
          startPercent.clamp(0.0, 1.0),
          endPercent.clamp(0.0, 1.0),
          curve: curve,
        ),
      );
    });
  }

  Animation<double> operator [](int index) => _animations[index];

  AnimationController get controller => _controller;

  Future<void> forward() => _controller.forward();

  Future<void> reverse() => _controller.reverse();

  void reset() => _controller.reset();

  void dispose() => _controller.dispose();
}

// ============================================================================
// GLOW ANIMATION WIDGET
// ============================================================================

class AnimatedGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double intensity;
  final Duration duration;
  final bool isActive;
  final double blurRadius;
  final double spreadRadius;

  const AnimatedGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.intensity = 0.3,
    this.duration = const Duration(milliseconds: 1200),
    this.isActive = true,
    this.blurRadius = 20.0,
    this.spreadRadius = 0.0,
  });

  @override
  State<AnimatedGlow> createState() => _AnimatedGlowState();
}

class _AnimatedGlowState extends State<AnimatedGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _glowAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    ));

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(
                  alpha: widget.intensity * _glowAnimation.value,
                ),
                blurRadius: widget.blurRadius * _glowAnimation.value,
                spreadRadius: widget.spreadRadius,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// CROSSFADE CONTENT WIDGET
// ============================================================================

class LiquidCrossfade<T> extends StatelessWidget {
  final T value;
  final Widget Function(T value) builder;
  final Duration duration;
  final Curve curve;

  const LiquidCrossfade({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: curve,
            )),
            child: child,
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey<T>(value),
        child: builder(value),
      ),
    );
  }
}

// ============================================================================
// HAPTIC FEEDBACK UTILITIES
// ============================================================================

class ModeHaptics {
  static void selectionFeedback(dynamic mode) {
    final modeName = mode.toString().split('.').last;
    switch (modeName) {
      case 'cozy':
        HapticFeedback.lightImpact();
        break;
      case 'normal':
        HapticFeedback.mediumImpact();
        break;
      case 'tuff':
        HapticFeedback.heavyImpact();
        break;
    }
  }

  static void tapFeedback() {
    HapticFeedback.selectionClick();
  }

  static void successFeedback() {
    HapticFeedback.mediumImpact();
  }
}

// ============================================================================
// PERFORMANCE UTILITIES
// ============================================================================

class AnimationPerformanceMonitor {
  static bool _debugEnabled = false;
  static final List<double> _frameTimes = [];
  static const int _maxSamples = 60;

  static void enableDebug() {
    _debugEnabled = true;
  }

  static void recordFrame(Duration frameTime) {
    if (!_debugEnabled) return;

    final ms = frameTime.inMicroseconds / 1000.0;
    _frameTimes.add(ms);

    if (_frameTimes.length > _maxSamples) {
      _frameTimes.removeAt(0);
    }
  }

  static double get averageFrameTime {
    if (_frameTimes.isEmpty) return 0;
    return _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
  }

  static bool get isPerforming60fps => averageFrameTime < 16.67;

  static void reset() {
    _frameTimes.clear();
  }
}

// ============================================================================
// ACCESSIBILITY UTILITIES
// ============================================================================

class MotionPreferences {
  /// Check if reduced motion is preferred
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get animation duration based on motion preferences
  static Duration getAdjustedDuration(
    BuildContext context,
    Duration normalDuration,
  ) {
    if (shouldReduceMotion(context)) {
      return Duration(milliseconds: normalDuration.inMilliseconds ~/ 3);
    }
    return normalDuration;
  }

  /// Get animation curve based on motion preferences
  static Curve getAdjustedCurve(
    BuildContext context,
    Curve normalCurve,
  ) {
    if (shouldReduceMotion(context)) {
      return Curves.linear;
    }
    return normalCurve;
  }
}

// ============================================================================
// LIQUID FLOW PAINTER
// ============================================================================

class LiquidFlowPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;
  final Offset startPosition;
  final Offset endPosition;

  LiquidFlowPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    required this.startPosition,
    required this.endPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          startColor.withValues(alpha: 0.6 * (1 - progress)),
          endColor.withValues(alpha: 0.6 * progress),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    // Draw flowing blob
    final currentX = startPosition.dx +
        (endPosition.dx - startPosition.dx) * progress;
    final currentY = startPosition.dy +
        (endPosition.dy - startPosition.dy) * progress;

    final blobRadius = 30.0 * math.sin(progress * math.pi);

    canvas.drawCircle(
      Offset(currentX, currentY),
      blobRadius,
      paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );
  }

  @override
  bool shouldRepaint(LiquidFlowPainter oldDelegate) {
    return progress != oldDelegate.progress ||
           startColor != oldDelegate.startColor ||
           endColor != oldDelegate.endColor;
  }
}

// ============================================================================
// SHIMMER LOADING EFFECT
// ============================================================================

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF2A2A2A),
    this.highlightColor = const Color(0xFF3A3A3A),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
