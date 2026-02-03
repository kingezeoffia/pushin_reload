import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/StripeCheckoutService.dart';
import '../../../state/auth_state_provider.dart';
import '../../../state/pushin_app_controller.dart';
import '../../widgets/ErrorPopup.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/RestorePurchasesPopup.dart';
import '../../navigation/main_tab_navigation.dart';
import '../auth/SubscriptionSuccessScreen.dart';
import '../auth/AdvancedUpgradeWelcomeScreen.dart';
import '../auth/SignUpScreen.dart';
import '../subscription/SubscriptionCancelledScreen.dart';

/// Paywall Screen - Free Trial with Pro or Advanced plan
///
/// BMAD V6 Spec:
/// - 3-Day Free Trial (Monthly) / 3-Day Free Trial (Yearly)
/// - Pro — 9.99 €: Unlimited Hours of App Blocking, Unlimited App Blockages, 3 Workouts, Emergency Unlock
/// - Advanced — 14.99 €: Unlimited Hours of App Blocking, Unlimited App Blockages, Unlimited Workouts*, Steps and kcal counter, Emergency Unlock
/// - GO Steps style design
class PaywallScreen extends StatefulWidget {
  final Map<String, dynamic>? onboardingData;
  final String?
      preSelectedPlan; // 'pro', 'advanced', or null for auto-selection

  const PaywallScreen({
    super.key,
    this.onboardingData,
    this.preSelectedPlan,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _proPlanKey = GlobalKey();
  final GlobalKey _advancedPlanKey = GlobalKey();
  String _selectedPlan =
      'pro'; // 'pro' or 'advanced' - will be updated dynamically
  String _billingPeriod = 'monthly'; // 'monthly' or 'yearly'
  bool _isLoading = false;
  bool _isInitializingPlan = true;
  bool _shouldScrollToSelectedPlan =
      false; // Flag to trigger scroll after layout
  String? _currentSubscriptionPlan; // Track user's current active plan
  bool _hasPreSelectedPlan = false; // Track if plan was explicitly pre-selected
  bool _hasUserManuallySelectedPlan =
      false; // Track if user manually selected a plan
  bool _pendingPurchaseAfterAuth =
      false; // Track if user was trying to purchase before auth
  SubscriptionStatus? _currentSubscriptionStatus; // Current subscription details

  // Listen for plan tier changes from PushinAppController
  late VoidCallback _planTierListener;
  late VoidCallback _paymentSuccessListener;
  late VoidCallback _authStateListener;
  late VoidCallback _subscriptionCancelledListener;

  void _onBillingPeriodChanged(String newPeriod) {
    if (newPeriod == _billingPeriod) return;
    HapticFeedback.mediumImpact();
    setState(() => _billingPeriod = newPeriod);
  }

  @override
  void initState() {
    super.initState();
    _initializeSelectedPlan();

    // Refresh subscription status when screen is shown (in case user returns from portal)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshSubscriptionStatus();
      }
    });

    // Listen for plan tier changes from PushinAppController
    // This ensures the paywall updates when subscription status changes after payment
    final pushinController = context.read<PushinAppController>();
    _planTierListener = _onPlanTierChanged;
    pushinController.addListener(_planTierListener);

    // CRITICAL: Listen for payment success to automatically dismiss paywall
    _paymentSuccessListener = _onPaymentSuccess;
    pushinController.paymentSuccessState.addListener(_paymentSuccessListener);
    pushinController.upgradeWelcomeState.addListener(_paymentSuccessListener);

    // Listen for subscription cancellation to show cancellation screen
    _subscriptionCancelledListener = _onSubscriptionCancelled;
    pushinController.subscriptionCancelledPlan
        .addListener(_subscriptionCancelledListener);

