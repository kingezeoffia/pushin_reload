import 'package:flutter/material.dart';
import '../../theme/pushin_theme.dart';
import 'SettingsSection.dart';

/// Themes settings section
class ThemesSection extends StatefulWidget {
  const ThemesSection({super.key});

  @override
  State<ThemesSection> createState() => _ThemesSectionState();
}

class _ThemesSectionState extends State<ThemesSection> {
  ThemeMode _selectedTheme = ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Appearance',
      icon: Icons.palette,
      children: [
        // Theme mode selector
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: PushinTheme.spacingMd,
            vertical: PushinTheme.spacingSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: PushinTheme.body1.copyWith(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: PushinTheme.spacingSm),
              Row(
                children: [
                  _buildThemeOption(
                    title: 'Light',
                    mode: ThemeMode.light,
                    icon: Icons.wb_sunny,
                  ),
                  SizedBox(width: PushinTheme.spacingMd),
                  _buildThemeOption(
                    title: 'Dark',
                    mode: ThemeMode.dark,
                    icon: Icons.nightlight_round,
                  ),
                  SizedBox(width: PushinTheme.spacingMd),
                  _buildThemeOption(
                    title: 'System',
                    mode: ThemeMode.system,
                    icon: Icons.settings_suggest,
                  ),
                ],
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Divider(height: 1, color: Color(0xFF334155)), // Slate 700
        ),

        // Color scheme preview
        SettingsListTile(
          title: 'Color Scheme',
          subtitle: 'Default (Blue)',
          leadingIcon: Icons.color_lens,
          onTap: () {
            // TODO: Navigate to color scheme selector
          },
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required String title,
    required ThemeMode mode,
    required IconData icon,
  }) {
    final isSelected = _selectedTheme == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTheme = mode),
        child: Container(
          padding: EdgeInsets.all(PushinTheme.spacingMd),
          decoration: BoxDecoration(
            color: isSelected
                ? PushinTheme.primaryBlue.withOpacity(0.2)
                : PushinTheme.surfaceDark,
            borderRadius: BorderRadius.circular(PushinTheme.radiusMd),
            border: Border.all(
              color: isSelected
                  ? PushinTheme.primaryBlue
                  : PushinTheme.surfaceDark,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? PushinTheme.primaryBlue
                    : PushinTheme.textSecondary,
                size: 24,
              ),
              SizedBox(height: PushinTheme.spacingXs),
              Text(
                title,
                style: PushinTheme.caption.copyWith(
                  color: isSelected
                      ? PushinTheme.primaryBlue
                      : PushinTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}







