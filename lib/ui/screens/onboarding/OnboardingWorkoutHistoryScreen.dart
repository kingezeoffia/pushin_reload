import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/SelectionButton.dart';
import 'HowItWorksBlockAppsScreen.dart';

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

/// Screen 4: Workout History
///
/// BMAD V6 Spec:
/// - Question: How long have you been working out?
/// - Options: Just starting, Few months, 1 year, Since forever
class OnboardingWorkoutHistoryScreen extends StatefulWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;

  const OnboardingWorkoutHistoryScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
  });

  @override
  State<OnboardingWorkoutHistoryScreen> createState() =>
      _OnboardingWorkoutHistoryScreenState();
}

class _OnboardingWorkoutHistoryScreenState
    extends State<OnboardingWorkoutHistoryScreen> {
  String? _selectedHistory;

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

              // Consistent spacing with other screens
              SizedBox(height: screenHeight * 0.08),

              // Heading - consistent positioning
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Workout history calendar icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6060FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 40,
                        color: Color(0xFF9090FF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'How long have',
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
                        'you trained?',
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

              // History Options - 2x2 grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SelectionButton(
                            label: 'Just starting',
                            isSelected: _selectedHistory == 'just_starting',
                            onTap: () => setState(
                                () => _selectedHistory = 'just_starting'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SelectionButton(
                            label: '3-6 months',
                            isSelected: _selectedHistory == '3_6_months',
                            onTap: () =>
                                setState(() => _selectedHistory = '3_6_months'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SelectionButton(
                            label: '6-12 months',
                            isSelected: _selectedHistory == '6_12_months',
                            onTap: () => setState(
                                () => _selectedHistory = '6_12_months'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SelectionButton(
                            label: '1+ years',
                            isSelected: _selectedHistory == '1_plus_years',
                            onTap: () => setState(
                                () => _selectedHistory = '1_plus_years'),
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
                  enabled: _selectedHistory != null,
                  onTap: () {
                    if (_selectedHistory != null) {
                      Navigator.push(
                        context,
                        _NoSwipeBackRoute(
                          builder: (context) => HowItWorksBlockAppsScreen(
                            fitnessLevel: widget.fitnessLevel,
                            goals: widget.goals,
                            otherGoal: widget.otherGoal,
                            workoutHistory: _selectedHistory!,
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
