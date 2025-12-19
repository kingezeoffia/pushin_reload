import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated Blob Background - Lava lamp style flowing gradients
/// 
/// Design Reference: GO Steps/GO Club animated blob backgrounds
/// Creates organic, flowing blob shapes with gradient colors that animate smoothly
class AnimatedBlobBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;

  const AnimatedBlobBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF4F46E5), // Indigo
      Color(0xFF3B82F6), // Blue
      Color(0xFF8B5CF6), // Purple
      Color(0xFF6366F1), // Indigo-blue
    ],
    this.duration = const Duration(seconds: 8),
  });

  @override
  State<AnimatedBlobBackground> createState() => _AnimatedBlobBackgroundState();
}

class _AnimatedBlobBackgroundState extends State<AnimatedBlobBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;

  @override
  void initState() {
    super.initState();
    
    // Create multiple controllers for different blob layers
    _controller1 = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    
    _controller2 = AnimationController(
      duration: Duration(milliseconds: (widget.duration.inMilliseconds * 1.3).round()),
      vsync: this,
    )..repeat(reverse: true);
    
    _controller3 = AnimationController(
      duration: Duration(milliseconds: (widget.duration.inMilliseconds * 0.8).round()),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A), // Dark slate
                Color(0xFF1E293B), // Lighter slate
              ],
            ),
          ),
        ),
        
        // Animated blob layers
        AnimatedBuilder(
          animation: Listenable.merge([_controller1, _controller2, _controller3]),
          builder: (context, child) {
            return CustomPaint(
              painter: BlobPainter(
                animation1: _controller1.value,
                animation2: _controller2.value,
                animation3: _controller3.value,
                colors: widget.colors,
              ),
              child: Container(),
            );
          },
        ),
        
        // Blur overlay for softness
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.transparent,
                Colors.black.withOpacity(0.5),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        
        // Child content
        widget.child,
      ],
    );
  }
}

/// Custom painter for flowing blob shapes
class BlobPainter extends CustomPainter {
  final double animation1;
  final double animation2;
  final double animation3;
  final List<Color> colors;

  BlobPainter({
    required this.animation1,
    required this.animation2,
    required this.animation3,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Blob 1 - Large, slow-moving
    _drawBlob(
      canvas,
      size,
      paint,
      offset: Offset(
        size.width * (0.2 + 0.3 * math.sin(animation1 * 2 * math.pi)),
        size.height * (0.3 + 0.2 * math.cos(animation1 * 2 * math.pi)),
      ),
      radius: size.width * (0.4 + 0.1 * math.sin(animation1 * 2 * math.pi)),
      color: colors[0].withOpacity(0.6),
    );

    // Blob 2 - Medium, faster
    _drawBlob(
      canvas,
      size,
      paint,
      offset: Offset(
        size.width * (0.7 + 0.2 * math.cos(animation2 * 2 * math.pi)),
        size.height * (0.6 + 0.3 * math.sin(animation2 * 2 * math.pi)),
      ),
      radius: size.width * (0.35 + 0.08 * math.cos(animation2 * 2 * math.pi)),
      color: colors[1].withOpacity(0.5),
    );

    // Blob 3 - Small, fastest
    _drawBlob(
      canvas,
      size,
      paint,
      offset: Offset(
        size.width * (0.5 + 0.25 * math.sin(animation3 * 2 * math.pi)),
        size.height * (0.8 + 0.15 * math.cos(animation3 * 2 * math.pi)),
      ),
      radius: size.width * (0.3 + 0.05 * math.sin(animation3 * 2 * math.pi)),
      color: colors[2].withOpacity(0.4),
    );

    // Blob 4 - Accent blob
    _drawBlob(
      canvas,
      size,
      paint,
      offset: Offset(
        size.width * (0.15 + 0.15 * math.cos(animation2 * 1.5 * math.pi)),
        size.height * (0.7 + 0.2 * math.sin(animation1 * 1.5 * math.pi)),
      ),
      radius: size.width * (0.25 + 0.05 * math.cos(animation3 * 2 * math.pi)),
      color: colors[3].withOpacity(0.35),
    );
  }

  void _drawBlob(
    Canvas canvas,
    Size size,
    Paint paint,
    {
    required Offset offset,
    required double radius,
    required Color color,
  }) {
    paint.color = color;
    
    // Create organic blob shape using multiple circles
    final path = Path();
    const int points = 8;
    
    for (int i = 0; i < points; i++) {
      final angle = (i / points) * 2 * math.pi;
      final nextAngle = ((i + 1) / points) * 2 * math.pi;
      
      // Add some randomness to radius for organic feel
      final radiusVariation = 0.8 + 0.4 * math.sin(angle * 3 + animation1 * 2 * math.pi);
      final r = radius * radiusVariation;
      
      final x = offset.dx + r * math.cos(angle);
      final y = offset.dy + r * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Use quadratic bezier for smooth curves
        final nextRadiusVariation = 0.8 + 0.4 * math.sin(nextAngle * 3 + animation1 * 2 * math.pi);
        final nextR = radius * nextRadiusVariation;
        final nextX = offset.dx + nextR * math.cos(nextAngle);
        final nextY = offset.dy + nextR * math.sin(nextAngle);
        
        final controlX = (x + nextX) / 2 + r * 0.3 * math.cos(angle + math.pi / 2);
        final controlY = (y + nextY) / 2 + r * 0.3 * math.sin(angle + math.pi / 2);
        
        path.quadraticBezierTo(controlX, controlY, nextX, nextY);
      }
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BlobPainter oldDelegate) {
    return oldDelegate.animation1 != animation1 ||
        oldDelegate.animation2 != animation2 ||
        oldDelegate.animation3 != animation3;
  }
}

/// Simpler version with radial gradients (lighter weight)
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFF4F46E5),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
    ],
  });

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
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
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                math.cos(_controller.value * 2 * math.pi),
                math.sin(_controller.value * 2 * math.pi),
              ),
              end: Alignment(
                -math.cos(_controller.value * 2 * math.pi),
                -math.sin(_controller.value * 2 * math.pi),
              ),
              colors: widget.colors,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(
                  0.5 * math.cos(_controller.value * 3 * math.pi),
                  0.5 * math.sin(_controller.value * 3 * math.pi),
                ),
                radius: 1.5,
                colors: [
                  widget.colors[1].withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}





















