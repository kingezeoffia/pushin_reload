import 'package:flutter/material.dart';
import '../../widgets/GOStepsBackground.dart';

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

  String get _planName {
    if (widget.previousPlan == 'pro') return 'Pro';
    if (widget.previousPlan == 'advanced') return 'Advanced';
    return 'Premium';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GOStepsBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

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
                      'Thank you for your support!',
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
                      'You successfully cancelled your $_planName subscription.\nYou\'ve been moved to the Free plan.',
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
                            _buildFeatureItem('3 workout options'),
                          ],
                          const SizedBox(height: 12),
                          _buildFeatureItem('Emergency unlock'),
                        ],
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onContinue?.call();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF2A2A6A),
                          elevation: 8,
                          shadowColor: Colors.black.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Continue with Free Plan',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Resubscribe link
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // User will be back on paywall screen where they can resubscribe
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Changed your mind? Resubscribe',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
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
