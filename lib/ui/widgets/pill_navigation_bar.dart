import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../theme/pushin_theme.dart';

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
    {'icon': Icons.fitness_center, 'label': 'Workouts'},
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
      bottom: safePadding + 8, // VERY BOTTOM - only 8px padding
      child: Center(
        child: Container(
          width: pillWidth,
          height: 64, // TALLER for text space
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32), // Full pill radius
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Stack(
                  children: [
                    // Animated background indicator
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
                              color: Colors.white.withOpacity(0.12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      PushinTheme.primaryBlue.withOpacity(0.3),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ],
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
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        scale: isPressed ? 0.92 : 1.0,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
              horizontal: 8), // Extra horizontal padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon without background
              Icon(
                icon,
                size: isActive ? 26 : 24, // Slightly larger icons
                color: isActive ? Colors.white : Colors.white.withOpacity(0.5),
              ),
              const SizedBox(height: 4),
              // Animated text label - NO CUTOFF
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                height: isActive ? 20 : 0, // More height for text
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isActive ? 1.0 : 0.0,
                  child: isActive
                      ? Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13, // Slightly bigger text
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            height: 1.0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
