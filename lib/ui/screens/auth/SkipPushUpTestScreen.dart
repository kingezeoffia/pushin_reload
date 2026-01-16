import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../state/auth_state_provider.dart';
import '../../../services/CameraWorkoutService.dart';
import '../../widgets/GOStepsBackground.dart';
import '../../widgets/PressAnimationButton.dart';
import 'SkipPushUpSuccessScreen.dart';

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

/// Skip Flow: Workout Try-Out Screen
///
/// Simplified version for users who skip onboarding
/// Handles all workout types dynamically
class SkipPushUpTestScreen extends StatefulWidget {
  final List<String> blockedApps;
  final String selectedWorkout;

  const SkipPushUpTestScreen({
    super.key,
    required this.blockedApps,
    required this.selectedWorkout,
  });

  @override
  State<SkipPushUpTestScreen> createState() => _SkipPushUpTestScreenState();
}

class _SkipPushUpTestScreenState extends State<SkipPushUpTestScreen>
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

  // Dynamic workout properties based on selected workout
  late String _workoutType;
  late int _targetReps;
  late String _workoutTitle;
  late String _workoutInstructions;

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
  static const Duration _stabilityDuration =
      Duration(milliseconds: 1500); // 1.5 seconds stable

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWorkoutProperties();
    _initializeCameraService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _stabilityTimer?.cancel();
    _cameraService?.dispose();
    super.dispose();
  }

  void _initializeWorkoutProperties() {
    final selectedWorkout = widget.selectedWorkout.toLowerCase();

    switch (selectedWorkout) {
      case 'push-ups':
        _workoutType = 'push-ups';
        _targetReps = 3;
        _workoutTitle = 'Push-Up Test';
        _workoutInstructions = 'Do 3 push-ups to test the workout detection';
        break;
      case 'squats':
        _workoutType = 'squats';
        _targetReps = 3;
        _workoutTitle = 'Squat Test';
        _workoutInstructions = 'Do 3 squats to test the workout detection';
        break;
      case 'glute bridge':
        _workoutType = 'glute-bridge';
        _targetReps = 3;
        _workoutTitle = 'Glute Bridge';
        _workoutInstructions =
            'Do 3 glute bridges to test the workout detection';
        break;
      case 'plank':
        _workoutType = 'plank';
        _targetReps = 1; // Will be overridden by timer logic
        _workoutTitle = 'Plank Test';
        _workoutInstructions =
            'Hold a plank for 5 seconds to test the workout detection';
        break;
      case 'jumping jacks':
        _workoutType = 'jumping-jacks';
        _targetReps = 3;
        _workoutTitle = 'Jumping Jacks';
        _workoutInstructions =
            'Do 3 jumping jacks to test the workout detection';
        break;
      default:
        // Fallback to push-ups
        _workoutType = 'push-ups';
        _targetReps = 3;
        _workoutTitle = 'Push-Up Test';
        _workoutInstructions = 'Do 3 push-ups to test the workout detection';
    }

    debugPrint(
        'Initialized workout: $_workoutType, target: $_targetReps, title: $_workoutTitle');
  }

  String _getPositioningMessage() {
    switch (_workoutType) {
      case 'jumping-jacks':
        return 'Show full body facing the camera';
      case 'push-ups':
      case 'squats':
      case 'glute-bridge':
      case 'plank':
      default:
        return 'Show full body from the side';
    }
  }

  String _getPositionText() {
    switch (_workoutType) {
      case 'push-ups':
        return 'Get in Push-Up position';
      case 'squats':
        return 'Get in Squat position';
      case 'glute-bridge':
        return 'Lie on your back';
      case 'plank':
        return 'Get in Plank position';
      case 'jumping-jacks':
        return 'Stand with feet together';
      default:
        return 'Get in position';
    }
  }

  String _getWorkoutIconPath() {
    switch (_workoutType) {
      case 'push-ups':
        return 'assets/icons/pushup_icon.png';
      case 'squats':
        return 'assets/icons/squats_icon.png';
      case 'glute-bridge':
        return 'assets/icons/glutebridge_icon.png';
      case 'plank':
        return 'assets/icons/plank_icon.png';
      case 'jumping-jacks':
        return 'assets/icons/jumping_jacks_icon.png';
      default:
        return 'assets/icons/pushup_icon.png';
    }
  }

  IconData _getWorkoutFallbackIcon() {
    switch (_workoutType) {
      case 'push-ups':
        return Icons.fitness_center;
      case 'squats':
        return Icons.airline_seat_legroom_normal;
      case 'glute-bridge':
        return Icons.accessibility_new;
      case 'plank':
        return Icons.self_improvement;
      case 'jumping-jacks':
        return Icons.sports_gymnastics;
      default:
        return Icons.fitness_center;
    }
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
      if (mounted && _workoutType != 'plank') {
        // Only handle reps for non-plank workouts
        debugPrint('🎯 AI DETECTED REP: $count (target: $_targetReps)');
        setState(() {
          _detectedReps = count;
        });
        HapticFeedback.mediumImpact();
        debugPrint('🔢 Updated rep count: $_detectedReps');

        if (_detectedReps >= _targetReps && !_hasCompleted) {
          debugPrint(
              '🎉 COMPLETED! Reps: $_detectedReps >= $_targetReps, showing success screen');
          _hasCompleted = true;
          _showSuccessScreen();
        } else {
          debugPrint(
              '⏳ Not completed yet: $_detectedReps < $_targetReps or already completed: $_hasCompleted');
        }
      }
    };

    _cameraService!.onTimerUpdate = (seconds) {
      if (mounted && _workoutType == 'plank') {
        // Only handle timer for plank
        debugPrint('⏱️ TIMER UPDATE: $seconds seconds (target: 5)');
        setState(() {
          _detectedReps =
              seconds; // Use _detectedReps to show progress for plank too
        });

        if (seconds >= 5 && !_hasCompleted) {
          debugPrint('🎉 COMPLETED! Plank held for $seconds >= 5 seconds');
          _hasCompleted = true;
          _showSuccessScreen();
        }
      }
    };

    _cameraService!.onPoseUpdate = (result) {
      if (mounted) {
        debugPrint(
            '🤖 POSE UPDATE: ${result.feedbackMessage}, phase: ${result.phase}, detected: ${result.isPoseDetected}, keypoints: ${result.keyPoints.length}');
        final wasReady = _isReadyToStart;
        setState(() {
          _feedbackMessage = result.feedbackMessage ?? 'Keep going!';
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
          'Starting camera initialization for skip flow with $_currentCameraLens camera...');
      final success = await _cameraService!
          .initialize(
        workoutType: _workoutType,
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
        debugPrint('Starting push-up test workout for skip flow...');
        await _cameraService!.startWorkout();
        debugPrint(
            'Workout started, service state: ${_cameraService!.state}, isReady: ${_cameraService!.isReady}');
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
        });
        debugPrint(
            'Camera initialized successfully for skip flow - AI detection should now be active!');
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

  /// User pressed START - enter positioning state (always allowed)
  void _startDetection() {
    if (_userPressedStart || _isCountingDown) return;

    debugPrint('🎬 STARTING DETECTION - Entering positioning state');
    setState(() {
      _userPressedStart = true;
      _isPositioning = true;
      _showInstructions = false; // Hide instructions when positioning starts
    });

    // Notify pose detection service to enter positioning state
    _cameraService!.poseDetectionService?.enterPositioningState();

    HapticFeedback.mediumImpact();
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
    Navigator.push(
      context,
      _NoSwipeBackRoute(
        builder: (context) => SkipPushUpSuccessScreen(
          blockedApps: widget.blockedApps,
          selectedWorkout: widget.selectedWorkout,
        ),
      ),
    );
  }

  void _manualRepCount() async {
    final targetValue = _workoutType == 'plank' ? 5 : _targetReps;

    if (_detectedReps < targetValue) {
      // Wenn Kamera aktiv ist, verwende den Service-Zähler
      if (_cameraService != null && _cameraService!.isReady) {
        if (_workoutType == 'plank') {
          // For plank, manually add a second
          setState(() {
            _detectedReps++;
          });
        } else {
          _cameraService!.addManualRep();
          // Der onRepCounted Callback wird automatisch _detectedReps aktualisieren
        }
      } else {
        // Wenn Kamera nicht aktiv, erhöhe manuell
        setState(() {
          _detectedReps++;
        });
      }
    }

    if (_detectedReps >= targetValue && !_hasCompleted) {
      _hasCompleted = true;

      // Brief pause to let user register the completion
      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        _showSuccessScreen();
      }
    }
  }

  void _continueToNextScreen() {
    final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
    authProvider.advanceGuestSetupStep();
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
                child: CameraPreview(controller),
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
      size: MediaQuery.of(context).size,
      painter: _PoseSkeletonPainter(
        keyPoints: result.keyPoints,
        phase: result.phase,
        cameraController: _cameraService?.cameraController,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthStateProvider>(context);
    print(
        '🧪 SkipPushUpTestScreen - justRegistered=${authProvider.justRegistered}, '
        'isGuestMode=${authProvider.isGuestMode}, '
        'guestCompletedSetup=${authProvider.guestCompletedSetup}');

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
                        _workoutTitle,
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
                      _workoutInstructions,
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
                                        _getWorkoutIconPath(),
                                        color: Colors.white24,
                                        width: 64,
                                        height: 64,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            _getWorkoutFallbackIcon(),
                                            color: Colors.white24,
                                            size: 64,
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                // Pose skeleton overlay - moved outside camera preview for visibility
                                if (_isInitialized && !_cameraFailed)
                                  _buildPoseSkeletonOverlay(),

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
                                            _getWorkoutIconPath(),
                                            color:
                                                Colors.white.withOpacity(0.8),
                                            width: 48,
                                            height: 48,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Icon(
                                                _getWorkoutFallbackIcon(),
                                                color: Colors.white
                                                    .withOpacity(0.8),
                                                size: 48,
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _getPositionText(),
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

                                // Positioning Overlay (after start pressed, waiting for pose)
                                if (!_showInstructions &&
                                    _isPositioning &&
                                    !_isCountingDown)
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
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                letterSpacing: -0.2,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getPositioningMessage(),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white
                                                    .withOpacity(0.8),
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
                                                  _workoutType == 'plank'
                                                      ? '${_detectedReps}s'
                                                      : '$_detectedReps',
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
                                        ? const Color(0xFF6060FF)
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
                                            ? Colors.white
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
                      else if (_isPositioning ||
                          _isCountingDown ||
                          _workoutActive)
                        // Button that changes based on state
                        Container(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Center(
                            child: _workoutActive
                                ? _ManualCountButton(onTap: _manualRepCount)
                                : _SkipWorkoutButton(
                                    onTap: () {
                                      // Navigate to success screen, skipping the workout
                                      Navigator.push(
                                        context,
                                        _NoSwipeBackRoute(
                                          builder: (context) =>
                                              SkipPushUpSuccessScreen(
                                            blockedApps: widget.blockedApps,
                                            selectedWorkout:
                                                widget.selectedWorkout,
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

              // Skip for now button (minimal, non-prominent) - hidden during detection
              if (_showInstructions)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
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

/// Back Button Widget

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
  final CameraController? cameraController;

  _PoseSkeletonPainter({
    required this.keyPoints,
    required this.phase,
    this.cameraController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (keyPoints.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF6060FF).withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Scale factor for converting pose coordinates to screen coordinates
    double scaleX = size.width;
    double scaleY = size.height;

    if (cameraController != null && cameraController!.value.isInitialized) {
      final previewSize = cameraController!.value.previewSize!;
      scaleX = size.width / previewSize.height;
      scaleY = size.height / previewSize.width;
    }

    // Check if we should mirror coordinates (only for back camera)
    final shouldMirror =
        cameraController?.description.lensDirection == CameraLensDirection.back;

    // Define connections for upper body (relevant for push-ups)
    final connections = [
      ['leftShoulder', 'rightShoulder'],
      ['leftShoulder', 'leftElbow'],
      ['leftElbow', 'leftWrist'],
      ['rightShoulder', 'rightElbow'],
      ['rightElbow', 'rightWrist'],
      ['leftShoulder', 'leftHip'],
      ['rightShoulder', 'rightHip'],
      ['leftHip', 'rightHip'],
    ];

    // Draw connections
    for (final connection in connections) {
      final point1Name = connection[0];
      final point2Name = connection[1];

      final point1 = keyPoints[point1Name];
      final point2 = keyPoints[point2Name];

      if (point1 != null && point2 != null) {
        // Apply mirroring only for back camera (front camera preview is already mirrored)
        final p1 = Offset(
          shouldMirror ? size.width - (point1.dx * scaleX) : point1.dx * scaleX,
          point1.dy * scaleY,
        );
        final p2 = Offset(
          shouldMirror ? size.width - (point2.dx * scaleX) : point2.dx * scaleX,
          point2.dy * scaleY,
        );

        canvas.drawLine(p1, p2, paint);
      }
    }

    // Draw key points
    for (final entry in keyPoints.entries) {
      final point = entry.value;
      final scaledPoint = Offset(
        shouldMirror ? size.width - (point.dx * scaleX) : point.dx * scaleX,
        point.dy * scaleY,
      );

      // Draw outer glow
      canvas.drawCircle(
        scaledPoint,
        8,
        Paint()
          ..color = const Color(0xFF6060FF).withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );

      // Draw inner point
      canvas.drawCircle(scaledPoint, 5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(_PoseSkeletonPainter oldDelegate) {
    return oldDelegate.keyPoints != keyPoints || oldDelegate.phase != phase;
  }
}
