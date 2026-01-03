import 'package:flutter/material.dart';

/// Animated Lava Lamp Background - Subtle purple gradient with smooth animated effects
///
/// Creates a sleek, barely noticeable animated background that blends seamlessly
/// with subtle purple gradients and gentle radial glows that stay within bounds
class AnimatedLavaLampBackground extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  const AnimatedLavaLampBackground({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding,
  });

  @override
  State<AnimatedLavaLampBackground> createState() => _AnimatedLavaLampBackgroundState();
}

class _AnimatedLavaLampBackgroundState extends State<AnimatedLavaLampBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Single smooth animation controller for subtle effect
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F0F25), // Very dark purple-black
                  const Color(0xFF14143A), // Dark navy-purple
                  const Color(0xFF1A1A50), // Deep purple
                  const Color(0xFF202070), // Medium purple
                  const Color(0xFF2A2A85), // Bright purple-blue
                  const Color(0xFF3232A0), // Vivid lavender-blue
                ],
                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Very subtle animated radial glow - stays within bounds
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          0.1 + _animation.value * 0.1, // Minimal horizontal shift
                          0.8 + _animation.value * 0.1, // Minimal vertical shift
                        ),
                        radius: 0.6 + _animation.value * 0.1, // Small radius variation
                        colors: [
                          const Color(0xFF4040D0).withOpacity(0.15 + _animation.value * 0.05),
                          const Color(0xFF3535B0).withOpacity(0.08 + _animation.value * 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Secondary subtle glow from top-right corner - very contained
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          0.3 + _animation.value * 0.1, // Gentle movement
                          -0.2 + _animation.value * 0.15, // Gentle movement
                        ),
                        radius: 0.4 + _animation.value * 0.08,
                        colors: [
                          const Color(0xFF5050E0).withOpacity(0.08 + _animation.value * 0.04),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),

                // Tiny highlight overlay for depth - barely visible
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.03 + _animation.value * 0.02,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.8,
                          colors: [
                            Colors.white.withOpacity(0.02),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Child content
                widget.child,
              ],
            ),
          ),
        );
      },
    );
  }
}
