import 'package:flutter/material.dart';
import '../../theme/pushin_theme.dart';

/// Base settings section widget with consistent styling
class SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? accentColor;

  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PushinTheme.surfaceDark,
        borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
        boxShadow: PushinTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: EdgeInsets.all(PushinTheme.spacingMd),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (accentColor ?? PushinTheme.primaryBlue).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(PushinTheme.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor ?? PushinTheme.primaryBlue,
                    size: 20,
                  ),
                ),
                SizedBox(width: PushinTheme.spacingMd),
                Text(
                  title,
                  style: PushinTheme.headline3,
                ),
              ],
            ),
          ),

          // Section content
          ...children,
        ],
      ),
    );
  }
}

/// Settings list tile for consistent item styling
class SettingsListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const SettingsListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: leadingIcon != null
              ? Icon(
                  leadingIcon,
                  color: PushinTheme.primaryBlue,
                  size: 20,
                )
              : null,
          title: Text(
            title,
            style: PushinTheme.body1.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: PushinTheme.caption.copyWith(
                    color: PushinTheme.textSecondary,
                  ),
                )
              : null,
          trailing: trailing ??
              (onTap != null
                  ? Icon(
                      Icons.chevron_right,
                      color: PushinTheme.textTertiary,
                    )
                  : null),
          onTap: onTap,
          contentPadding: EdgeInsets.symmetric(
            horizontal: PushinTheme.spacingMd,
            vertical: PushinTheme.spacingXs,
          ),
          dense: true,
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Divider(height: 1, color: Color(0xFF334155)), // Slate 700
          ),
      ],
    );
  }
}







