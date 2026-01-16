import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../theme/pushin_theme.dart';
import '../../../services/CameraWorkoutService.dart';
import '../../../services/PoseDetectionService.dart' show PlankPhase;
import 'HowItWorksWorkoutSuccessScreen.dart';

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

/// Step 2.4: Plank Test Screen
///
/// BMAD V6 Spec:
/// - Camera-based plank detection
/// - Time-based workout (5 seconds)
/// - Manual timer fallback
/// - Target: 5 seconds holding plank
class HowItWorksPlankTestScreen extends StatefulWidget {
  final String fitnessLevel;
  final List<String> goals;
  final String otherGoal;
  final String workoutHistory;
  final List<String> blockedApps;

  const HowItWorksPlankTestScreen({
    super.key,
    required this.fitnessLevel,
    required this.goals,
    required this.otherGoal,
    required this.workoutHistory,
    required this.blockedApps,
  });

  @override
  State<HowItWorksPlankTestScreen> createState() =>
      _HowItWorksPlankTestScreenState();
}

class _HowItWorksPlankTestScreenState extends State<HowItWorksPlankTestScreen>
    with WidgetsBindingObserver {
  CameraWorkoutService? _cameraService;
  bool _isInitialized = false;
  bool _isInitializing = true;
  bool _cameraFailed = false;
  String _errorMessage = '';
  int _elapsedSeconds = 0;
  bool _showInstructions = true;
  bool _hasCompleted = false;
  String _feedbackMessage = 'Position yourself in frame';
  Timer? _manualTimer;

  // Track current camera lens direction for switching
  CameraLensDirection _currentCameraLens = CameraLensDirection.front;

  // NEW: Workout initialization state (like main workout screen)
  bool _isFullBodyDetected = false;
  bool _isReadyToStart = false;
  bool _userPressedStart = false; // User intent - pressed START button
  bool _isPositioning = false; // In positioning state after START pressed
  bool _workoutActive = false; // Workout is actively counting
  int _countdownValue = 3;
  bool _isCountingDown = false;
  Timer? _countdownTimer;
  Timer? _stabilityTimer; // Timer to track stable pose before auto-countdown
  DateTime? _readyStateStartTime; // When pose became ready
  static const Duration _stabilityDuration = Duration(milliseconds: 1500); // 1.5 seconds stable

  // Target time for plank test
  static const int _targetSeconds = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameraService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualTimer?.cancel();
    _countdownTimer?.cancel();
    _stabilityTimer?.cancel();
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
      _manualTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraService();
    }
  }

  Future<void> _initializeCameraService() async {
    _cameraService = CameraWorkoutService();

    _cameraService!.onTimerUpdate = (seconds) {
      if (mounted) {
        setState(() {
          _elapsedSeconds = seconds;
        });

        if (_elapsedSeconds >= _targetSeconds && !_hasCompleted) {
          _hasCompleted = true;
          _showSuccessScreen();
        }
      }
    };

    _cameraService!.onPoseUpdate = (result) {
      if (mounted) {
        final wasReady = _isReadyToStart;
        setState(() {
          _feedbackMessage = result.feedbackMessage ?? 'Hold that plank!';
          _isFullBodyDetected = result.isFullBodyDetected;
          _isReadyToStart = result.isReadyToStart;
        });

        // Auto-countdown logic when in positioning state
        if (_isPositioning && !_isCountingDown) {
          if (_isReadyToStart) {
            // Pose is ready - track stability
            if (!wasReady) {
              // Just became ready - start tracking
              _readyStateStartTime = DateTime.now();
            } else {
              // Check if stable long enough
              final now = DateTime.now();
              if (_readyStateStartTime != null &&
                  now.difference(_readyStateStartTime!) >= _stabilityDuration) {
                // Stable for required duration - trigger countdown!
                _triggerAutoCountdown();
              }
            }
          } else {
            // Not ready - reset stability timer
            _readyStateStartTime = null;
          }
        }
      }
    };

    try {
      debugPrint(
          'Starting camera initialization for onboarding with $_currentCameraLens camera...');
      final success = await _cameraService!
          .initialize(
        workoutType: 'plank',
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
        debugPrint('Starting plank test workout...');
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
              'Camera initialization failed. You can still time manually.';

          if (_cameraService!.errorMessage?.contains('permission denied') ??
              false) {
            errorMsg =
                'Camera permission is required for AI timing. Please enable camera access in Settings > Privacy > Camera. You can still time manually.';
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
              'Camera error: $e. You can still time manually.';
        });
      }
    }
  }

  void _switchCamera() async {
    // Dispose current service
    await _cameraService?.dispose();
    _manualTimer?.cancel();

    // Switch camera lens direction
    setState(() {
      _currentCameraLens = _currentCameraLens == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      _isInitialized = false;
      _isInitializing = true;
      _elapsedSeconds = 0;
    });

    // Initialize with the new camera
    await _initializeCameraService();
  }

  /// User pressed START - enter positioning state (always allowed)
  void _startDetection() {
    if (_userPressedStart || _isCountingDown) return;

    setState(() {
      _userPressedStart = true;
      _isPositioning = true;
      _showInstructions = false; // Hide instructions when positioning starts
    });

    // Notify pose detection service to enter positioning state
    _cameraService!.poseDetectionService?.enterPositioningState();

    HapticFeedback.mediumImpact();
  }

  void _startManualTimer() {
    _manualTimer?.cancel();
    _manualTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });

        if (_elapsedSeconds >= _targetSeconds && !_hasCompleted) {
          _hasCompleted = true;
          timer.cancel();
          _showSuccessScreen();
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Auto-trigger countdown when pose is stable (called automatically)
  void _triggerAutoCountdown() {
    if (_isCountingDown) return;

    setState(() {
      _isCountingDown = true;
      _isPositioning = false; // Exit positioning state
      _countdownValue = 3;
    });

    // Notify pose detection service that countdown started
    _cameraService!.poseDetectionService?.startCountdown();

    HapticFeedback.heavyImpact();

    // Countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue > 1) {
        setState(() {
          _countdownValue--;
        });
        HapticFeedback.lightImpact();
      } else {
        // Countdown complete!
        timer.cancel();
        setState(() {
          _isCountingDown = false;
          _workoutActive = true; // Workout is now active
        });

        // Activate workout in pose detection service
        _cameraService!.poseDetectionService?.activateWorkout();

        HapticFeedback.heavyImpact();
      }
    });
  }

  void _showSuccessScreen() {
    _manualTimer?.cancel();
    _countdownTimer?.cancel();
    _stabilityTimer?.cancel();
    Navigator.push(
      context,
      _NoSwipeBackRoute(
        builder: (context) => HowItWorksWorkoutSuccessScreen(
          fitnessLevel: widget.fitnessLevel,
          goals: widget.goals,
          otherGoal: widget.otherGoal,
          workoutHistory: widget.workoutHistory,
          blockedApps: widget.blockedApps,
          workoutType: 'Plank',
        ),
      ),
    );
  }

  void _manualStartStop() {
    if (_manualTimer == null || !_manualTimer!.isActive) {
      _startManualTimer();
    } else {
      _manualTimer?.cancel();
      setState(() {
        _manualTimer = null;
      });
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
                        'Plank Test',
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
                      'Hold a plank for 5 seconds to test the workout detection',
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
                                    child: Center(
                                      child: Image.asset(
                                        'assets/icons/plank_icon.png',
                                        color: Colors.white24,
                                        width: 64,
                                        height: 64,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.self_improvement,
                                            color: Colors.white24,
                                            size: 64,
                                          );
                                        },
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
                                          Image.asset(
                                            'assets/icons/plank_icon.png',
                                            color: Colors.white.withOpacity(0.8),
                                            width: 48,
                                            height: 48,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                Icons.self_improvement,
                                                color: Colors.white.withOpacity(0.8),
                                                size: 48,
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Get in Plank position',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            'Forearms on ground, body straight',
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

                                // Positioning Overlay (after start pressed, waiting for pose)
                                if (!_showInstructions && _isPositioning && !_isCountingDown)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.3),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Position yourself in frame',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white.withOpacity(0.9),
                                                letterSpacing: -0.2,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Show full body from the side',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white.withOpacity(0.8),
                                                fontWeight: FontWeight.w400,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                // Countdown Overlay (3-2-1 countdown)
                                if (_isCountingDown)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.5),
                                      child: Center(
                                        child: Text(
                                          '$_countdownValue',
                                          style: const TextStyle(
                                            fontSize: 72,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Active Workout Overlay (when actually counting)
                                if (_workoutActive)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.3),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Timer display
                                            Container(
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6060FF)
                                                    .withOpacity(0.9),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '$_elapsedSeconds',
                                                  style: const TextStyle(
                                                    fontSize: 36,
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
                      else if (_isPositioning || _isCountingDown || _workoutActive)
                        // Button that changes based on state
                        Container(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Center(
                            child: _workoutActive
                                ? _ManualTimerButton(
                                    onTap: _manualStartStop,
                                    isRunning: _manualTimer?.isActive ?? false,
                                  )
                                : _SkipWorkoutButton(
                                    onTap: () {
                                      // Navigate to success screen, skipping the workout
                                      Navigator.push(
                                        context,
                                        _NoSwipeBackRoute(
                                          builder: (context) =>
                                              HowItWorksWorkoutSuccessScreen(
                                            fitnessLevel: widget.fitnessLevel,
                                            goals: widget.goals,
                                            otherGoal: widget.otherGoal,
                                            workoutHistory: widget.workoutHistory,
                                            blockedApps: widget.blockedApps,
                                            workoutType: 'Plank',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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


/// Manual Timer Button with play/pause functionality
class _ManualTimerButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isRunning;

  const _ManualTimerButton({
    required this.onTap,
    required this.isRunning,
  });

  @override
  State<_ManualTimerButton> createState() => _ManualTimerButtonState();
}

class _ManualTimerButtonState extends State<_ManualTimerButton> {
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
        child: Center(
          child: Icon(
            widget.isRunning ? Icons.pause : Icons.play_arrow,
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Skip Workout Button
class _SkipWorkoutButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SkipWorkoutButton({required this.onTap});

  @override
  State<_SkipWorkoutButton> createState() => _SkipWorkoutButtonState();
}

class _SkipWorkoutButtonState extends State<_SkipWorkoutButton> {
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
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.white.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
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
        child: const Text(
          'Skip Workout',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for drawing pose detection skeleton
class _PoseSkeletonPainter extends CustomPainter {
  final Map<String, Offset> keyPoints;
  final dynamic phase;

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

  Color _getPhaseColor(dynamic phase) {
    if (phase is PlankPhase) {
      switch (phase) {
        case PlankPhase.holding:
          return Colors.green;
        case PlankPhase.broken:
          return Colors.red;
        case PlankPhase.unknown:
          return Colors.white.withOpacity(0.7);
      }
    }
    return Colors.white.withOpacity(0.7);
  }

  @override
  bool shouldRepaint(_PoseSkeletonPainter oldDelegate) {
    return oldDelegate.keyPoints != keyPoints || oldDelegate.phase != phase;
  }
}