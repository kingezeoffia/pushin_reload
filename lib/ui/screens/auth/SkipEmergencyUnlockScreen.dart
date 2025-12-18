import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/OnboardingService.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';

/// Skip Flow: Emergency Unlock Screen
///
/// Context-free version for users who skip onboarding
/// Final screen that completes setup and navigates to main app
class SkipEmergencyUnlockScreen extends StatelessWidget {
  final List<String> blockedApps;
  final String selectedWorkout;
  final int unlockDuration;

  const SkipEmergencyUnlockScreen({
    super.key,
    required this.blockedApps,
    required this.selectedWorkout,
    required this.unlockDuration,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button (no step indicator for skip flow)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16, top: 8),
                child: _BackButton(onTap: () => Navigator.pop(context)),
              ),

              const Spacer(),

              // Success Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Large Checkmark with Glow
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6060FF).withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6060FF).withOpacity(0.4),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF9090FF),
                        size: 80,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Success Title
                    const Text(
                      'Setup Complete!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Success Description
                    Text(
                      'You\'re all set to start earning screen time through exercise.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                        letterSpacing: -0.2,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 48),

                    // Summary
                    Container(
                      padding: const EdgeInsets.all(24),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          _SummaryItem(
                            icon: Icons.apps,
                            text: '${blockedApps.length} apps blocked',
                          ),
                          const SizedBox(height: 12),
                          _SummaryItem(
                            icon: Icons.fitness_center,
                            text: selectedWorkout,
                          ),
                          const SizedBox(height: 12),
                          _SummaryItem(
                            icon: Icons.timer,
                            text: '${unlockDuration} min unlock time',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Continue Button
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                child: _ContinueButton(
                  onTap: () async {
                    // Mark onboarding as completed - this will trigger the callback
                    // that switches the app to main app mode
                    await OnboardingService.markOnboardingCompleted();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Summary item widget
class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF6060FF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF9090FF),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Back Button Widget
class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 22,
        ),
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
            'Get Started',
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




