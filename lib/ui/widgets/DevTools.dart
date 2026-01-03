import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../services/OnboardingService.dart';
import '../../state/auth_state_provider.dart';

/// Development tools widget - REMOVE BEFORE PRODUCTION
///
/// Add this temporarily to your HomeScreen during development to reset onboarding
class DevTools extends StatelessWidget {
  const DevTools({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    print('🛠️ DevTools: Showing debug tools in debug mode');
    return Positioned(
      top: 60,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DEV',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                print('🔄 DEV RESET initiated');

                // Complete reset to ensure we always go to WelcomeScreen
                final authProvider = Provider.of<AuthStateProvider>(context, listen: false);

                // 1. Clear all tokens and guest mode completely
                await authProvider.logout(); // This clears user and tokens
                authProvider.exitGuestMode(); // Clear guest mode flag

                // 2. Clear just registered flag
                authProvider.clearJustRegisteredFlag();

                // 3. Reset OnboardingService state (this will trigger the reset callback in AppRouter)
                await OnboardingService.resetOnboarding();

                // 4. Force AuthStateProvider to reinitialize to ensure clean state
                await authProvider.initialize();

                print('✅ DEV RESET complete - AppRouter should show WelcomeScreen');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'RESET',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () async {
                await OnboardingService.devForceShowOnboarding();
                // Show snackbar
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Onboarding forced! You should see onboarding now.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Force',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}