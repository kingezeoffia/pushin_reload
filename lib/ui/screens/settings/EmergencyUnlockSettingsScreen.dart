import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';

/// Emergency Unlock Settings Screen
///
/// Simplified design:
/// - GOStepsBackground with animated gradient
/// - Red/coral gradient text and icons
/// - Clean, minimal settings layout
class EmergencyUnlockSettingsScreen extends StatelessWidget {
  const EmergencyUnlockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Consumer<PushinAppController>(
            builder: (context, controller, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white.withOpacity(0.8),
                          size: 22,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // Heading section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Emergency',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF6060), Color(0xFFFF9090)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'Unlock',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bypass workouts when needed',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.6),
                            letterSpacing: -0.2,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Usage Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: _UsageCard(
                      unlocksRemaining:
                          controller.emergencyUnlocksRemaining,
                      maxUnlocks: controller.maxEmergencyUnlocksPerDay,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Settings toggles
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        // Enable Toggle
                        _SettingToggle(
                          icon: Icons.flash_on_rounded,
                          title: 'Enable Emergency Unlock',
                          description: 'Allow bypassing workouts',
                          value: controller.emergencyUnlockEnabled,
                          onChanged: (value) {
                            HapticFeedback.lightImpact();
                            controller.setEmergencyUnlockEnabled(value);
                          },
                        ),

                        const SizedBox(height: 16),

                        // Duration Picker
                        _DurationSetting(
                          icon: Icons.timer,
                          title: 'Duration per unlock',
                          description: 'How long each unlock lasts',
                          selectedMinutes: controller.emergencyUnlockMinutes,
                          enabled: controller.emergencyUnlockEnabled,
                          onChanged: (minutes) {
                            HapticFeedback.lightImpact();
                            controller.setEmergencyUnlockMinutes(minutes);
                          },
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Save Changes Button
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).padding.bottom + 8,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _SaveChangesButton(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          // Settings are automatically saved via the controller
                          // Just pop back to previous screen
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Usage Card showing remaining unlocks
class _UsageCard extends StatelessWidget {
  final int unlocksRemaining;
  final int maxUnlocks;

  const _UsageCard({
    required this.unlocksRemaining,
    required this.maxUnlocks,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnlocks = unlocksRemaining > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6060).withOpacity(0.15),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6060).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              hasUnlocks ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: const Color(0xFFFF9090),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlocksRemaining of $maxUnlocks remaining',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF9090),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasUnlocks
                      ? 'Emergency unlocks available today'
                      : 'Resets at midnight',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle setting item
class _SettingToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6060).withOpacity(0.15),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFF9090),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFFF6060).withOpacity(0.5),
            activeColor: const Color(0xFFFF9090),
            inactiveThumbColor: Colors.white.withOpacity(0.5),
            inactiveTrackColor: Colors.white.withOpacity(0.15),
          ),
        ],
      ),
    );
  }
}

/// Duration picker setting
class _DurationSetting extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int selectedMinutes;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _DurationSetting({
    required this.icon,
    required this.title,
    required this.description,
    required this.selectedMinutes,
    required this.enabled,
    required this.onChanged,
  });

  static const List<int> durations = [10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6060).withOpacity(0.15),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFFF9090),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.5),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Duration chips
            Row(
              children: durations.map((minutes) {
                final isSelected = minutes == selectedMinutes;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: minutes == durations.last ? 0 : 8,
                    ),
                    child: GestureDetector(
                      onTap: enabled ? () => onChanged(minutes) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF6060).withOpacity(0.25)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF9090).withOpacity(0.5)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${minutes}m',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFFFF9090)
                                  : Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Save Changes Button Widget
class _SaveChangesButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SaveChangesButton({
    required this.onTap,
  });  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Save Changes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A2A6A),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}
