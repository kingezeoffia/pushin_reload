import 'package:flutter/material.dart';

/// GO Steps Style Background - Premium gradient aesthetic
///
/// Design spec (BMAD V6):
/// - Top ~1/3 to 1/4 of screen is pure black
/// - Bottom ~3/4 is purple/lavender blur gradient
/// - Title always fits perfectly into this background
/// - Clean, premium, modern feel
class GOStepsBackground extends StatelessWidget {
  final Widget child;
  final double blackRatio;

  const GOStepsBackground({
    super.key,
    required this.child,
    this.blackRatio = 0.28,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base: Pure black
        Container(
          color: Colors.black,
        ),

        // Main gradient: Black top transitioning to purple/lavender bottom
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Colors.black,
                  Colors.black,
                  Color(0xFF0A0A1A), // Very dark purple-black
                  Color(0xFF12122A), // Dark navy-purple
                  Color(0xFF1E1E45), // Deep purple
                  Color(0xFF2A2A6A), // Medium purple
                  Color(0xFF3535A0), // Bright purple-blue
                  Color(0xFF4040C0), // Vivid lavender-blue
                ],
                stops: [
                  0.0,
                  blackRatio - 0.05,
                  blackRatio,
                  blackRatio + 0.15,
                  blackRatio + 0.30,
                  0.70,
                  0.85,
                  1.0,
                ],
              ),
            ),
          ),
        ),

        // Soft radial glow from bottom center for depth
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, 1.3),
                radius: 1.0,
                colors: [
                  const Color(0xFF5050E0).withOpacity(0.5),
                  const Color(0xFF4040C0).withOpacity(0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.8],
              ),
            ),
          ),
        ),

        // Subtle purple accent glow
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.5, 0.9),
                radius: 0.7,
                colors: [
                  const Color(0xFF6060FF).withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Child content
        child,
      ],
    );
  }
}

/// Workout Selection Background - Clean gradient without radial glows
///
/// Specialized for screens with content throughout (like workout grids)
/// Removes the radial gradients that interfere with card visibility
class WorkoutSelectionBackground extends StatelessWidget {
  final Widget child;
  final double blackRatio;

  const WorkoutSelectionBackground({
    super.key,
    required this.child,
    this.blackRatio = 0.40, // Higher default for workout screens
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base: Pure black
        Container(
          color: Colors.black,
        ),

        // Main gradient: Black top transitioning to purple/lavender bottom
        // No radial gradients to avoid interference with workout cards
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Colors.black,
                  Colors.black,
                  Color(0xFF0A0A1A), // Very dark purple-black
                  Color(0xFF12122A), // Dark navy-purple
                  Color(0xFF1E1E45), // Deep purple
                  Color(0xFF2A2A6A), // Medium purple
                  Color(0xFF3535A0), // Bright purple-blue
                  Color(0xFF4040C0), // Vivid lavender-blue
                ],
                stops: [
                  0.0,
                  blackRatio - 0.05,
                  blackRatio,
                  blackRatio + 0.15,
                  blackRatio + 0.30,
                  0.70,
                  0.85,
                  1.0,
                ],
              ),
            ),
          ),
        ),

        // Child content
        child,
      ],
    );
  }
}
