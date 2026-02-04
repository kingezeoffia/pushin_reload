import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';

import 'package:pushin_reload/services/ios_rating_service.dart';

/// Rating Screen - Prompts users to rate the app
///
/// Design matches the app's visual system (GOStepsBackground, consistent styling)
/// Shows after key milestones (2nd launch, 1st workout, new subscription)
class RatingScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const RatingScreen({
    super.key,
    required this.onContinue,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _selectedStars = 5;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GOStepsBackground(
        blackRatio: 0.18, // Matching Paywall opacity
        child: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Consistent spacing with other screens
                  SizedBox(height: screenHeight * 0.04),

                  // Heading
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            size: 40,
                            color: Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Your opinion",
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
                            colors: [
                              Color(0xFFFBBF24),
                              Color(0xFFFCD34D),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(
                            Rect.fromLTWH(
                                0, 0, bounds.width, bounds.height * 1.3),
                          ),
                          blendMode: BlendMode.srcIn,
                          child: const Text(
                            "Matters!",
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Help us grow by rating us',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.6),
                            letterSpacing: -0.2,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // Star Rating
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Title
                  Text(
                    '$_selectedStars-Star Rating',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final starNumber = index + 1;
                              final isSelected = starNumber <= _selectedStars;
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _selectedStars = starNumber;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  child: Icon(
                                    isSelected
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 48,
                                    color: isSelected
                                        ? const Color(0xFFFBBF24)
                                        : Colors.black.withOpacity(0.2),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Reviews
                  const _ReviewCard(
                    name: 'Juan C.',
                    imageAsset: 'assets/images/reviews/IMG_2726.png',
                    review: 'Finally broke my doom scrolling! This is the perfect app to keep me on track!',
                    stars: 5,
                    avatarColor: Color(0xFFE9D5FF),
                  ),
                  const _ReviewCard(
                    name: 'Alexander',
                    imageAsset: 'assets/images/reviews/IMG_2729.png',
                    review: 'My screen time dropped from 9 hours to 3, and I get to exercise more? SIGN ME UP!',
                    stars: 5,
                    avatarColor: Color(0xFFBFDBFE),
                  ),
                  const _ReviewCard(
                    name: 'Andrew',
                    imageAsset: 'assets/images/reviews/IMG_2730.png',
                    review: 'I sometimes find myself motivated to not even access my earned screen time. I love the psychological impact!',
                    stars: 5,
                    avatarColor: Color(0xFFFED7AA),
                  ),
                  const _ReviewCard(
                    name: 'Nguyen T.',
                    imageAsset: 'assets/images/reviews/IMG_2731.png',
                    review: 'Great concept. This might be a game changer for me!',
                    stars: 4.5,
                    avatarColor: Color(0xFFA7F3D0),
                  ),
                  const _ReviewCard(
                    name: 'Jason M',
                    imageAsset: 'assets/images/reviews/IMG_2732.png',
                    review: 'Great design! The app doesn\'t feel like a punishment.',
                    stars: 4,
                    avatarColor: Color(0xFFFECACA),
                  ),

                  const SizedBox(height: 24),

                  // Spacer for button area
                  const SizedBox(height: 140),


                ],
              ),
            ),

            // Fixed Bottom Action Area with Gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 32,
                  right: 32,
                  top: 24,
                  bottom: MediaQuery.of(context).padding.bottom + 4,
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
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SubmitButton(
                      onTap: _selectedStars > 0 ? _handleSubmit : null,
                      isLoading: _isSubmitting,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _handleSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        splashFactory: NoSplash.splashFactory,
                      ),
                      child: Text(
                        'Maybe Later',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.5),
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w500,
                        ),
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

  void _handleSkip() async {
    HapticFeedback.mediumImpact();
    // Don't mark as rated so the prompt shows again later
    widget.onContinue();
  }

  void _handleSubmit() async {
    if (_selectedStars == 0 || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    HapticFeedback.mediumImpact();

    // Mark as rated
    await _markAsRated();

    // Show native iOS rating popup instead of redirecting to App Store
    try {
      await IOSRatingService.requestNativeRating();
      debugPrint('⭐ RatingScreen: Native iOS rating popup requested');
    } catch (e) {
      debugPrint('⭐ RatingScreen: Error requesting native rating: $e');
    }

    // Close the screen
    widget.onContinue();
  }

  Future<void> _markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_rated_app', true);
    debugPrint('⭐ RatingScreen: Marked as rated');
  }
}

/// Submit Button Widget
class _SubmitButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _SubmitButton({
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null && !isLoading;

    return PressAnimationButton(
      onTap: isEnabled ? onTap! : () {},
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: isEnabled
              ? Colors.white.withOpacity(0.95)
              : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(100),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF2A2A6A),
                    ),
                  ),
                )
              : Text(
                  "Submit Rating",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isEnabled
                        ? const Color(0xFF2A2A6A)
                        : const Color(0xFF2A2A6A).withOpacity(0.5),
                    letterSpacing: -0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String name;
  final String? imageAsset;
  final String review;
  final double stars;
  final Color avatarColor;

  const _ReviewCard({
    required this.name,
    this.imageAsset,
    required this.review,
    required this.stars,
    required this.avatarColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2), // White border effect
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: imageAsset != null
                    ? CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.transparent,
                        backgroundImage: AssetImage(imageAsset!),
                      )
                    : CircleAvatar(
                        radius: 18,
                        backgroundColor: avatarColor,
                        child: Text(
                          name[0],
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: List.generate(5, (index) {
                        IconData icon;
                        if (index >= stars) {
                          icon = Icons.star_outline_rounded;
                        } else if (index > stars - 1 && index < stars) {
                          icon = Icons.star_half_rounded;
                        } else {
                          icon = Icons.star_rounded;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(
                            icon,
                            color: const Color(0xFFFBBF24), // Yellow
                            size: 18,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
