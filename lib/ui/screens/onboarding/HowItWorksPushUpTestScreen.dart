import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../theme/pushin_theme.dart';
import 'HowItWorksUnlockDurationScreen.dart';
import 'HowItWorksPushUpSuccessScreen.dart';

/// Step 2.5: Push-Up Test Screen
///
/// BMAD V6 Spec:
/// - Camera permission request and live preview
/// - Visual guidance for phone placement and user positioning
/// - Real push-up detection simulation (falls back to manual counting if camera unavailable)
/// - Premium, modern UI matching onboarding flow
/// - Clear instructions with minimal text
class HowItWorksPushUpTestScreen extends StatefulWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;
  final String workoutHistory;
  final List<String> blockedApps;

  const HowItWorksPushUpTestScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
    required this.workoutHistory,
    required this.blockedApps,
  });

  @override
  State<HowItWorksPushUpTestScreen> createState() =>
      _HowItWorksPushUpTestScreenState();
}

class _HowItWorksPushUpTestScreenState extends State<HowItWorksPushUpTestScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  int _detectedReps = 0;
  bool _showInstructions = true;

  // Mock push-up detection for demo
  static const int _targetReps = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void activate() {
    super.activate();
    // Reset state immediately when returning to this screen
    _resetStateForRetry();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _isCameraInitialized = false);
        return;
      }

      // Use front camera for push-up detection
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      // Camera not available, will show manual fallback
      setState(() => _isCameraInitialized = false);
    }
  }

  void _resetStateForRetry() {
    setState(() {
      _isDetecting = false;
      _detectedReps = 0;
      _showInstructions = true;
    });
  }

  void _startDetection() {
    setState(() {
      _isDetecting = true;
      _showInstructions = false;
    });

    // Simulate push-up detection for demo
    _simulatePushUpDetection();
  }

  void _simulatePushUpDetection() async {
    // Mock detection - in real implementation, this would use pose detection
    // First push-up detection happens quickly
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _detectedReps = 1);
      HapticFeedback.mediumImpact();
    }

    // Subsequent detections at normal intervals
    for (int i = 2; i <= _targetReps; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _detectedReps = i);
        HapticFeedback.mediumImpact();
      }
    }

    // Brief pause to let user register the final "3" rep
    await Future.delayed(const Duration(milliseconds: 800));

    // Stop detection and navigate to success screen
    if (mounted) {
      setState(() => _isDetecting = false);
      _showSuccessScreen();
    }
  }

  void _showSuccessScreen() {
    HapticFeedback.heavyImpact();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HowItWorksPushUpSuccessScreen(
          fitnessLevel: widget.fitnessLevel,
          goals: widget.goals,
          otherGoal: widget.otherGoal,
          workoutHistory: widget.workoutHistory,
          blockedApps: widget.blockedApps,
        ),
      ),
    );
  }

  void _manualRepCount() async {
    if (_detectedReps < _targetReps) {
      setState(() => _detectedReps++);
      HapticFeedback.lightImpact();
    }

    if (_detectedReps >= _targetReps) {
      // Brief pause to let user register the final "3" rep
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        _showSuccessScreen();
      }
    }
  }

  void _continueToNextScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HowItWorksUnlockDurationScreen(
          fitnessLevel: widget.fitnessLevel,
          goals: widget.goals,
          otherGoal: widget.otherGoal,
          workoutHistory: widget.workoutHistory,
          blockedApps: widget.blockedApps,
          selectedWorkout: 'Push-Ups',
        ),
      ),
    );
  }

  /// Build camera preview with proper aspect ratio (no stretching)
  /// Fills width edge-to-edge, crops top/bottom if needed (no side bars)
  Widget _buildCameraPreview() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    // Get camera's natural dimensions
    final previewSize = _cameraController!.value.previewSize!;

    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover, // Fill width, crop top/bottom to avoid side bars
        child: SizedBox(
          width: previewSize.height, // Swapped due to camera sensor orientation
          height: previewSize.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

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
              // Back Button & Step Indicator
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16, top: 8),
                child: Row(
                  children: [
                    _BackButton(onTap: () => Navigator.pop(context)),
                    const Spacer(),
                    _StepIndicator(
                        currentStep: 3, totalSteps: 6), // Updated total steps
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.04),

              // Heading
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Try it out:',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.05,
                        letterSpacing: -1,
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(
                        Rect.fromLTWH(0, 0, bounds.width, bounds.height * 1.3),
                      ),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        'Push-Up Test',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -0.5,
                          decoration: TextDecoration.none,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Do 3 push-ups to test the workout detection',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.04),

              // Camera Preview / Instructions
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Camera Container
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                // Camera Preview
                                if (_isCameraInitialized &&
                                    _cameraController != null)
                                  _buildCameraPreview()
                                else
                                  // Fallback when camera not available
                                  Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: Icon(
                                        Icons.camera_alt_outlined,
                                        color: Colors.white24,
                                        size: 64,
                                      ),
                                    ),
                                  ),

                                // Instructions Overlay (when not detecting)
                                if (_showInstructions)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.7),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.camera_alt_rounded,
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            size: 48,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Position your phone',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Place phone 2-3 feet away, angled up slightly',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                                  Colors.white.withOpacity(0.6),
                                              letterSpacing: -0.2,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Get in push-up position',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Detection Overlay (when detecting)
                                if (_isDetecting)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.3),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Rep counter
                                            Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6060FF)
                                                    .withOpacity(0.9),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '$_detectedReps',
                                                  style: const TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Push-ups detected',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // Camera frame hints
                                if (_isCameraInitialized)
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    right: 16,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white.withOpacity(0.5),
                                          size: 20,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            'Front Camera',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Colors.white.withOpacity(0.8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Buttons
                      if (!_isDetecting)
                        Row(
                          children: [
                            // Start Detection Button
                            Expanded(
                              child: PressAnimationButton(
                                onTap: _startDetection,
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6060FF),
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Start Detection',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Manual Count Button
                            GestureDetector(
                              onTap: _manualRepCount,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        // Progress indicator
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Detecting push-ups...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    const Color(0xFF6060FF).withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Info text
                      if (!_isCameraInitialized)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.white.withOpacity(0.6),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Camera not available. Use manual counting to test the workout.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.6),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Skip for now button (minimal, non-prominent)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: GestureDetector(
                    onTap: _continueToNextScreen,
                    child: Text(
                      'Skip test for now',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.4),
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                      textAlign: TextAlign.center,
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

/// Step indicator widget
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'Step $currentStep of $totalSteps',
        style: PushinTheme.stepIndicatorText.copyWith(
          color: Colors.white.withOpacity(0.8),
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
