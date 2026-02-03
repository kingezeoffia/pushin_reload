import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../state/auth_state_provider.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/SelectionButton.dart';
import '../../widgets/pill_navigation_bar.dart';

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

/// Screen 2: Current Fitness Level
///
/// BMAD V6 Spec:
/// - Options: Beginner, Moderate, Advanced, Athletic
/// - 2x2 grid layout
/// - Selection button states as specified
class OnboardingFitnessLevelScreen extends StatefulWidget {
  const OnboardingFitnessLevelScreen({super.key});

  @override
  State<OnboardingFitnessLevelScreen> createState() =>
      _OnboardingFitnessLevelScreenState();
}

class _OnboardingFitnessLevelScreenState
    extends State<OnboardingFitnessLevelScreen> {
  String? _selectedLevel;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthStateProvider>(context);
    print(
        '🧪 OnboardingFitnessLevelScreen - justRegistered=${authProvider.justRegistered}, '
        'isGuestMode=${authProvider.isGuestMode}, '
        'guestCompletedSetup=${authProvider.guestCompletedSetup}');

    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor:
          Colors.black, // TEMP: Changed to red to debug white screen issue
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
                        // Athletic sprinting icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF6060FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.directions_run_rounded,
                            size: 40,
                            color: Color(0xFF9090FF),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Current',
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
                            colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            'fitness level?',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.06),

                  // Fitness Level Grid - 2x2
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SelectionButton(
                                label: 'Beginner',
                                isSelected: _selectedLevel == 'beginner',
                                onTap: () =>
                                    setState(() => _selectedLevel = 'beginner'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SelectionButton(
                                label: 'Moderate',
                                isSelected: _selectedLevel == 'moderate',
                                onTap: () =>
                                    setState(() => _selectedLevel = 'moderate'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SelectionButton(
                                label: 'Advanced',
                                isSelected: _selectedLevel == 'advanced',
                                onTap: () =>
                                    setState(() => _selectedLevel = 'advanced'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SelectionButton(
                                label: 'Athletic',
                                isSelected: _selectedLevel == 'athletic',
                                onTap: () =>
                                    setState(() => _selectedLevel = 'athletic'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Spacer to push content up (button will be positioned at bottom)
                  const Spacer(),
                ],
              ),
            ),

            // Next Button - positioned at navigation pill level
            BottomActionContainer(
              child: _NextButton(
                enabled: _selectedLevel != null,
                onTap: () {
                  if (_selectedLevel != null) {
                    final authProvider = context.read<AuthStateProvider>();
                    authProvider.setFitnessLevel(_selectedLevel!);
                    debugPrint('🔄 OnboardingFitnessLevelScreen: Advancing step...');
                    authProvider.advanceOnboardingStep();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back Button Widget

/// Next Button Widget
class _NextButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _NextButton({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressAnimationButton(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? const Color(0xFF2A2A6A)
                  : Colors.white.withValues(alpha: 0.4),
              letterSpacing: -0.3,
            ),
            child: const Text('Next'),
          ),
        ),
      ),
    );
  }
}
