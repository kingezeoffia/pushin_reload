import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../theme/pushin_theme.dart';
import '../../../services/CameraWorkoutService.dart';
import '../../../services/PoseDetectionService.dart';
import 'HowItWorksPushUpSuccessScreen.dart';

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

/// Step 3: Push-Up Test Screen
///
/// BMAD V6 Spec:
/// - Camera-based push-up detection
/// - Manual count fallback
/// - Target: 3 push-ups
/// - Step indicator: 3 of 6
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
  CameraWorkoutService? _cameraService;
  bool _isInitialized = false;
  bool _isInitializing = true;
  bool _cameraFailed = false;
  String _errorMessage = '';
  int _detectedReps = 0;
  bool _showInstructions = true;
  bool _hasCompleted = false;
  String _feedbackMessage = 'Position yourself in frame';

  // Track current camera lens direction for switching
  CameraLensDirection _currentCameraLens = CameraLensDirection.front;

  // Mock push-up detection for demo
  static const int _targetReps = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraService == null || !_cameraService!.isReady) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraService?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraService();
    }
  }

  Future<void> _initializeCameraService() async {
    _cameraService = CameraWorkoutService();

    _cameraService!.onRepCounted = (count) {
      if (mounted) {
        setState(() {
          _detectedReps = count;
        });
        HapticFeedback.mediumImpact();

        if (_detectedReps >= _targetReps && !_hasCompleted) {
          _hasCompleted = true;
          _showSuccessScreen();
        }
      }
    };

    _cameraService!.onPoseUpdate = (result) {
      if (mounted) {
        setState(() {
          _feedbackMessage = result.feedbackMessage ?? 'Keep going!';
        });
      }
    };

    try {
      debugPrint(
          'Starting camera initialization for onboarding with $_currentCameraLens camera...');
      final success = await _cameraService!
          .initialize(
        workoutType: 'push-ups',
        preferredCamera: _currentCameraLens,
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Camera initialization timed out after 15 seconds');
          return false;
        },
      );

      debugPrint('Camera initialization result: $success');

      if (success && mounted) {
        debugPrint('Starting push-up test workout...');
        await _cameraService!.startWorkout();
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
        });
        debugPrint('Camera initialized successfully for onboarding');
      } else {
        debugPrint(
            'Camera initialization failed. Error: ${_cameraService!.errorMessage}');
        if (mounted) {
          String errorMsg = _cameraService!.errorMessage ??
              'Camera initialization failed. You can still count reps manually.';

          if (_cameraService!.errorMessage?.contains('permission denied') ??
              false) {
            errorMsg =
                'Camera permission is required for AI rep counting. Please enable camera access in Settings > Privacy > Camera. You can still count reps manually.';
          }

          setState(() {
            _isInitializing = false;
            _cameraFailed = true;
            _errorMessage = errorMsg;
          });
        }
      }
    } catch (e) {
      debugPrint('Camera initialization exception: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _cameraFailed = true;
          _errorMessage =
              'Camera error: $e. You can still count reps manually.';
        });
      }
    }
  }

  void _switchCamera() async {
    // Dispose current service
    await _cameraService?.dispose();

    // Switch camera lens direction
    setState(() {
      _currentCameraLens = _currentCameraLens == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      _isInitialized = false;
      _isInitializing = true;
    });

    // Initialize with the new camera
    await _initializeCameraService();
  }

  void _startDetection() {
    setState(() {
      _showInstructions = false;
    });

    // Detection is already running via the CameraWorkoutService
    // Just hide instructions to show the detection UI
  }

  void _showSuccessScreen() {
    Navigator.push(
      context,
      _NoSwipeBackRoute(
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
      // Wenn Kamera aktiv ist, verwende den Service-Zähler
      if (_cameraService != null && _cameraService!.isReady) {
        _cameraService!.addManualRep();
        // Der onRepCounted Callback wird automatisch _detectedReps aktualisieren
      } else {
        // Wenn Kamera nicht aktiv, erhöhe manuell
        setState(() {
          _detectedReps++;
        });
      }
    }

    if (_detectedReps >= _targetReps && !_hasCompleted) {
      _hasCompleted = true;

      // Brief pause to let user register the final rep
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        _showSuccessScreen();
      }
    }
  }

  /// Build camera preview with proper aspect ratio (no stretching)
  /// Fills width edge-to-edge, crops top/bottom if needed (no side bars)
  Widget _buildCameraPreview() {
    final controller = _cameraService?.cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    // Get camera's natural dimensions
    final previewSize = controller.value.previewSize!;

    return Positioned.fill(
      child: AspectRatio(
        aspectRatio: previewSize.width / previewSize.height,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.height,
                height: previewSize.width,
                child: Stack(
                  children: [
                    CameraPreview(controller),
                    // Pose skeleton overlay
                    if (_cameraService?.lastResult.isPoseDetected ?? false)
                      _buildPoseSkeletonOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build pose skeleton overlay showing detected keypoints
  Widget _buildPoseSkeletonOverlay() {
    final result = _cameraService!.lastResult;
    if (!result.isPoseDetected || result.keyPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _PoseSkeletonPainter(
        keyPoints: result.keyPoints,
        phase: result.phase,
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
              // Step Indicator
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: Row(
                  children: [
                    const Spacer(),
                    _StepIndicator(currentStep: 3, totalSteps: 5),
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
                                if (_isInitialized)
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
                                            'Get in Push-Up position',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            'Place phone angled up slightly',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                                  Colors.white.withOpacity(0.6),
                                              letterSpacing: -0.2,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Detection Overlay (when not showing instructions)
                                if (!_showInstructions)
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
                                              _feedbackMessage,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // Camera frame hints
                                if (_isInitialized &&
                                    _cameraService?.cameraController != null)
                                  Positioned(
                                    top: 16,
                                    right: 16,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        _cameraService!
                                                    .cameraController!
                                                    .description
                                                    .lensDirection ==
                                                CameraLensDirection.front
                                            ? 'Front Camera'
                                            : 'Back Camera',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Buttons
                      if (_showInstructions)
                        Row(
                          children: [
                            // Start Detection Button
                            Expanded(
                              child: PressAnimationButton(
                                onTap: _isInitialized ? _startDetection : null,
                                child: Container(
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: _isInitialized
                                        ? Colors.white
                                        : Colors.grey.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _isInitialized
                                          ? 'Start Detection'
                                          : 'Initializing...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _isInitialized
                                            ? Colors.black
                                            : Colors.white.withOpacity(0.5),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Camera Switch Button
                            GestureDetector(
                              onTap: _isInitialized ? _switchCamera : null,
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _isInitialized
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                child: Icon(
                                  Icons.flip_camera_ios,
                                  color: _isInitialized
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.3),
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        // Manual Count Button
                        Container(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Center(
                            child: _ManualCountButton(onTap: _manualRepCount),
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Info text
                      if (_cameraFailed)
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
                                  _errorMessage,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.6),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_isInitializing)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Initializing AI camera detection...',
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

/// Manual Count Button with light-up effect
class _ManualCountButton extends StatefulWidget {
  final VoidCallback onTap;

  const _ManualCountButton({required this.onTap});

  @override
  State<_ManualCountButton> createState() => _ManualCountButtonState();
}

class _ManualCountButtonState extends State<_ManualCountButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        width: 48,
        height: 48,
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.white.withOpacity(0.3) // Brighter when pressed
              : Colors.white.withOpacity(0.1), // Normal state
          borderRadius: BorderRadius.circular(30),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: const Center(
          child: Icon(
            Icons.add,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for drawing pose detection skeleton
class _PoseSkeletonPainter extends CustomPainter {
  final Map<String, Offset> keyPoints;
  final PushUpPhase phase;

  _PoseSkeletonPainter({
    required this.keyPoints,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (keyPoints.isEmpty) return;

    final paint = Paint()
      ..color = _getPhaseColor(phase)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Draw pose connections (simplified skeleton)
    _drawConnection(canvas, paint, 'nose', 'left_eye');
    _drawConnection(canvas, paint, 'nose', 'right_eye');
    _drawConnection(canvas, paint, 'left_eye', 'left_ear');
    _drawConnection(canvas, paint, 'right_eye', 'right_ear');

    // Shoulders
    _drawConnection(canvas, paint, 'left_shoulder', 'right_shoulder');

    // Arms
    _drawConnection(canvas, paint, 'left_shoulder', 'left_elbow');
    _drawConnection(canvas, paint, 'left_elbow', 'left_wrist');
    _drawConnection(canvas, paint, 'right_shoulder', 'right_elbow');
    _drawConnection(canvas, paint, 'right_elbow', 'right_wrist');

    // Torso
    _drawConnection(canvas, paint, 'left_shoulder', 'left_hip');
    _drawConnection(canvas, paint, 'right_shoulder', 'right_hip');
    _drawConnection(canvas, paint, 'left_hip', 'right_hip');

    // Legs
    _drawConnection(canvas, paint, 'left_hip', 'left_knee');
    _drawConnection(canvas, paint, 'left_knee', 'left_ankle');
    _drawConnection(canvas, paint, 'right_hip', 'right_knee');
    _drawConnection(canvas, paint, 'right_knee', 'right_ankle');

    // Draw keypoints as circles
    final keyPointPaint = Paint()
      ..color = _getPhaseColor(phase)
      ..style = PaintingStyle.fill;

    keyPoints.forEach((key, point) {
      canvas.drawCircle(point, 4, keyPointPaint);
    });
  }

  void _drawConnection(
      Canvas canvas, Paint paint, String point1, String point2) {
    final p1 = keyPoints[point1];
    final p2 = keyPoints[point2];

    if (p1 != null && p2 != null) {
      canvas.drawLine(p1, p2, paint);
    }
  }

  Color _getPhaseColor(PushUpPhase phase) {
    switch (phase) {
      case PushUpPhase.up:
        return Colors.green;
      case PushUpPhase.goingDown:
        return Colors.yellow;
      case PushUpPhase.down:
        return Colors.orange;
      case PushUpPhase.goingUp:
        return Colors.blue;
      case PushUpPhase.unknown:
        return Colors.white.withOpacity(0.7);
    }
  }

  @override
  bool shouldRepaint(_PoseSkeletonPainter oldDelegate) {
    return oldDelegate.keyPoints != keyPoints || oldDelegate.phase != phase;
  }
}
