import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/SelectionButton.dart';
import 'OnboardingWorkoutHistoryScreen.dart';

/// Screen 3: What Are Your Goals
///
/// BMAD V6 Spec:
/// - Options: Lose weight, Build muscle, Reduce screen time, Others
/// - "Others" is tap-only selection (no text input - minimal friction)
/// - Multiple selection allowed
class OnboardingGoalsScreen extends StatefulWidget {
  final String fitnessLevel;

  const OnboardingGoalsScreen({
    super.key,
    required this.fitnessLevel,
  });

  @override
  State<OnboardingGoalsScreen> createState() => _OnboardingGoalsScreenState();
}

class _OnboardingGoalsScreenState extends State<OnboardingGoalsScreen> {
  final Set<String> _selectedGoals = {};

  void _toggleGoal(String goal) {
    setState(() {
      if (_selectedGoals.contains(goal)) {
        _selectedGoals.remove(goal);
      } else {
        _selectedGoals.add(goal);
        // Only provide haptic feedback when selecting (not deselecting)
        HapticFeedback.lightImpact();
      }
    });
  }

  bool get _canProceed => _selectedGoals.isNotEmpty;

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

              SizedBox(height: screenHeight * 0.08),

              // Heading - consistent with other screens
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Goals target icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6060FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.adjust_rounded,
                        size: 40,
                        color: Color(0xFF9090FF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'What are',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -1,
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
                      child: Text(
                        'your goals?',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                          decoration: TextDecoration.none,
                          fontFamily: 'Inter', // Explicit font family
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.06),

              // Goal Options - 2x2 grid, tap only
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    // Row 1
                    Row(
                      children: [
                        Expanded(
                          child: SelectionButton(
                            label: 'Lose weight',
                            isSelected: _selectedGoals.contains('lose_weight'),
                            onTap: () => _toggleGoal('lose_weight'),
                            provideHapticFeedback: false,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SelectionButton(
                            label: 'Build muscle',
                            isSelected: _selectedGoals.contains('build_muscle'),
                            onTap: () => _toggleGoal('build_muscle'),
                            provideHapticFeedback: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Row 2
                    Row(
                      children: [
                        Expanded(
                          child: SelectionButton(
                            label: 'Less screen time',
                            isSelected:
                                _selectedGoals.contains('reduce_screen_time'),
                            onTap: () => _toggleGoal('reduce_screen_time'),
                            provideHapticFeedback: false,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SelectionButton(
                            label: 'Others',
                            isSelected: _selectedGoals.contains('others'),
                            onTap: () => _toggleGoal('others'),
                            provideHapticFeedback: false,
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
                  enabled: _canProceed,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OnboardingWorkoutHistoryScreen(
                          fitnessLevel: widget.fitnessLevel,
                          goals: _selectedGoals.toList(),
                          otherGoal: '', // No text input needed
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
              ? Colors.white.withOpacity(0.95)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(100),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
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
                  : Colors.white.withOpacity(0.4),
              letterSpacing: -0.3,
            ),
            child: const Text('Next'),
          ),
        ),
      ),
    );
  }
}
