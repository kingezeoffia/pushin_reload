import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';
import '../../../state/auth_state_provider.dart';

/// New User Welcome Screen - Welcome screen for newly registered users
///
/// BMAD V6 Spec:
/// - Same visual system as onboarding screens (GOStepsBackground, consistent styling)
/// - Clean, premium, minimal design
/// - Continue button handles navigation to onboarding welcome screen
/// - NO navigation logic - routing handled by AppRouter state changes
class NewUserWelcomeScreen extends StatelessWidget {
  final bool isReturningUser;

  const NewUserWelcomeScreen({
    super.key,
    this.isReturningUser = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final authProvider = Provider.of<AuthStateProvider>(context);

    print('🎨 NewUserWelcomeScreen: Building screen');
    print('   - isReturningUser: $isReturningUser');
    print('🧪 NewUserWelcomeScreen - justRegistered=${authProvider.justRegistered}, '
        'isGuestMode=${authProvider.isGuestMode}, '
        'guestCompletedSetup=${authProvider.guestCompletedSetup}');

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
                        // Welcome icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF60A5FA).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.family_restroom_rounded,
                            size: 40,
                            color: Color(0xFF60A5FA),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome to the',
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
                            colors: [Color(0xFF60A5FA), Color(0xFF93C5FD)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'FAMILY',
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
                          "You're now part of something special",
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

                  // Welcome features
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        _RuleItem(
                          icon: Icons.fitness_center,
                          title: 'Smart Workout Tracking',
                          description: 'AI-powered rep counting and form guidance',
                        ),
                        const SizedBox(height: 16),
                        _RuleItem(
                          icon: Icons.block,
                          title: 'App Blocking',
                          description: 'Stay focused with customizable restrictions',
                        ),
                        const SizedBox(height: 16),
                        _RuleItem(
                          icon: Icons.emergency,
                          title: 'Emergency Access',
                          description: 'Three unlocks per day when you need them',
                        ),
                      ],
                    ),
                  ),

                  // Spacer to push content up (button will be positioned at bottom)
                  const Spacer(),
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

  void _handleContinue(BuildContext context) {
    // Handle continue based on user type
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

    print('🎯 NewUserWelcomeScreen: Continue button tapped');
    print('   - isReturningUser: $isReturningUser');
    print('   - current justRegistered flag: ${authProvider.justRegistered}');
    print('   - user email: ${authProvider.currentUser?.email ?? "none"}');

    // This screen should only be shown to new users (isReturningUser = false)
    // The routing logic in AppRouter ensures returning users go directly to onboarding
    print('   → New user: Clearing justRegistered flag to start onboarding flow');
    // For new users, clear the justRegistered flag to proceed directly to onboarding
    authProvider.clearJustRegisteredFlag();
    print('   ✓ Just registered flag cleared - router will show onboarding flow');
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
              color: const Color(0xFF60A5FA).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF60A5FA),
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
