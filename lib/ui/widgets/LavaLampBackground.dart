import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Lava Lamp Background - Animated floating blob gradients
///
/// Recreates the HTML lava lamp effect with:
/// - Pink/coral and blue/purple radial gradient blobs
/// - Blur effects and screen blend mode
/// - Horizontal-focused floating animation
/// - Randomized animation timing for organic feel
class LavaLampBackground extends StatefulWidget {
  final Widget child;

  const LavaLampBackground({
    super.key,
    required this.child,
  });

  @override
  State<LavaLampBackground> createState() => _LavaLampBackgroundState();
}

class _LavaLampBackgroundState extends State<LavaLampBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;

  // Randomize animation durations for organic feel
  late Duration _duration1;
  late Duration _duration2;

  // Store screen size to avoid MediaQuery calls during animation
  late Size _screenSize;

  @override
  void initState() {
    super.initState();

    // Store initial screen size
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    _screenSize = view.physicalSize / view.devicePixelRatio;

    // Create randomized durations (15-25 seconds for more dynamic movement)
    _duration1 = Duration(seconds: 15 + math.Random().nextInt(11));
    _duration2 = Duration(seconds: 18 + math.Random().nextInt(11));

    _controller1 = AnimationController(
      duration: _duration1,
      vsync: this,
    )..repeat();

    _controller2 = AnimationController(
      duration: _duration2,
      vsync: this,
    )..repeat();

    // Add slight offset to start times for asynchronous movement
    Future.delayed(Duration(milliseconds: math.Random().nextInt(1000)), () {
      if (mounted) _controller1.forward();
    });

    Future.delayed(Duration(milliseconds: math.Random().nextInt(1500)), () {
      if (mounted) _controller2.forward();
    });
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Update screen size if it changed
    final currentScreenSize = MediaQuery.of(context).size;
    if (_screenSize != currentScreenSize) {
      _screenSize = currentScreenSize;
    }

    return Stack(
      children: [
        // Base dark background
        Container(
          color: const Color(0xFF111113),
        ),

        // Animated blobs with blur and blend mode
        AnimatedBuilder(
          animation: Listenable.merge([_controller1, _controller2]),
          builder: (context, child) {
            return Stack(
              children: [
                // Blob 1 - Pink/Coral
                _buildBlob(
                  animationValue: _controller1.value,
                  size: 350.0,
                  position: _calculateBlob1Position(_controller1.value),
                  gradient: const RadialGradient(
                    colors: [
                      Color.fromRGBO(
                          255, 107, 139, 0.35), // rgba(255, 107, 139, 0.35)
                      Color.fromRGBO(
                          255, 107, 139, 0.1), // rgba(255, 107, 139, 0.1)
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),

                // Blob 2 - Blue/Purple
                _buildBlob(
                  animationValue: _controller2.value,
                  size: 400.0,
                  position: _calculateBlob2Position(_controller2.value),
                  gradient: const RadialGradient(
                    colors: [
                      Color.fromRGBO(
                          107, 139, 255, 0.3), // rgba(107, 139, 255, 0.3)
                      Color.fromRGBO(
                          107, 139, 255, 0.08), // rgba(107, 139, 255, 0.08)
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),

                // Fade edges overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF111113).withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.transparent,
                        const Color(0xFF111113).withValues(alpha: 0.4),
                      ],
                      stops: const [0.0, 0.1, 0.9, 1.0],
                    ),
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF111113).withValues(alpha: 0.3),
                      ],
                      stops: const [0.8, 1.0],
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // Child content
        widget.child,
      ],
    );
  }

  Widget _buildBlob({
    required double animationValue,
    required double size,
    required Offset position,
    required RadialGradient gradient,
  }) {
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(size / 2), // Make it circular
        ),
      ),
    );
  }

  Offset _calculateBlob1Position(double animationValue) {
    // Horizontal movement: 0% to 100% of screen width
    // Vertical movement: subtle variation around center-top
    final x =
        _screenSize.width * (0.1 + 0.8 * animationValue); // 10% to 90% width
    final y = _screenSize.height *
        (0.2 +
            0.1 *
                math.sin(
                    animationValue * 2 * math.pi)); // Subtle vertical variation

    return Offset(x, y);
  }

  Offset _calculateBlob2Position(double animationValue) {
    // Horizontal movement: reverse direction, 90% to 10% of screen width
    // Vertical movement: subtle variation around center-bottom
    final x =
        _screenSize.width * (0.85 - 0.75 * animationValue); // 85% to 10% width
    final y = _screenSize.height *
        (0.4 +
            0.15 *
                math.sin(
                    animationValue * 2 * math.pi)); // Subtle vertical variation

    return Offset(x, y);
  }
}
