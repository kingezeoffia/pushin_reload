import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'native_liquid_glass.dart';

/// Standardized bottom button container that positions content at screen edge level (like Continue As Guest button)
class BottomActionContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const BottomActionContainer({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: safePadding, // Right at screen edge like Continue As Guest button
      child: Padding(
        padding: padding!,
        child: child,
      ),
    );
  }
}

class PillNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  const PillNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onTabChanged,
  }) : super(key: key);

  @override
  State<PillNavigationBar> createState() => _PillNavigationBarState();
}

class _PillNavigationBarState extends State<PillNavigationBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int? _pressedIndex;
  late int _prevIndex;

  // EXACTLY 3 TABS: Workouts, Home, Settings
  final List<Map<String, dynamic>> _tabs = [
    {'icon': Icons.directions_run, 'label': 'Workouts'},
    {'icon': Icons.home, 'label': 'Home'},
    {'icon': Icons.settings, 'label': 'Settings'},
  ];

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.selectedIndex;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(PillNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _prevIndex = oldWidget.selectedIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final pillWidth = screenWidth * 0.9; // WIDE PILL - 90% width
    final tabWidth = pillWidth / 3; // Divide equally among 3 tabs

    return Positioned(
      left: 0,
      right: 0,
      bottom:
          safePadding, // RIGHT AT SCREEN EDGE - no extra padding like Continue As Guest button
      child: Center(
        child: SizedBox(
          width: pillWidth,
          height: 64, // BACK TO ORIGINAL HEIGHT - text space
          child: NativeLiquidGlass(
            borderRadius: 32, // Full pill radius
            blurSigma: 20.0,
            useUltraThinMaterial:
                true, // Use Apple's ultra-thin material for navigation
            child: Stack(
              children: [
                // Animated background indicator with enhanced glass
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final position = widget.selectedIndex * tabWidth;
                    final animatedPosition = Tween<double>(
                      begin: _prevIndex * tabWidth,
                      end: position,
                    )
                        .animate(CurvedAnimation(
                          parent: _controller,
                          curve: Curves.easeInOutCubicEmphasized,
                        ))
                        .value;

                    return Positioned(
                      left: animatedPosition + 6,
                      top: 6,
                      bottom: 6,
                      child: Container(
                        width: tabWidth - 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          // Flat, minimal background - no gradient depth
                          color: Colors.white.withOpacity(0.08),
                          // No shadows - completely flat, modern look
                        ),
                      ),
                    );
                  },
                ),
                // Tabs row - evenly distributed
                Row(
                  children: List.generate(_tabs.length, (index) {
                    return Expanded(
                      child: _buildTab(
                        index: index,
                        icon: _tabs[index]['icon'] as IconData,
                        label: _tabs[index]['label'] as String,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isActive = widget.selectedIndex == index;
    final isPressed = _pressedIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressedIndex = index;
        });
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _pressedIndex = null);
        if (widget.selectedIndex != index) {
          widget.onTabChanged(index);
        }
      },
      onTapCancel: () => setState(() => _pressedIndex = null),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
            horizontal: 8), // Extra horizontal padding
        child: // ULTRA-BRIGHT ICONS - Maximum reflectivity for light-bouncing glass with tap scaling
            AnimatedScale(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubicEmphasized,
          scale: isPressed
              ? 1.2
              : (isActive
                  ? 1.1
                  : 1.0), // Bigger when pressed, slightly bigger when active
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isActive
                  ? [
                      Colors.white.withOpacity(1.0), // MAXIMUM BRIGHTNESS
                      Colors.white.withOpacity(0.98),
                    ]
                  : [
                      Colors.white.withOpacity(0.85), // Very bright inactive
                      Colors.white.withOpacity(0.75),
                    ],
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Icon(
              icon,
              size: isActive ? 28 : 24, // Larger base size for active state
            ),
          ),
        ),
      ),
    );
  }
}
