import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/SelectionButton.dart';
import 'OnboardingGoalsScreen.dart';

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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: _BackButton(onTap: () => Navigator.pop(context)),
              ),

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
                        color: const Color(0xFF6060FF).withValues(alpha: 0.2),
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
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
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

              const Spacer(),

              // Next Button
              Padding(
                padding: const EdgeInsets.all(32),
                child: _NextButton(
                  enabled: _selectedLevel != null,
                  onTap: () {
                    if (_selectedLevel != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OnboardingGoalsScreen(
                            fitnessLevel: _selectedLevel!,
                          ),
                        ),
                      );
                    }
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
          color: Colors.white.withValues(alpha: 0.1),
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
