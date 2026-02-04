import 'package:flutter/material.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';
import '../../../services/PaymentService.dart';
import '../../../state/auth_state_provider.dart';
import 'package:provider/provider.dart';

/// Screen shown when user cancels their subscription
class SubscriptionCancelledScreen extends StatefulWidget {
  final String? previousPlan; // 'pro' or 'advanced'
  final VoidCallback? onContinue;

  const SubscriptionCancelledScreen({
    super.key,
    this.previousPlan,
    this.onContinue,
  });

  @override
  State<SubscriptionCancelledScreen> createState() =>
      _SubscriptionCancelledScreenState();
}

class _SubscriptionCancelledScreenState
    extends State<SubscriptionCancelledScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleResubscribe() async {
    try {
      final authProvider = context.read<AuthStateProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to manage your subscription.'),
            ),
          );
        }
        return;
      }

      final paymentService = PaymentConfig.createService();

      final success = await paymentService.openCustomerPortal(
        userId: currentUser.id.toString(),
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Unable to open subscription management. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: GOStepsBackground(
        blackRatio: 0.25,
        child: SafeArea(
          child: Stack(
            children: [
              // Scrollable content area
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Top spacing
                        SizedBox(height: screenHeight * 0.1),

                        // Sad emoji
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '👋',
                              style: TextStyle(fontSize: 64),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Heading
                        const Text(
                          'Thanks for Everything!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                            height: 1.1,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Subtitle
                        Text(
                          'You\'ve been moved to the Free plan.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 48),

                        // What you'll miss box
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What you\'ll miss:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.7),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureItem('Unlimited app blocking'),
                              const SizedBox(height: 12),
                              _buildFeatureItem('Unlimited blockages'),
                              if (widget.previousPlan == 'advanced') ...[
                                const SizedBox(height: 12),
                                _buildFeatureItem('Unlimited workouts'),
                                const SizedBox(height: 12),
                                _buildFeatureItem('Steps & kcal counter'),
                              ] else ...[
                                const SizedBox(height: 12),
                                _buildFeatureItem('3 Workouts'),
                              ],
                              const SizedBox(height: 12),
                              _buildFeatureItem('Emergency Unlock'),
                            ],
                          ),
                        ),

                        // Add spacing at bottom to prevent content from being hidden by buttons
                        const SizedBox(height: 200),
                      ],
                    ),
                  ),
                ),
              ),

              // Fixed bottom buttons - Continue with Free Plan and Resubscribe
              BottomActionContainer(
                child: Column(
                  children: [
                    // Continue with Free Plan Button (Primary)
                    _PrimaryButton(
                      label: 'Continue with Free Plan',
                      onTap: () {
                        widget.onContinue?.call();
                        Navigator.of(context).pop();
                      },
                    ),

                    const SizedBox(height: 16),

                    // Resubscribe Button (Secondary)
                    _SecondaryButton(
                      label: 'Resubscribe',
                      onTap: _handleResubscribe,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        Icon(
          Icons.close_rounded,
          size: 20,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Primary action button with press animation
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
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
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
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

/// Secondary button for resubscribe
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
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
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }
}
