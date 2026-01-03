import 'package:flutter/material.dart';
import '../../theme/enhanced_settings_design_tokens.dart';

enum SettingsTileType {
  navigation,
  toggle,
  slider,
  colorPicker,
}

class EnhancedSettingsTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;
  final Color? iconColor;

  const EnhancedSettingsTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EnhancedSettingsDesignTokens.spacingLarge,
                vertical: EnhancedSettingsDesignTokens.spacingSmall,
              ),
              child: Row(
                children: [
                  if (icon != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EnhancedSettingsDesignTokens.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor ?? EnhancedSettingsDesignTokens.primaryPurple,
                        size: 18,
                      ),
                    ),
                  if (icon != null) const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: EnhancedSettingsDesignTokens.tileTitle,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: EnhancedSettingsDesignTokens.tileSubtitle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ] else
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withOpacity(0.4),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: Colors.white.withOpacity(0.1),
            indent: EnhancedSettingsDesignTokens.spacingLarge,
            endIndent: EnhancedSettingsDesignTokens.spacingLarge,
          ),
      ],
    );
  }
}

class EnhancedSettingsSwitchTile extends StatefulWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;

  const EnhancedSettingsSwitchTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.showDivider = true,
  });

  @override
  State<EnhancedSettingsSwitchTile> createState() => _EnhancedSettingsSwitchTileState();
}

class _EnhancedSettingsSwitchTileState extends State<EnhancedSettingsSwitchTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: EnhancedSettingsDesignTokens.toggleAnimation,
      vsync: this,
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(EnhancedSettingsSwitchTile oldWidget) {
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
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onChanged != null
                ? () => widget.onChanged!(!widget.value)
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EnhancedSettingsDesignTokens.spacingLarge,
                vertical: EnhancedSettingsDesignTokens.spacingSmall,
              ),
              child: Row(
                children: [
                  if (widget.icon != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: EnhancedSettingsDesignTokens.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.icon,
                        color: EnhancedSettingsDesignTokens.primaryPurple,
                        size: 18,
                      ),
                    ),
                  if (widget.icon != null) const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: EnhancedSettingsDesignTokens.tileTitle,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: EnhancedSettingsDesignTokens.tileSubtitle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Container(
                        width: 50,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Color.lerp(
                            Colors.white.withOpacity(0.2),
                            EnhancedSettingsDesignTokens.primaryPurple,
                            _controller.value,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: EnhancedSettingsDesignTokens.primaryPurple.withOpacity(_controller.value * 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: EnhancedSettingsDesignTokens.toggleAnimation,
                              curve: Curves.easeInOut,
                              left: _controller.value * 22,
                              top: 2,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
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
                ],
              ),
            ),
          ),
        ),
        if (widget.showDivider)
          Divider(
            height: 1,
            color: Colors.white.withOpacity(0.1),
            indent: EnhancedSettingsDesignTokens.spacingLarge,
            endIndent: EnhancedSettingsDesignTokens.spacingLarge,
          ),
      ],
    );
  }
}

