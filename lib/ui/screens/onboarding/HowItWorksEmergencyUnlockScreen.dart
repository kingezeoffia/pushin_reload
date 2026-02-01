import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../../state/auth_state_provider.dart';
import '../paywall/PaywallScreen.dart';

/// Step 4: Emergency Unlock
///
/// BMAD V6 Spec:
/// - Allowed three times per day
/// - Grants 30 minutes of unlocked screen time
/// - After use, the button becomes disabled until the next day
class HowItWorksEmergencyUnlockScreen extends StatelessWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;
  final String workoutHistory;
  final List<String> blockedApps;
  final String selectedWorkout;
  final int unlockDuration;

  const HowItWorksEmergencyUnlockScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
    required this.workoutHistory,
    required this.blockedApps,
    required this.selectedWorkout,
    required this.unlockDuration,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final authProvider = context.watch<AuthStateProvider>();

    // This screen should only be shown when onboarding is not completed
    // The router handles when to show this vs other screens

    // Debug: Check current state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print(
          '🔍 EmergencyUnlockScreen: Building with state - authenticated=${authProvider.isAuthenticated}, onboardingCompleted=${authProvider.isOnboardingCompleted}, onboardingStep=${authProvider.onboardingStep}');
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Consistent spacing with other screens
                  SizedBox(height: screenHeight * 0.06),

                  // Heading - consistent positioning
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emergency unlock icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6060).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.warning_rounded,
                            size: 40,
                            color: Color(0xFFFF9090),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF6060), Color(0xFFFF9090)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'Emergency',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFF6060), Color(0xFFFF9090)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
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
                          "For those rare moments when you need access",
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

                  SizedBox(height: screenHeight * 0.04),

                  // Rules List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        _RuleItem(
                          icon: Icons.timer,
                          title: 'Temporary Access',
                          description: 'Customizable duration',
                        ),
                        const SizedBox(height: 16),
                        _RuleItem(
                          icon: Icons.today,
                          title: 'Three times per day',
                          description: 'Emergency unlock 3x a day',
                        ),
                        const SizedBox(height: 16),
                        _RuleItem(
                          icon: Icons.lock_clock,
                          title: 'Auto-disable',
                          description: 'Disabled until tomorrow',
                        ),
                      ],
                    ),
                  ),

                  // Spacer to push content up (button will be positioned at bottom)
                  const Spacer(),
                ],
              ),
            ),

            // Continue to Paywall Button - properly positioned in Stack
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context)
                  .padding
                  .bottom, // Right at screen edge like navigation pill
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _ContinueButton(
                  onTap: () async {
                    try {
                      debugPrint(
                          '🎯 Continue to Paywall button pressed - manual navigation to paywall');

                      // Manual navigation to paywall screen
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PaywallScreen(
                              onboardingData: {
                                'fitnessLevel': fitnessLevel,
                                'goals': goals,
                                'otherGoal': otherGoal,
                                'workoutHistory': workoutHistory,
                                'blockedApps': blockedApps,
                                'selectedWorkout': selectedWorkout,
                                'unlockDuration': unlockDuration,
                              },
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('❌ Error navigating to paywall: $e');
                      // Show error to user
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error continuing setup: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rule item widget
class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _RuleItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6060).withOpacity(0.15),
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
    );
  }
}

/// Continue Button Widget
class _ContinueButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContinueButton({
    required this.onTap,
  });

  @override
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
            'Continue',
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