    // Listen for auth state changes to reset loading state when user signs in
    final authProvider = context.read<AuthStateProvider>();
    _authStateListener = _onAuthStateChanged;
    authProvider.addListener(_authStateListener);
  }

  /// Called when auth state changes - reset loading state if user just signed in
  void _onAuthStateChanged() {
    final authProvider = context.read<AuthStateProvider>();
    // If user just became authenticated and was trying to purchase, continue with purchase
    if (authProvider.isAuthenticated && _pendingPurchaseAfterAuth && mounted) {
      debugPrint(
          '🎉 User authenticated after pending purchase - continuing purchase flow');
      setState(() {
        _pendingPurchaseAfterAuth = false;
        _isLoading = true;
      });
      // Continue with the purchase flow
      _continuePurchaseAfterAuth();
    }
    // Reset loading state when user becomes authenticated (just signed in)
    else if (authProvider.isAuthenticated && _isLoading && mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Continue purchase flow after user authentication
  Future<void> _continuePurchaseAfterAuth() async {
    debugPrint('🔄 Continuing purchase after authentication...');

    try {
      debugPrint('🟡 Creating StripeCheckoutService...');
      final stripeService = StripeCheckoutService(
        baseUrl: 'https://pushin-production.up.railway.app/api',
        isTestMode: true,
      );

      // Get current user info
      final authProvider = context.read<AuthStateProvider>();
      final currentUser = authProvider.currentUser;
      final isAuthenticated = authProvider.isAuthenticated;

      // At this point user should be authenticated
      if (!isAuthenticated || currentUser == null) {
        debugPrint('❌ User not authenticated after auth flow - aborting');
        setState(() => _isLoading = false);
        return;
      }

      // Generate user info for authenticated user
      String userId = currentUser.id.toString();
      String userEmail = currentUser.email ?? 'user@example.com';

      debugPrint('🛒 Continuing checkout for authenticated user');
      debugPrint('   - userId: $userId');
      debugPrint('   - userEmail: $userEmail');
      debugPrint('   - planId: $_selectedPlan');
      debugPrint('   - billingPeriod: $_billingPeriod');

      // Set the pending checkout userId so DeepLinkHandler can verify the payment
      final pushinController = context.read<PushinAppController>();
      pushinController.setPendingCheckoutUserId(userId);

      // Set the planId for fallback subscription status creation
      await pushinController.setPendingCheckoutPlanId(_selectedPlan);

      final success = await stripeService.launchCheckout(
        userId: userId,
        planId: _selectedPlan,
        billingPeriod: _billingPeriod,
        userEmail: userEmail,
      );

      if (!context.mounted) return;

      if (success) {
        // For real mode, plan tier will be updated via deep link handler
        // For test mode, simulate payment success immediately since no deep link is triggered
        if (stripeService.isTestMode) {
          debugPrint(
              'TEST MODE: Checkout simulated successfully - triggering payment success flow');
          // Simulate payment success by creating a subscription status and triggering the callback
          final simulatedStatus = SubscriptionStatus(
            isActive: true,
            planId: _selectedPlan,
            customerId: 'cus_test_${currentUser.id}',
            subscriptionId:
                'sub_test_${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}',
            currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
            cachedUserId: currentUser.id.toString(),
          );

          // Save the simulated subscription status
          await stripeService.saveSubscriptionStatus(simulatedStatus);

          // Trigger the payment success callback to update UI state
          pushinController.paymentSuccessState.value = simulatedStatus;
          debugPrint(
              'TEST MODE: Payment success state updated, UI should reflect new plan tier');
        }
      } else {
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

  /// Called when payment succeeds - navigate to success screen
  void _onPaymentSuccess() {
    final pushinController = context.read<PushinAppController>();
    final paymentStatus = pushinController.paymentSuccessState.value;
    final hasUpgradeWelcome = pushinController.upgradeWelcomeState.value;

    if ((paymentStatus != null || hasUpgradeWelcome) && mounted) {
      debugPrint('🎉 PaywallScreen: Payment success detected');
      debugPrint('   - hasUpgradeWelcome: $hasUpgradeWelcome');
      debugPrint('   - hasPaymentSuccess: ${paymentStatus != null}');

      // Navigate to the appropriate success screen
      if (hasUpgradeWelcome) {
        debugPrint('🎉 PaywallScreen: Showing AdvancedUpgradeWelcomeScreen');
        // Clear the upgrade welcome state immediately
        final pushinController = context.read<PushinAppController>();
        pushinController.upgradeWelcomeState.value = false;

        // Show upgrade welcome screen for PRO → ADVANCED upgrades
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdvancedUpgradeWelcomeScreen(),
          ),
        );
      } else if (paymentStatus != null) {
        debugPrint(
            '🎉 PaywallScreen: Showing SubscriptionSuccessScreen for ${paymentStatus.planId}');
        // Clear the payment success state immediately
        final pushinController = context.read<PushinAppController>();
        pushinController.paymentSuccessState.value = null;

        // Show regular success screen for new subscriptions
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SubscriptionSuccessScreen(
              subscriptionStatus: paymentStatus,
            ),
          ),
        );
      }
    }
  }

  Future<void> _initializeSelectedPlan() async {
    try {
      // First check cached subscription status to get current plan
      final stripeService = StripeCheckoutService(
        baseUrl: 'https://pushin-production.up.railway.app/api',
        isTestMode: true,
      );

      final cachedStatus = await stripeService.getCachedSubscriptionStatus();
      String? currentPlan;

      if (cachedStatus != null && cachedStatus.isActive) {
        currentPlan = cachedStatus.planId;
        debugPrint(
            '📦 PaywallScreen: Found cached subscription - plan: $currentPlan');
      }

      // If preSelectedPlan is provided, use it directly but still set currentPlan
      if (widget.preSelectedPlan != null) {
        if (mounted) {
          setState(() {
            _currentSubscriptionPlan = currentPlan;
            _selectedPlan = widget.preSelectedPlan!;
            _hasPreSelectedPlan = true; // Mark that this was pre-selected
            _isInitializingPlan = false;
            _shouldScrollToSelectedPlan =
                true; // Set flag to scroll after layout
          });

          debugPrint('📦 PaywallScreen: Pre-selected plan');
          debugPrint('   - Current plan: $_currentSubscriptionPlan');
          debugPrint('   - Selected plan: $_selectedPlan');
        }
        return;
      }

      // Also try to get from backend (but don't block on it)
      final nextBestPlan = await _getNextBestPlan();

      if (mounted) {
        setState(() {
          _currentSubscriptionPlan = currentPlan;
          _currentSubscriptionStatus = cachedStatus;
          _selectedPlan = nextBestPlan;
          _isInitializingPlan = false;
        });

        debugPrint('📦 PaywallScreen: Initialized');
        debugPrint('   - Current plan: $_currentSubscriptionPlan');
        debugPrint('   - Selected plan: $_selectedPlan');
        debugPrint('   - Cancel at period end: ${_currentSubscriptionStatus?.cancelAtPeriodEnd}');
      }
    } catch (e) {
      debugPrint('Error initializing selected plan: $e');
      // Default to 'pro' on error
      if (mounted) {
        setState(() {
          _selectedPlan = 'pro';
          _isInitializingPlan = false;
        });
      }
    }
  }

  /// Called when subscription is cancelled - navigate to cancellation screen
  void _onSubscriptionCancelled() {
    final pushinController = context.read<PushinAppController>();
    final cancelledPlan = pushinController.subscriptionCancelledPlan.value;

    if (cancelledPlan != null && mounted) {
      debugPrint('😢 PaywallScreen: Subscription cancellation detected');
      debugPrint('   - Cancelled plan: $cancelledPlan');

      // Clear the state immediately
      pushinController.clearSubscriptionCancelled();

      // Navigate to cancellation screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SubscriptionCancelledScreen(
            previousPlan: cancelledPlan,
            onContinue: () {
              // Refresh subscription status when user continues
              _refreshSubscriptionStatus();
            },
          ),
        ),
      );
    }
  }

  /// Called when the plan tier changes in PushinAppController
  /// This ensures the paywall updates immediately after successful payment
  void _onPlanTierChanged() {
    final pushinController = context.read<PushinAppController>();
    final newPlanTier = pushinController.planTier;

    // Only update if the plan tier actually changed from what we know
    if (_currentSubscriptionPlan != newPlanTier && mounted) {
      debugPrint(
          '🔄 Paywall: Plan tier changed from $_currentSubscriptionPlan to $newPlanTier');

      // If a plan was pre-selected (e.g., from dashboard) or manually selected by user,
      // only override it if the user's subscription actually upgraded (not just initialized)
      if (_hasPreSelectedPlan || _hasUserManuallySelectedPlan) {
        // Only refresh if the user actually became a paid subscriber
        // Don't override pre-selected or manually selected plans with "next best plan" logic
        final wasFree = _currentSubscriptionPlan == null ||
            _currentSubscriptionPlan == 'free';

        if (wasFree && newPlanTier != 'free') {
          // User became a paid subscriber - refresh to show current plan
          _refreshSubscriptionStatus();
        }
        // If user was already paid or still free, keep the selected plan
      } else {
        // No pre-selected or manual plan - normal refresh behavior
        _refreshSubscriptionStatus();
      }
    }
  }

  /// Refresh the subscription status and update UI accordingly
  Future<void> _refreshSubscriptionStatus() async {
    if (!mounted) return;

    try {
      debugPrint('🔄 Paywall: Refreshing subscription status from server...');

      // Re-check subscription status from server (not just cache)
      final stripeService = StripeCheckoutService(
        baseUrl: 'https://pushin-production.up.railway.app/api',
        isTestMode: true,
      );

      final authProvider = context.read<AuthStateProvider>();
      final currentUser = authProvider.currentUser;

      SubscriptionStatus? freshStatus;

      if (currentUser != null) {
        // Fetch fresh status from server
        freshStatus = await stripeService.checkSubscriptionStatus(
          userId: currentUser.id.toString(),
        );
      } else {
        // Fall back to cached for unauthenticated
        freshStatus = await stripeService.getCachedSubscriptionStatus();
      }

      String? updatedPlan;

      if (freshStatus != null && freshStatus.isActive) {
        updatedPlan = freshStatus.planId;
        debugPrint('🔄 Paywall: Refreshed subscription status');
        debugPrint('   - Plan: $updatedPlan');
        debugPrint('   - cancelAtPeriodEnd: ${freshStatus.cancelAtPeriodEnd}');
      }

      // Check if subscription was just cancelled
      final previousStatus = _currentSubscriptionStatus;
      final wasNotCancelling = previousStatus?.cancelAtPeriodEnd != true &&
                                previousStatus?.isActive == true;
      final isNowCancelling = freshStatus?.cancelAtPeriodEnd == true;

      // Update state
      if (mounted) {
        setState(() {
          _currentSubscriptionPlan = updatedPlan;
          _currentSubscriptionStatus = freshStatus;
          // Only update selected plan if user hasn't manually selected one AND no plan was pre-selected
          if (!_hasUserManuallySelectedPlan && !_hasPreSelectedPlan) {
            _selectedPlan = _getNextBestPlanSync(updatedPlan);
          }
        });

        // Show cancellation screen if subscription was just cancelled
        if (wasNotCancelling && isNowCancelling) {
          debugPrint('🚨 CANCELLATION DETECTED in _refreshSubscriptionStatus!');
          debugPrint('   - Previous plan: ${previousStatus?.planId}');

          // Small delay to ensure state update completes
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SubscriptionCancelledScreen(
                    previousPlan: previousStatus?.planId,
                    onContinue: () {
                      _refreshSubscriptionStatus();
                    },
                  ),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error refreshing subscription status: $e');
    }
  }

  /// Synchronous version of _getNextBestPlan for immediate UI updates
  String _getNextBestPlanSync(String? currentPlan) {
    switch (currentPlan) {
      case 'free':
        return 'pro';
      case 'pro':
        return 'advanced'; // Pro users should see Advanced as upgrade option
      case 'advanced':
        return 'advanced'; // Already on highest plan
      default:
        return 'pro';
    }
  }

  void _scrollToSelectedPlan() {
    debugPrint('🔄 _scrollToSelectedPlan called for plan: $_selectedPlan');
    if (!mounted) {
      debugPrint('❌ Scroll cancelled: not mounted');
      return;
    }

    GlobalKey? targetKey;
    if (_selectedPlan == 'pro') {
      targetKey = _proPlanKey;
    } else if (_selectedPlan == 'advanced') {
      targetKey = _advancedPlanKey;
    }

    debugPrint(
        '🎯 Target key: $targetKey, currentContext: ${targetKey?.currentContext}');

    if (targetKey?.currentContext != null) {
      debugPrint('✅ Found context, scheduling scroll');

      // Use Scrollable.ensureVisible which handles all the coordinate transformations
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            Scrollable.ensureVisible(
              targetKey!.currentContext!,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              alignment: 0.1, // Position 10% from top of viewport
            );
            debugPrint('📜 Scrollable.ensureVisible called');
          } catch (e) {
            debugPrint('❌ Error during scroll: $e');
          }
        }
      });
    } else {
      debugPrint('❌ No context found for target key');
    }
  }

  Future<String> _getNextBestPlan() async {
    try {
      // First check cached subscription (most reliable since backend may fail)
      final stripeService = StripeCheckoutService(
        baseUrl: 'https://pushin-production.up.railway.app/api',
        isTestMode: true,
      );

      final cachedStatus = await stripeService.getCachedSubscriptionStatus();
      if (cachedStatus != null && cachedStatus.isActive) {
        switch (cachedStatus.planId) {
          case 'free':
            return 'pro';
          case 'pro':
            return 'advanced'; // Pro users should see Advanced as upgrade option
          case 'advanced':
            return 'advanced'; // Already on highest plan
          default:
            return 'pro';
        }
      }

      // Try backend as fallback (may fail with 500)
      final authProvider = context.read<AuthStateProvider>();
      final currentUser = authProvider.currentUser;
      final isAuthenticated = authProvider.isAuthenticated;

      if (currentUser != null) {
        final subscriptionStatus = await stripeService.checkSubscriptionStatus(
          userId: currentUser.id.toString(),
        );

        if (subscriptionStatus != null && subscriptionStatus.isActive) {
          switch (subscriptionStatus.planId) {
            case 'free':
              return 'pro';
            case 'pro':
              return 'advanced';
            case 'advanced':
              return 'advanced';
            default:
              return 'pro';
          }
        }
      } else if (!isAuthenticated) {
        // Unauthenticated users are always on free tier
        // They need to sign up to purchase a subscription
      }

      // Default for unauthenticated users or no active subscription
      return 'pro';
    } catch (e) {
      debugPrint('Error checking subscription status for plan selection: $e');
      return 'pro'; // Default fallback on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    // Trigger scroll to selected plan after layout is complete
    if (_shouldScrollToSelectedPlan && !_isInitializingPlan) {
      _shouldScrollToSelectedPlan = false; // Reset flag
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedPlan();
      });
    }

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
                          // Left side: Back button (only show when not in onboarding)
                          if (widget.onboardingData == null)
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
                              onPeriodChanged: _isInitializingPlan
                                  ? (_) {}
                                  : _onBillingPeriodChanged,
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
                      controller: _scrollController,
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
                                    '3-Day Free Trial',
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

                          // Free Version Card
                          _PlanCard(
                            planName: 'Free',
                            monthlyPrice: '0 €',
                            yearlyPrice: '0 €',
                            isYearly: _billingPeriod == 'yearly',
                            features: const [
                              '3 hours of app blocking per day',
                              '1 workout',
                              'Basic Progress Tracking',
                            ],
                            isSelected: _selectedPlan == 'free',
                            isPopular: false,
                            isCurrentPlan:
                                false, // Free plan doesn't show as "current"
                            onTap: _isInitializingPlan
                                ? null
                                : () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _selectedPlan = 'free';
                                      _hasUserManuallySelectedPlan = true;
                                    });
                                  },
                          ),

                          const SizedBox(height: 16),

                          // Plan Cards
                          _PlanCard(
                            key: _proPlanKey,
                            planName: 'Pro',
                            monthlyPrice: '6.99 €',
                            yearlyPrice: '49.99 €',
                            oldMonthlyPrice:
                                '9.99 €', // Show original monthly price crossed out
                            oldYearlyPrice:
                                '119.99 €', // Show full yearly price crossed out (60% off)
                            isYearly: _billingPeriod == 'yearly',
                            features: const [
                              'Unlimited Hours of App Blocking',
                              'Unlimited App Blockages',
                              '3 Workouts',
                              'Basic Progress Tracking',
                              'Emergency Unlock',
                            ],
                            isSelected: _selectedPlan == 'pro',
                            isPopular: _currentSubscriptionPlan !=
                                'pro', // Only show POPULAR if not current plan
                            isCurrentPlan: _currentSubscriptionPlan == 'pro',
                            subscriptionStatus: _currentSubscriptionPlan == 'pro'
                                ? _currentSubscriptionStatus
                                : null,
                            onTap: _isInitializingPlan
                                ? null
                                : _currentSubscriptionPlan == 'pro'
                                    ? () {
                                        // Current plan - still update selection for visual feedback
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _selectedPlan = 'pro';
                                          _hasUserManuallySelectedPlan = true;
                                        });
                                      }
                                    : () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _selectedPlan = 'pro';
                                          _hasUserManuallySelectedPlan = true;
                                        });
                                      },
                          ),

                          const SizedBox(height: 16),

                          _PlanCard(
                            key: _advancedPlanKey,
                            planName: 'Advanced',
                            monthlyPrice: '9.99 €',
                            yearlyPrice: '79.99 €',
                            oldMonthlyPrice:
                                '14.99 €', // Show original monthly price crossed out
                            oldYearlyPrice:
                                '179.99 €', // Show full yearly price crossed out (60% off)
                            isYearly: _billingPeriod == 'yearly',
                            isCurrentPlan:
                                _currentSubscriptionPlan == 'advanced',
                            subscriptionStatus:
                                _currentSubscriptionPlan == 'advanced'
                                    ? _currentSubscriptionStatus
                                    : null,
                            features: const [
                              'Unlimited Hours of App Blocking',
                              'Unlimited App Blockages',
                              'Unlimited Workouts*',
                              'Advanced Analytics',
                              'Water intake tracking',
                              'Steps and kcal counter',
                              'Emergency Unlock',
                            ],
                            isSelected: _selectedPlan == 'advanced',
                            isPopular: false,
                            onTap: _isInitializingPlan
                                ? null
                                : _currentSubscriptionPlan == 'advanced'
                                    ? () {
                                        // Current plan - still update selection for visual feedback
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _selectedPlan = 'advanced';
                                          _hasUserManuallySelectedPlan = true;
                                        });
                                      }
                                    : () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _selectedPlan = 'advanced';
                                          _hasUserManuallySelectedPlan = true;
                                        });
                                      },
                          ),

                          const SizedBox(height: 150), // Space for fixed button
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
                    isLoading: _isLoading || _isInitializingPlan,
                    planName: _selectedPlan,
                    isCurrentPlan: _selectedPlan == _currentSubscriptionPlan,
                    onTap: _isInitializingPlan
                        ? null
                        : () => _selectedPlan == _currentSubscriptionPlan
                            ? _handleManageSubscription()
                            : _handleSubscribe(context),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _skipTrial,
                    child: Builder(
                      builder: (context) {
                        final authProvider = context.read<AuthStateProvider>();
                        final isAuthenticated = authProvider.isAuthenticated;
                        final displayText = _getCurrentPlanDisplayName();
                        return Text(
                          isAuthenticated
                              ? 'Continue with $displayText'
                              : 'Continue as Guest',
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

    // Complete onboarding flow for all users (free plan)
    await authProvider.completeOnboardingFlow();

    // Replace entire navigation stack with main app to prevent flash of intermediate screens
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainTabNavigation(),
        ),
        (route) => false, // Remove all previous routes
      );
    }
  }

  String _getCurrentPlanDisplayName() {
    // Use the cached _currentSubscriptionPlan state instead of making API calls
    // This ensures Pro/Advanced users see their correct plan when pressing continue
    if (_currentSubscriptionPlan != null) {
      switch (_currentSubscriptionPlan) {
        case 'pro':
          return 'Pro Plan';
        case 'advanced':
          return 'Advanced Plan';
        case 'free':
        default:
          return 'Free Plan';
      }
    }

    // Default to Free Plan if no cached plan
    return 'Free Plan';
  }

  void _handleSubscribe(BuildContext context) async {
    debugPrint('🔴🔴🔴 _handleSubscribe CALLED! 🔴🔴🔴');

    // Handle free plan selection - skip trial
    if (_selectedPlan == 'free') {
      _skipTrial();
      return;
    }

    // Safety check: Prevent purchasing the current plan
    if (_selectedPlan == _currentSubscriptionPlan) {
      debugPrint('⚠️ Attempted to purchase current plan - blocked');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('🟡 Creating StripeCheckoutService...');
      final stripeService = StripeCheckoutService(
        baseUrl: 'https://pushin-production.up.railway.app/api',
        isTestMode: true,
      );

      // Get current user info
      final authProvider = context.read<AuthStateProvider>();
      final currentUser = authProvider.currentUser;
      final isAuthenticated = authProvider.isAuthenticated;

      // Check if user is authenticated - if not, prompt to sign up first
      if (!authProvider.isAuthenticated) {
        debugPrint(
            '🚫 Unauthenticated user attempting purchase - navigating to sign up screen');
        // Mark that user was trying to purchase, so we can continue after auth
        setState(() => _pendingPurchaseAfterAuth = true);
        // Keep loading state active during navigation to prevent button spam
        // Use direct navigation instead of state-driven routing for immediate effect
        Navigator.of(context)
            .push(
          MaterialPageRoute(
            builder: (context) => const SignUpScreen(),
          ),
        )
            .then((_) {
          // Reset loading state when user returns from sign up screen
          if (mounted) {
            setState(() {
              _isLoading = false;
              // If purchase didn't auto-continue, reset the pending flag
              if (_pendingPurchaseAfterAuth) {
                _pendingPurchaseAfterAuth = false;
              }
            });
          }
        });
        return;
      }

      // Require authenticated user for checkout
      if (!isAuthenticated || currentUser == null) {
        _showErrorDialog('Please sign in to continue with your purchase.');
        return;
      }

      final userId = currentUser.id.toString();
      final userEmail = currentUser.email ?? 'user@example.com';

      debugPrint('🛒 PaywallScreen: Starting checkout');
      debugPrint('   - userId: $userId');
      debugPrint('   - userEmail: $userEmail');
      debugPrint('   - planId: $_selectedPlan');
      debugPrint('   - billingPeriod: $_billingPeriod');

      // Set the pending checkout userId so DeepLinkHandler can verify the payment
      final pushinController = context.read<PushinAppController>();
      pushinController.setPendingCheckoutUserId(userId);

      // Launch checkout with plan ID ('pro' or 'advanced') and billing period ('monthly' or 'yearly')
      final backendPlanId = _selectedPlan; // 'pro' or 'advanced'

      // Set the planId for fallback subscription status creation (CRITICAL for fallback)
      // MUST await this to ensure it's persisted before launching checkout
      await pushinController.setPendingCheckoutPlanId(backendPlanId);
      debugPrint(
          '💳 PaywallScreen: Set and persisted pending checkout plan: $backendPlanId');

      final success = await stripeService.launchCheckout(
        userId: userId,
        planId: backendPlanId, // 'pro' or 'advanced'
        billingPeriod: _billingPeriod, // 'monthly' or 'yearly'
        userEmail: userEmail,
      );

      if (!context.mounted) return;

      if (success) {
        // For real mode, plan tier will be updated via deep link handler
        // For test mode, simulate payment success immediately since no deep link is triggered
        if (stripeService.isTestMode) {
          debugPrint(
              'TEST MODE: Checkout simulated successfully - triggering payment success flow');
          // Simulate payment success by creating a subscription status and triggering the callback
          final simulatedStatus = SubscriptionStatus(
            isActive: true,
            planId: _selectedPlan,
            customerId: 'cus_test_${currentUser.id}',
            subscriptionId:
                'sub_test_${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}',
            currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
            cachedUserId: currentUser.id.toString(),
          );

          // Save the simulated subscription status
          await stripeService.saveSubscriptionStatus(simulatedStatus);

          // Trigger the payment success callback to update UI state
          final pushinController = context.read<PushinAppController>();
          pushinController.paymentSuccessState.value = simulatedStatus;
          debugPrint(
              'TEST MODE: Payment success state updated, UI should reflect new plan tier');
        }
      } else {
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
      barrierDismissible: false,
      builder: (context) => ErrorPopup(
        title: 'Something Went Wrong',
        message: message,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _handleReactivateSubscription() async {
    try {
      final authProvider = context.read<AuthStateProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null ||
          _currentSubscriptionStatus?.subscriptionId == null) {
        debugPrint('❌ Cannot reactivate: missing user or subscription');
        _showErrorDialog('Unable to reactivate subscription.');
        return;
      }

      debugPrint('🔄 ═══════════════════════════════════════════════');
      debugPrint('🔄 REACTIVATING SUBSCRIPTION');
      debugPrint('🔄 ═══════════════════════════════════════════════');

      setState(() => _isLoading = true);

      final stripeService = StripeCheckoutService(
        baseUrl: 'https://pushin-production.up.railway.app/api',
        isTestMode: true,
      );

      final success = await stripeService.reactivateSubscription(
        userId: currentUser.id.toString(),
        subscriptionId: _currentSubscriptionStatus!.subscriptionId!,
      );

      if (success && mounted) {
        debugPrint('✅ Subscription reactivated - refreshing status...');

        // Refresh subscription status
        await _refreshSubscriptionStatus();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '✅ Subscription reactivated! You\'ll continue to be billed.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (mounted) {
        _showErrorDialog('Unable to reactivate subscription. Please try again.');
      }
    } catch (e) {
      debugPrint('❌ Error reactivating subscription: $e');
      if (mounted) {
        _showErrorDialog('An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleManageSubscription() async {
    try {
      final authProvider = context.read<AuthStateProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        debugPrint('❌ Cannot open portal: user not authenticated');
        _showErrorDialog('Please sign in to manage your subscription.');
        return;
      }

      debugPrint('🏦 ═══════════════════════════════════════════════');
      debugPrint('🏦 OPENING STRIPE CUSTOMER PORTAL');
      debugPrint('🏦 ═══════════════════════════════════════════════');

      setState(() => _isLoading = true);

      final stripeService = StripeCheckoutService(
        baseUrl: 'https://pushin-production.up.railway.app/api',
        isTestMode: true,
      );

      // CRITICAL: Store current subscription status before opening portal
      // This allows us to detect if the user cancels their subscription
      debugPrint('🏦 Fetching current subscription status...');
      final currentSubscription = await stripeService.checkSubscriptionStatus(
        userId: currentUser.id.toString(),
      );

      debugPrint('🏦 Current subscription before portal:');
      debugPrint('   - Plan: ${currentSubscription?.planId}');
      debugPrint('   - Active: ${currentSubscription?.isActive}');
      debugPrint('   - Customer ID: ${currentSubscription?.customerId}');

      final pushinController = context.read<PushinAppController>();
      await pushinController.setSubscriptionBeforePortal(currentSubscription);

      debugPrint('🏦 Opening portal...');
      final success = await stripeService.openCustomerPortal(
        userId: currentUser.id.toString(),
      );

      debugPrint('🏦 Portal open result: $success');

      if (!success && mounted) {
        _showErrorDialog(
            'Unable to open subscription management. Please try again.');
      } else {
        debugPrint('🏦 ✅ Portal opened successfully');
        debugPrint('🏦 ⚠️ IMPORTANT: After cancelling in Stripe, tap "Return to app" button');
        debugPrint('🏦 ⚠️ Do NOT manually switch back using app switcher!');

        // Check status when user returns (fallback if deep link doesn't fire)
        _scheduleStatusCheckAfterPortal();
      }
    } catch (e) {
      debugPrint('❌ Error opening customer portal: $e');
      if (mounted) {
        _showErrorDialog('An error occurred: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Schedule a status check after portal visit (fallback if deep link fails)
  void _scheduleStatusCheckAfterPortal() {
    // Store current status before portal
    final beforePortalStatus = _currentSubscriptionStatus;
    bool cancellationScreenShown = false;

    // Helper to check for cancellation and show screen
    Future<void> checkForCancellation(int delaySeconds) async {
      await Future.delayed(Duration(seconds: delaySeconds));

      if (!mounted || cancellationScreenShown) return;

      debugPrint('🔄 Scheduled portal check (${delaySeconds}s delay): Refreshing subscription status...');
      debugPrint('   - Before: cancelAtPeriodEnd = ${beforePortalStatus?.cancelAtPeriodEnd}');

      await _refreshSubscriptionStatus();

      // Check if cancellation happened
      final afterPortalStatus = _currentSubscriptionStatus;
      debugPrint('   - After: cancelAtPeriodEnd = ${afterPortalStatus?.cancelAtPeriodEnd}');

      final wasNotCancelling = beforePortalStatus?.cancelAtPeriodEnd != true &&
                                beforePortalStatus?.isActive == true;
      final isNowCancelling = afterPortalStatus?.cancelAtPeriodEnd == true;

      debugPrint('🔍 Cancellation check (${delaySeconds}s):');
      debugPrint('   - wasNotCancelling: $wasNotCancelling');
      debugPrint('   - isNowCancelling: $isNowCancelling');
      debugPrint('   - mounted: $mounted');
      debugPrint('   - cancellationScreenShown: $cancellationScreenShown');

      if (wasNotCancelling && isNowCancelling && mounted && !cancellationScreenShown) {
        cancellationScreenShown = true;
        debugPrint('🚨 FALLBACK: Cancellation detected via status check (${delaySeconds}s)!');
        debugPrint('   - Previous plan: ${beforePortalStatus?.planId}');

        // Navigate to cancellation screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SubscriptionCancelledScreen(
              previousPlan: beforePortalStatus?.planId,
              onContinue: () {
                // Refresh when user continues
                _refreshSubscriptionStatus();
              },
            ),
          ),
        );
      }
    }

    // Check at multiple intervals to catch the cancellation whenever Stripe updates
    checkForCancellation(5);  // First check at 5 seconds
    checkForCancellation(10); // Second check at 10 seconds
    checkForCancellation(15); // Third check at 15 seconds (in case Stripe is slow)
  }

  void _showRestorePurchasesDialog() async {
    // Create payment service
    final stripeService = StripeCheckoutService(
      baseUrl: 'https://pushin-production.up.railway.app/api',
      isTestMode: true,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RestorePurchasesPopup(
        paymentService: stripeService,
        onDismiss: () => Navigator.pop(context),
        onRestoreComplete: (result) async {
          // Close dialog
          Navigator.pop(context);

          if (result.hasActiveSubscription) {
            // Update app state with restored subscription
            final pushinController = context.read<PushinAppController>();

            // Update plan tier
            pushinController.updatePlanTier(
              result.subscription!.planId,
              0, // No grace period
            );

            // Show success and navigate away from paywall
            await Future.delayed(const Duration(milliseconds: 500));

            if (mounted) {
              // Navigate to main app
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainTabNavigation(),
                ),
                (route) => false,
              );
            }
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    final pushinController = context.read<PushinAppController>();
    final authProvider = context.read<AuthStateProvider>();

    pushinController.removeListener(_planTierListener);
    pushinController.paymentSuccessState
        .removeListener(_paymentSuccessListener);
    pushinController.upgradeWelcomeState
        .removeListener(_paymentSuccessListener);
    pushinController.subscriptionCancelledPlan
        .removeListener(_subscriptionCancelledListener);
    authProvider.removeListener(_authStateListener);

    _scrollController.dispose();
    super.dispose();
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
  final String? oldMonthlyPrice; // For showing discounted monthly pricing
  final String? oldYearlyPrice; // For showing discounted yearly pricing
  final bool isYearly;
  final List<String> features;
  final bool isSelected;
  final bool isPopular;
  final bool isCurrentPlan; // Whether this is the user's currently active plan
  final SubscriptionStatus?
      subscriptionStatus; // For showing cancellation countdown
  final VoidCallback? onTap;

  const _PlanCard({
    super.key,
    required this.planName,
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.oldMonthlyPrice,
    this.oldYearlyPrice,
    required this.isYearly,
    required this.features,
    required this.isSelected,
    required this.isPopular,
    this.isCurrentPlan = false,
    this.subscriptionStatus,
    required this.onTap,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isPressed = false;

  /// Get badge text for current plan
  String _getBadgeText() {
    // Check if subscription is set to cancel
    if (widget.subscriptionStatus?.cancelAtPeriodEnd == true &&
        widget.subscriptionStatus?.currentPeriodEnd != null) {
      final daysRemaining = widget.subscriptionStatus!.currentPeriodEnd!
          .difference(DateTime.now())
          .inDays;

      if (daysRemaining <= 0) {
        return 'EXPIRES TODAY';
      } else if (daysRemaining == 1) {
        return '1 DAY LEFT';
      } else {
        return '$daysRemaining DAYS LEFT';
      }
    }

    // Default: show current plan
    return 'CURRENT PLAN';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
      value: widget.isYearly ? 1.0 : 0.0,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(_PlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isYearly != widget.isYearly) {
      if (widget.isYearly) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) {
              setState(() => _isPressed = true);
            }
          : null,
      onTapUp: widget.onTap != null
          ? (_) {
              setState(() => _isPressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.onTap != null
          ? () {
              setState(() => _isPressed = false);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Colors.white
              : Colors.white.withOpacity(widget.onTap == null ? 0.05 : 0.1),
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
        child: Stack(
          children: [
            // Main content
            Column(
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
                              // Current Plan badge or Days Left countdown
                              if (widget.isCurrentPlan) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.subscriptionStatus
                                                    ?.cancelAtPeriodEnd ==
                                                true
                                        ? Colors.red
                                            .shade600 // Red for cancelling
                                        : const Color(
                                            0xFF6060FF), // Blue for active
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    _getBadgeText(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ] else if (widget.isPopular) ...[
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
                              // Animated savings badge with smooth crossfade
                              if (widget.planName != 'Free')
                                Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: AnimatedBuilder(
                                    animation: _animation,
                                    builder: (context, child) {
                                      final monthlyDiscount =
                                          _getDiscountPercentageFor(
                                              isYearly: false);
                                      final yearlyDiscount =
                                          _getDiscountPercentageFor(
                                              isYearly: true);

                                      return ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                          ),
                                          child: Stack(
                                            children: [
                                              // Monthly discount
                                              Opacity(
                                                opacity: 1.0 - _animation.value,
                                                child: Text(
                                                  monthlyDiscount,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              // Yearly discount
                                              Opacity(
                                                opacity: _animation.value,
                                                child: Text(
                                                  yearlyDiscount,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Animated price display with smooth crossfade
                          ClipRect(
                            child: SizedBox(
                              height: 40,
                              child: AnimatedBuilder(
                                animation: _animation,
                                builder: (context, child) {
                                  return Stack(
                                    children: [
                                      // Monthly price (fades out and slides left when going to yearly)
                                      Opacity(
                                        opacity: 1.0 - _animation.value,
                                        child: Transform.translate(
                                          offset:
                                              Offset(-20 * _animation.value, 0),
                                          child:
                                              _buildPriceRow(isYearly: false),
                                        ),
                                      ),
                                      // Yearly price (fades in and slides in from right)
                                      Opacity(
                                        opacity: _animation.value,
                                        child: Transform.translate(
                                          offset: Offset(
                                              20 * (1 - _animation.value), 0),
                                          child: _buildPriceRow(isYearly: true),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
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
                        Flexible(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.isSelected
                                  ? const Color(0xFF2A2A6A).withOpacity(0.8)
                                  : Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Selection indicator positioned at top right
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedContainer(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow({required bool isYearly}) {
    final price = isYearly ? widget.yearlyPrice : widget.monthlyPrice;
    final period = isYearly ? '/year' : '/month';
    final oldPrice = isYearly ? widget.oldYearlyPrice : widget.oldMonthlyPrice;
    final hasOldPrice = oldPrice != null;
    final priceFontSize = hasOldPrice ? 28.0 : 28.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Old price (crossed out)
        if (hasOldPrice) ...[
          Text(
            oldPrice,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: widget.isSelected
                  ? const Color(0xFF3535A0).withOpacity(0.5)
                  : Colors.white.withOpacity(0.4),
              decoration: TextDecoration.lineThrough,
              decorationColor: widget.isSelected
                  ? const Color(0xFF3535A0).withOpacity(0.3)
                  : Colors.white.withOpacity(0.3),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Current price
        Text(
          price,
          style: TextStyle(
            fontSize: priceFontSize,
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

  String _getDiscountPercentageFor({required bool isYearly}) {
    final oldPriceStr =
        isYearly ? widget.oldYearlyPrice : widget.oldMonthlyPrice;
    final newPriceStr = isYearly ? widget.yearlyPrice : widget.monthlyPrice;

    if (oldPriceStr == null) return '';

    // Parse prices (remove € and convert to double)
    final oldPrice = double.tryParse(
            oldPriceStr.replaceAll(' €', '').replaceAll(',', '.')) ??
        0;
    final newPrice = double.tryParse(
            newPriceStr.replaceAll(' €', '').replaceAll(',', '.')) ??
        0;

    if (oldPrice == 0) return '';

    final discount = ((oldPrice - newPrice) / oldPrice * 100).round();
    return '-$discount%';
  }
}

/// Start Trial Button
class _StartTrialButton extends StatelessWidget {
  final bool isLoading;
  final String planName;
  final bool isCurrentPlan;
  final VoidCallback? onTap;

  const _StartTrialButton({
    required this.isLoading,
    required this.planName,
    this.isCurrentPlan = false,
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
          color: isLoading ? Colors.white.withOpacity(0.7) : Colors.white,
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
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF2A2A6A),
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  isCurrentPlan
                      ? 'Manage Subscription'
                      : planName == 'free'
                          ? 'Continue for Free'
                          : 'Start Free Trial — ${planName.toUpperCase()}',
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
