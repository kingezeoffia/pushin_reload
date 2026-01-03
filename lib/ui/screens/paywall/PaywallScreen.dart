import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/StripeCheckoutService.dart';
import '../../../state/auth_state_provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../widgets/GOStepsBackground.dart';
import '../auth/SignUpScreen.dart';

/// Paywall Screen - Free Trial with Pro or Advanced plan
///
/// BMAD V6 Spec:
/// - 3-Day Free Trial (Monthly) / 5-Day Free Trial (Yearly)
/// - Pro — 9.99 €: 3 App Blockages, 3 Workouts
/// - Advanced — 14.99 €: Unlimited App Blockages, Unlimited Workouts
/// - GO Steps style design
class PaywallScreen extends StatefulWidget {
  final Map<String, dynamic>? onboardingData;

  const PaywallScreen({
    super.key,
    this.onboardingData,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  String _selectedPlan = 'pro'; // 'pro' or 'advanced'
  String _billingPeriod = 'monthly'; // 'monthly' or 'yearly'
  bool _isLoading = false;

  void _onBillingPeriodChanged(String newPeriod) {
    if (newPeriod == _billingPeriod) return;
    HapticFeedback.mediumImpact();
    setState(() => _billingPeriod = newPeriod);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          GOStepsBackground(
            blackRatio: 0.18,
            child: SafeArea(
              child: Column(
                children: [
                  // Header with Billing Toggle
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 16, top: 8),
                    child: SizedBox(
                      height: 44, // Fixed height to prevent overflow
                      child: Stack(
                        children: [
                          // Left side: Back button
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: _BackButton(
                                  onTap: () => Navigator.pop(context)),
                            ),
                          ),

                          // Center: Billing toggle (perfectly centered)
                          Center(
                            child: _BillingPeriodToggle(
                              selectedPeriod: _billingPeriod,
                              onPeriodChanged: _onBillingPeriodChanged,
                            ),
                          ),

                          // Right side: Restore button
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: TextButton(
                                onPressed: _showRestorePurchasesDialog,
                                child: Text(
                                  'Restore',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: screenHeight * 0.02),

                          // Heading
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  'Start Your',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.1,
                                    letterSpacing: -1,
                                  ),
                                ),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    colors: [
                                      Color(0xFF6060FF),
                                      Color(0xFF9090FF)
                                    ],
                                  ).createShader(
                                    Rect.fromLTWH(0, 0, bounds.width,
                                        bounds.height * 1.3),
                                  ),
                                  blendMode: BlendMode.srcIn,
                                  child: const Text(
                                    "PUSHIN' Journey",
                                    style: TextStyle(
                                      fontSize: 36,
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

                          SizedBox(height: screenHeight * 0.03),

                          // Trial Badge - Perfectly centered
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color:
                                      const Color(0xFF10B981).withOpacity(0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.celebration,
                                    color: Color(0xFF10B981),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _billingPeriod == 'yearly'
                                        ? '5-Day Free Trial'
                                        : '3-Day Free Trial',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: screenHeight * 0.03),

                          // Plan Cards
                          _PlanCard(
                            planName: 'Pro',
                            monthlyPrice: '9.99 €',
                            yearlyPrice: '49.99 €',
                            isYearly: _billingPeriod == 'yearly',
                            features: const [
                              '3 App Blockages',
                              '3 Workouts',
                              'Basic Progress Tracking',
                            ],
                            isSelected: _selectedPlan == 'pro',
                            isPopular: true,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedPlan = 'pro');
                            },
                          ),

                          const SizedBox(height: 16),

                          _PlanCard(
                            planName: 'Advanced',
                            monthlyPrice: '14.99 €',
                            yearlyPrice: '79.99 €',
                            isYearly: _billingPeriod == 'yearly',
                            features: const [
                              'Unlimited App Blockages',
                              'Unlimited Workouts',
                              'Advanced Analytics',
                              'Water intake tracking',
                            ],
                            isSelected: _selectedPlan == 'advanced',
                            isPopular: false,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedPlan = 'advanced');
                            },
                          ),

                          const SizedBox(height: 24),

                          // What You Get
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Color(0xFF9090FF),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'How the trial works',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _TrialStep(
                                  step: '1',
                                  text: _billingPeriod == 'yearly'
                                      ? 'Start your free 5-day trial today'
                                      : 'Start your free 3-day trial today',
                                ),
                                const SizedBox(height: 8),
                                _TrialStep(
                                  step: '2',
                                  text: "Get a reminder before the trial ends",
                                ),
                                const SizedBox(height: 8),
                                _TrialStep(
                                  step: '3',
                                  text: 'Cancel anytime before trial ends',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 100), // Space for fixed button
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Fixed Bottom CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 32,
                right: 32,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.95),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StartTrialButton(
                    isLoading: _isLoading,
                    planName: _selectedPlan == 'pro' ? 'Pro' : 'Advanced',
                    onTap: () => _handleSubscribe(context),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _skipTrial,
                    child: FutureBuilder<String>(
                      future: _getCurrentPlanDisplayName(),
                      builder: (context, snapshot) {
                        final displayText = snapshot.data ?? 'Free Plan';
                        return Text(
                          'Continue with $displayText',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cancel anytime. Terms apply.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Payment success overlay
          ValueListenableBuilder<SubscriptionStatus?>(
            valueListenable:
                context.watch<PushinAppController>().paymentSuccessState,
            builder: (context, paymentStatus, _) {
              if (paymentStatus != null) {
                return _PaymentSuccessOverlay(
                    subscriptionStatus: paymentStatus);
              }
              return const SizedBox.shrink();
            },
          ),

          // Payment cancel notification
          ValueListenableBuilder<bool>(
            valueListenable:
                context.watch<PushinAppController>().paymentCancelState,
            builder: (context, showCancel, _) {
              if (showCancel) {
                return _PaymentCancelOverlay();
              }
              return const SizedBox.shrink();
            },
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6060FF),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _skipTrial() async {
    final authProvider = context.read<AuthStateProvider>();

    // Check if user is logged in
    if (!authProvider.isAuthenticated) {
      // NOT logged in → Navigate to SignUp screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const SignUpScreen(),
          ),
        );
      }
    } else {
      // Logged in → Complete onboarding and go to home (original behavior)
      await authProvider.completeOnboardingFlow();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<String> _getCurrentPlanDisplayName() async {
    try {
      // Get current user
      final authProvider = context.read<AuthStateProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser != null) {
        // Check subscription status using Stripe service
        final stripeService = StripeCheckoutService(
          baseUrl: 'https://pushin-production.up.railway.app/api',
          isTestMode: true,
        );

        final subscriptionStatus = await stripeService.checkSubscriptionStatus(
          userId: currentUser.id,
        );

        if (subscriptionStatus != null && subscriptionStatus.isActive) {
          switch (subscriptionStatus.planId) {
            case 'pro':
              return 'Pro Plan';
            case 'advanced':
              return 'Advanced Plan';
            case 'free':
            default:
              return 'Free Plan';
          }
        }
      }

      // Default to Free Plan if no user or no active subscription
      return 'Free Plan';
    } catch (e) {
      print('Error checking subscription status: $e');
      // Default to Free Plan on error
      return 'Free Plan';
    }
  }

  void _handleSubscribe(BuildContext context) async {
    print('🔴🔴🔴 _handleSubscribe CALLED! 🔴🔴🔴');

    setState(() => _isLoading = true);

    try {
      print('🟡 Creating StripeCheckoutService...');
      final stripeService = StripeCheckoutService(
        baseUrl: 'https://pushin-production.up.railway.app/api',
        isTestMode: true,
      );

      // Get current user info (fallback to test values if not authenticated)
      final authProvider = context.read<AuthStateProvider>();
      final currentUser = authProvider.currentUser;
      final userId = currentUser?.id.toString() ?? 'test_user_123';
      final userEmail = currentUser?.email ?? 'test@example.com';

      print('🛒 PaywallScreen: Starting checkout');
      print('   - userId: $userId');
      print('   - userEmail: $userEmail');
      print('   - planId: $_selectedPlan');
      print('   - billingPeriod: $_billingPeriod');
      print('   - isAuthenticated: ${authProvider.isAuthenticated}');
      print('   - isGuestMode: ${authProvider.isGuestMode}');

      // Launch checkout with plan ID ('pro' or 'advanced') and billing period ('monthly' or 'yearly')
      final backendPlanId = _selectedPlan; // 'pro' or 'advanced'

      final success = await stripeService.launchCheckout(
        userId: userId,
        planId: backendPlanId, // 'pro' or 'advanced'
        billingPeriod: _billingPeriod, // 'monthly' or 'yearly'
        userEmail: userEmail,
      );

      if (!context.mounted) return;

      if (!success) {
        _showErrorDialog('Unable to start checkout. Please try again.');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showErrorDialog('An error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Color(0xFFFF6060),
              ),
              const SizedBox(height: 16),
              const Text(
                'Something Went Wrong',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Center(
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A2A6A),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRestorePurchasesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E1E45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.refresh,
                size: 56,
                color: Color(0xFF6060FF),
              ),
              const SizedBox(height: 16),
              const Text(
                'Restore Purchases',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Checking for previous purchases...',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Center(
                    child: Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A2A6A),
                      ),
                    ),
                  ),
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

/// Plan Card Widget with smooth animated price transition
class _PlanCard extends StatefulWidget {
  final String planName;
  final String monthlyPrice;
  final String yearlyPrice;
  final bool isYearly;
  final List<String> features;
  final bool isSelected;
  final bool isPopular;
  final VoidCallback onTap;

  const _PlanCard({
    required this.planName,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.isYearly,
    required this.features,
    required this.isSelected,
    required this.isPopular,
    required this.onTap,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeOutAnimation;
  late Animation<double> _fadeInAnimation;

  bool _showYearly = false;

  @override
  void initState() {
    super.initState();
    _showYearly = widget.isYearly;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void didUpdateWidget(_PlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isYearly != widget.isYearly) {
      _controller.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() => _showYearly = widget.isYearly);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPrice = _showYearly ? widget.yearlyPrice : widget.monthlyPrice;
    final targetPrice =
        widget.isYearly ? widget.yearlyPrice : widget.monthlyPrice;
    final currentPeriod = _showYearly ? '/year' : '/month';
    final targetPeriod = widget.isYearly ? '/year' : '/month';

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              widget.isSelected ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isSelected
                ? Colors.transparent
                : Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Name & Price Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plan name with badges
                      Row(
                        children: [
                          Text(
                            widget.planName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: widget.isSelected
                                  ? const Color(0xFF2A2A6A)
                                  : Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (widget.isPopular) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                'POPULAR',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          // Animated savings badge - smooth transition both ways
                          AnimatedScale(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            scale: widget.isYearly ? 1.0 : 0.0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              opacity: widget.isYearly ? 1.0 : 0.0,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: const Text(
                                    '-60%',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Animated price display
                      SizedBox(
                        height: 36,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            final isAnimating = _controller.isAnimating;
                            final slideOffset = _slideAnimation.value;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Outgoing price (current)
                                if (isAnimating)
                                  Opacity(
                                    opacity: _fadeOutAnimation.value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        widget.isYearly
                                            ? -30 * slideOffset
                                            : 30 * slideOffset,
                                        0,
                                      ),
                                      child: _buildPriceRow(
                                          currentPrice, currentPeriod),
                                    ),
                                  ),
                                // Incoming price (target)
                                if (isAnimating)
                                  Opacity(
                                    opacity: _fadeInAnimation.value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        widget.isYearly
                                            ? 30 * (1 - slideOffset)
                                            : -30 * (1 - slideOffset),
                                        0,
                                      ),
                                      child: _buildPriceRow(
                                          targetPrice, targetPeriod),
                                    ),
                                  ),
                                // Static price when not animating
                                if (!isAnimating)
                                  _buildPriceRow(currentPrice, currentPeriod),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? const Color(0xFF3535A0)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.isSelected
                          ? const Color(0xFF3535A0)
                          : Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: widget.isSelected
                        ? const Icon(
                            Icons.check,
                            key: ValueKey('check'),
                            color: Colors.white,
                            size: 18,
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Features
            ...widget.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: widget.isSelected
                          ? const Color(0xFF10B981)
                          : const Color(0xFF10B981).withOpacity(0.8),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      feature,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.isSelected
                            ? const Color(0xFF2A2A6A).withOpacity(0.8)
                            : Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String price, String period) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          price,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: widget.isSelected ? const Color(0xFF3535A0) : Colors.white,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          period,
          style: TextStyle(
            fontSize: 14,
            color: widget.isSelected
                ? const Color(0xFF3535A0).withOpacity(0.7)
                : Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}

/// Trial step widget
class _TrialStep extends StatelessWidget {
  final String step;
  final String text;

  const _TrialStep({
    required this.step,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF6060FF).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9090FF),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}

/// Start Trial Button
class _StartTrialButton extends StatelessWidget {
  final bool isLoading;
  final String planName;
  final VoidCallback onTap;

  const _StartTrialButton({
    required this.isLoading,
    required this.planName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
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
            'Start Free Trial — $planName',
            style: const TextStyle(
              fontSize: 17,
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

/// Payment success overlay
class _PaymentSuccessOverlay extends StatelessWidget {
  final SubscriptionStatus subscriptionStatus;

  const _PaymentSuccessOverlay({
    required this.subscriptionStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF10B981).withOpacity(0.98),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Welcome to PUSHIN\'!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your ${subscriptionStatus.displayName} is now active.',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                GestureDetector(
                  onTap: () async {
                    context
                        .read<PushinAppController>()
                        .paymentSuccessState
                        .value = null;

                    // Complete onboarding flow before transitioning to main app (BMAD v6 canonical method)
                    await context
                        .read<AuthStateProvider>()
                        .completeOnboardingFlow();
                    // Pop the paywall screen to let AppRouter handle navigation
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Center(
                      child: Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Billing Period Toggle Widget - Clean, smooth sliding toggle
class _BillingPeriodToggle extends StatelessWidget {
  final String selectedPeriod;
  final Function(String) onPeriodChanged;

  const _BillingPeriodToggle({
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  static const double _toggleWidth = 180.0;
  static const double _toggleHeight = 40.0;
  static const double _indicatorPadding = 3.0;

  @override
  Widget build(BuildContext context) {
    final isYearly = selectedPeriod == 'yearly';

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 100) {
          onPeriodChanged('yearly');
        } else if (velocity < -100) {
          onPeriodChanged('monthly');
        }
      },
      child: Container(
        width: _toggleWidth,
        height: _toggleHeight,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(_toggleHeight / 2),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Animated sliding indicator
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: isYearly
                  ? _toggleWidth / 2 - _indicatorPadding
                  : _indicatorPadding,
              top: _indicatorPadding,
              bottom: _indicatorPadding,
              width: _toggleWidth / 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(
                      (_toggleHeight - _indicatorPadding * 2) / 2),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
            ),

            // Labels
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onPeriodChanged('monthly'),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              !isYearly ? FontWeight.w700 : FontWeight.w500,
                          color:
                              Colors.white.withOpacity(!isYearly ? 1.0 : 0.5),
                          letterSpacing: -0.2,
                        ),
                        child: const Text('Monthly'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onPeriodChanged('yearly'),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isYearly ? FontWeight.w700 : FontWeight.w500,
                          color: Colors.white.withOpacity(isYearly ? 1.0 : 0.5),
                          letterSpacing: -0.2,
                        ),
                        child: const Text('Yearly'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment cancel overlay
class _PaymentCancelOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFBBF24).withOpacity(0.98),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Payment Canceled',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No charges were made to your card.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                GestureDetector(
                  onTap: () {
                    context
                        .read<PushinAppController>()
                        .paymentCancelState
                        .value = false;
                  },
                  child: Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Center(
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
