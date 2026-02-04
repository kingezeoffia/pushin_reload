import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';
import '../../navigation/main_tab_navigation.dart';
import '../../../state/auth_state_provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../../services/PaymentService.dart';

/// Subscription Success Screen - Welcome screen shown after successful payment
///
/// BMAD V6 Spec:
/// - Same visual system as onboarding screens (GOStepsBackground, consistent styling)
/// - Clean, premium, minimal design
/// - Shows subscription details (plan name, features)
/// - Continue button navigates to main app via state-driven routing
class SubscriptionSuccessScreen extends StatelessWidget {
  final SubscriptionStatus subscriptionStatus;

  const SubscriptionSuccessScreen({
    super.key,
    required this.subscriptionStatus,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    print('🎉 SubscriptionSuccessScreen: Building screen');
    print('   - Plan: ${subscriptionStatus.planId}');
    print('   - Display name: ${subscriptionStatus.displayName}');

    // Determine if Pro or Advanced plan
    final isPro = subscriptionStatus.planId == 'pro';
    final planName = isPro ? 'PRO' : 'ADVANCED';

    // Get features based on plan
    final features = isPro ? _proFeatures : _advancedFeatures;

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
                  SizedBox(height: screenHeight * 0.08),

                  // Heading - consistent positioning
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Success icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: (isPro
                                    ? const Color(0xFF60A5FA)
                                    : const Color(0xFFFBBF24))
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.celebration_rounded,
                            size: 40,
                            color: isPro
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "You're now",
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isPro
                                ? [
                                    const Color(0xFF60A5FA),
                                    const Color(0xFF93C5FD)
                                  ]
                                : [
                                    const Color(0xFFFBBF24),
                                    const Color(0xFFFCD34D)
                                  ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            planName,
                            style: const TextStyle(
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
                          'Your subscription is now active',
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

                  // Features list
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: features
                            .map((feature) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _FeatureItem(
                                    icon: feature.icon,
                                    title: feature.title,
                                    isPro: isPro,
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),

                  // Spacer for button area
                  const SizedBox(height: 100),
                ],
              ),
            ),

            // Continue Button - positioned at navigation pill level
            BottomActionContainer(
              child: _ContinueButton(
                onTap: () => _handleContinue(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleContinue(BuildContext context) async {
    HapticFeedback.mediumImpact();

    print('🎯 SubscriptionSuccessScreen: Continue button tapped');

    // Clear the payment success state so this screen doesn't show again
    context.read<PushinAppController>().paymentSuccessState.value = null;
    print('🧹 SubscriptionSuccessScreen: Cleared paymentSuccessState');

    // Complete onboarding flow (BMAD v6 canonical method)
    await context.read<AuthStateProvider>().completeOnboardingFlow();

    // Check if context is still mounted
    if (!context.mounted) return;

    print('🎯 SubscriptionSuccessScreen: Navigating to main app');

    // Navigate to main app, replacing the entire stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainTabNavigation(),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  // Pro plan features
  static const List<_Feature> _proFeatures = [
    _Feature(
      icon: Icons.all_inclusive,
      title: 'Unlimited Hours of App Blocking',
    ),
    _Feature(
      icon: Icons.block,
      title: 'Unlimited App Blockages',
    ),
    _Feature(
      icon: Icons.fitness_center,
      title: '3 Workout Types',
    ),
    _Feature(
      icon: Icons.trending_up,
      title: 'Basic Progress Tracking',
    ),
    _Feature(
      icon: Icons.emergency,
      title: 'Emergency Unlock',
    ),
  ];

  // Advanced plan features
  static const List<_Feature> _advancedFeatures = [
    _Feature(
      icon: Icons.all_inclusive,
      title: 'Unlimited Hours of App Blocking',
    ),
    _Feature(
      icon: Icons.block,
      title: 'Unlimited App Blockages',
    ),
    _Feature(
      icon: Icons.fitness_center,
      title: 'Unlimited Workouts',
    ),
    _Feature(
      icon: Icons.analytics,
      title: 'Advanced Analytics',
    ),
    _Feature(
      icon: Icons.water_drop,
      title: 'Water Intake Tracking',
    ),
    _Feature(
      icon: Icons.directions_walk,
      title: 'Steps and kcal Counter',
    ),
    _Feature(
      icon: Icons.emergency,
      title: 'Emergency Unlock',
    ),
  ];
}

/// Feature data class
class _Feature {
  final IconData icon;
  final String title;

  const _Feature({
    required this.icon,
    required this.title,
  });
}

/// Feature item widget - matches onboarding style
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isPro;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.isPro,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = isPro
        ? const Color(0xFF60A5FA) // Blue for Pro
        : const Color(0xFFFBBF24); // Gold/Amber for Advanced

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
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: -0.1,
              ),
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
            "Let's Go!",
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
