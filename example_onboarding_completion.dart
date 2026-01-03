/// Example: How to handle onboarding completion in UI buttons
/// This shows the proper pattern for state-driven navigation

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/state/auth_state_provider.dart';

/// Example button handler for completing onboarding
/// This should be used in onboarding completion buttons/screens
class OnboardingCompleteButton extends StatelessWidget {
  const OnboardingCompleteButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        // Mark onboarding as completed via Provider
        // This updates state AND persists to SharedPreferences
        await Provider.of<AuthStateProvider>(context, listen: false)
            .markOnboardingCompleted();

        // Navigation will happen automatically due to state change
        // No Navigator.push/pop needed - AppRouter will rebuild and show main app
      },
      child: const Text('Complete Onboarding'),
    );
  }
}

/// Example of how onboarding completion is stored and reloaded:
///
/// 1. STORAGE (via OnboardingService.markOnboardingCompleted()):
///    - Uses SharedPreferences with key 'onboarding_completed'
///    - Stores boolean value: true when completed
///    - Persists across app restarts and login sessions
///
/// 2. LOADING (via AuthStateProvider.loadOnboardingStatus()):
///    - Called during AuthStateProvider.initialize()
///    - Reads from SharedPreferences on app start
///    - Sets _isOnboardingCompleted flag
///
/// 3. USAGE IN ROUTING:
///    - AppRouter checks authProvider.isOnboardingCompleted
///    - If true: shows HomeScreen (main app)
///    - If false: shows onboarding screens
///
/// 4. RESETTING (for development/testing):
///    - Call OnboardingService.resetOnboarding() to clear stored value
///    - This allows testing onboarding flow again
