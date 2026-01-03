import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/auth_state_provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'SkipEmergencyUnlockScreen.dart';

/// Custom route that disables swipe back gesture on iOS
class _NoSwipeBackRoute<T> extends MaterialPageRoute<T> {
  _NoSwipeBackRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(builder: builder, settings: settings);

  @override
  bool get hasScopedWillPopCallback => true;

  @override
  bool get canPop => false;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // Disable the default iOS swipe back transition
    return child;
  }
}

/// Skip Flow: Push-Up Success Screen
///
/// Simplified version for users who skip onboarding
/// Shows success message after completing push-up test
class SkipPushUpSuccessScreen extends StatelessWidget {
  final List<String> blockedApps;
  final String selectedWorkout;

  const SkipPushUpSuccessScreen({
    super.key,
    required this.blockedApps,
    required this.selectedWorkout,
  });

  @override
  Widget build(BuildContext context) {
    // Capture widget properties for use in callbacks
    final blockedApps = this.blockedApps;
    final selectedWorkout = this.selectedWorkout;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // Success Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Large Checkmark with Glow
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF10B981), // success green
                            Color(0xFF059669), // darker green
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Success Headline
                    const Text(
                      'Great Job!',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -1.2,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Supporting Text
                    Text(
                      'Look at you!',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Action Button
              Padding(
                padding: const EdgeInsets.all(32),
                child: _ContinueButton(
                  onTap: () {
                    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
                    authProvider.advanceGuestSetupStep();

                    // Navigate to the next screen in the guest flow (disable swipe back)
                    Navigator.push(
                      context,
                      _NoSwipeBackRoute(
                        builder: (context) => SkipEmergencyUnlockScreen(
                          blockedApps: blockedApps,
                          selectedWorkout: selectedWorkout,
                          unlockDuration: 15, // Default 15 minutes
                        ),
                      ),
                    );
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








