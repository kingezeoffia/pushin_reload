import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/settings_design_tokens.dart';

enum SettingsTileType {
  navigation,
  toggle,
  slider,
  colorPicker,
}

/// Sleek, minimal settings section matching onboarding aesthetic
/// - Clean section headers (just elegant text)
/// - Subtle container styling
/// - No heavy shadows or thick containers
class EnhancedSettingsSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final List<Widget> children;
  final int delay;

  const EnhancedSettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.gradient,
    required this.children,
    this.delay = 0,
  });

  @override
  State<EnhancedSettingsSection> createState() =>
      _EnhancedSettingsSectionState();
}

class _EnhancedSettingsSectionState extends State<EnhancedSettingsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extract the primary color from the gradient for the section accent
    final accentColor = widget.gradient.colors.first;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sleek section header - just elegant text with subtle accent
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Row(
                children: [
                  // Subtle icon accent
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icon,
                      color: accentColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.4),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Content container - subtle, clean styling
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: widget.children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ENHANCED SETTINGS TILE - Sleek, minimal design
// =============================================================================

class EnhancedSettingsTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final SettingsTileType type;
  final bool? initialValue;
  final double? sliderValue;
  final VoidCallback? onTap;

  const EnhancedSettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    required this.type,
    this.initialValue = false,
    this.sliderValue = 0.5,
    this.onTap,
  });

  @override
  State<EnhancedSettingsTile> createState() => _EnhancedSettingsTileState();
}

class _EnhancedSettingsTileState extends State<EnhancedSettingsTile> {
  late bool _toggleValue;
  late double _sliderValue;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _toggleValue = widget.initialValue ?? false;
    _sliderValue = widget.sliderValue ?? 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.type == SettingsTileType.navigation
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _isPressed ? Colors.white.withOpacity(0.06) : Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (widget.leadingIcon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C8CFF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.leadingIcon,
                        color: const Color(0xFF7C8CFF),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildTrailing(),
                ],
              ),
            ),
            if (widget.type == SettingsTileType.slider) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF7C8CFF),
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFF7C8CFF).withOpacity(0.2),
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: _sliderValue,
                    onChanged: (value) {
                      setState(() => _sliderValue = value);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
              ),
            ],
            // Subtle divider
            Padding(
              padding: const EdgeInsets.only(left: 66),
              child: Container(
                height: 0.5,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailing() {
    switch (widget.type) {
      case SettingsTileType.toggle:
        return AnimatedToggle(
          value: _toggleValue,
          onChanged: (value) {
            HapticFeedback.lightImpact();
            setState(() => _toggleValue = value);
          },
        );
      case SettingsTileType.slider:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF7C8CFF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${(_sliderValue * 100).round()}%',
            style: const TextStyle(
              color: Color(0xFF7C8CFF),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case SettingsTileType.colorPicker:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF7C8CFF),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 2,
            ),
          ),
        );
      case SettingsTileType.navigation:
        return Icon(
          Icons.chevron_right_rounded,
          color: Colors.white.withOpacity(0.25),
          size: 20,
        );
    }
  }
}

// =============================================================================
// ANIMATED TOGGLE - Sleek, minimal design
// =============================================================================

class AnimatedToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AnimatedToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<AnimatedToggle> createState() => _AnimatedToggleState();
}

class _AnimatedToggleState extends State<AnimatedToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(AnimatedToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
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
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final activeColor = const Color(0xFF4ADE80); // Success green
          return Container(
            width: 46,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: Color.lerp(
                Colors.white.withOpacity(0.15),
                activeColor,
                _controller.value,
              ),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: 2 + (_controller.value * 20),
                  top: 2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
