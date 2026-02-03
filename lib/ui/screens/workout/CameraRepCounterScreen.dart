import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../../state/pushin_app_controller.dart';
import '../../../services/CameraWorkoutService.dart';
import '../../../services/PoseDetectionService.dart';
import '../../widgets/PressAnimationButton.dart';
import '../../widgets/pill_navigation_bar.dart';
import 'WorkoutCompletionScreen.dart';

/// Camera-based Rep Counter Screen with automatic push-up detection
///
/// Features:
/// - Full-screen camera preview as background
/// - Real-time pose detection with skeleton overlay
/// - Automatic rep counting using ML Kit
/// - Manual "+ Add Rep" fallback button
/// - Mode-specific theming (Cozy/Normal/Tuff)
/// - Progress ring with smooth animations
/// - Motivational messages
class CameraRepCounterScreen extends StatefulWidget {
  final String workoutType;
  final int targetReps;
  final int desiredScreenTimeMinutes;
  final String workoutMode; // 'cozy', 'normal', or 'tuff'

  const CameraRepCounterScreen({
    super.key,
    required this.workoutType,
    required this.targetReps,
    required this.desiredScreenTimeMinutes,
    this.workoutMode = 'normal',
  });

  @override
  State<CameraRepCounterScreen> createState() => _CameraRepCounterScreenState();
}

class _CameraRepCounterScreenState extends State<CameraRepCounterScreen>
    with TickerProviderStateMixin {
  late CameraWorkoutService _cameraService;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _currentReps = 0;
  int _elapsedSeconds = 0; // For time-based workouts
  bool _isInitialized = false;
  bool _isInitializing = true;
  bool _cameraFailed = false;
  String _errorMessage = '';
  bool _showManualButton = true;
  String _feedbackMessage = 'Position yourself in frame';
  dynamic _currentPhase = PushUpPhase.unknown; // Can be any phase enum

  // Workout initialization state
  bool _isFullBodyDetected = false;
  bool _isReadyToStart = false;
  bool _isPositioning = false; // In positioning state (starts immediately)
  bool _countdownTriggered = false; // Prevent duplicate countdown triggers
  int _countdownValue = 3;
  bool _isCountingDown = false;
  Timer? _countdownTimer;

  // Step completion state
  bool _step1Completed = false; // Phone positioned (stable)
  bool _step2Completed = false; // Full body visible
  bool _step3Completed = false; // Arms and legs in frame

  // Prevent duplicate workout completion calls
  bool _workoutCompleted = false;

  // Performance optimization: throttle UI updates
  DateTime? _lastPoseUpdateTime;
  static const Duration _poseUpdateThrottle =
      Duration(milliseconds: 100); // 10fps

  // Mode colors
  late Color _primaryColor;
  late Color _secondaryColor;

  @override
  void initState() {
    super.initState();
    _setupModeColors();
    _setupAnimations();

    // Reset rep count to ensure clean start
    _currentReps = 0;
    _elapsedSeconds = 0;
    _workoutCompleted = false;

    // Reset step completion states
    _step1Completed = false;
    _step2Completed = false;
    _step3Completed = false;

    _initializeCameraService();

    // Start workout in controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PushinAppController>().startWorkout(
            widget.workoutType,
            widget.targetReps,
            desiredScreenTimeMinutes: widget.desiredScreenTimeMinutes,
          );
    });
  }

  void _setupModeColors() {
    switch (widget.workoutMode.toLowerCase()) {
      case 'cozy':
        _primaryColor = const Color(0xFF10B981); // Green
        _secondaryColor = const Color(0xFF34D399);
        break;
      case 'tuff':
        _primaryColor = const Color(0xFFF59E0B); // Orange
        _secondaryColor = const Color(0xFFFBBF24);
        break;
      default: // normal
        _primaryColor = const Color(0xFF6060FF); // Purple
        _secondaryColor = const Color(0xFF9090FF);
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutBack),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
  }

  /// Check if this is a time-based workout (like plank)
  bool get _isTimeBased => widget.workoutType.toLowerCase() == 'plank';

  /// Get target value (reps or seconds)
  int get _targetValue => _isTimeBased
      ? widget.targetReps
      : widget.targetReps; // Dynamic seconds for plank

  /// Get current value (reps or seconds)
  int get _currentValue => _isTimeBased ? _elapsedSeconds : _currentReps;

  /// Format seconds to MM:SS
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _initializeCameraService() async {
    _cameraService = CameraWorkoutService();

    _cameraService.onRepCounted = (count) {
      debugPrint(
          '🎯 UI REP COUNT UPDATE: Received count $count, current _currentReps is $_currentReps');
      if (mounted) {
        setState(() {
          _currentReps = count;
        });
        debugPrint('✅ UI REP COUNT SET: _currentReps now $_currentReps');
        HapticFeedback.mediumImpact();
        _pulseController.forward().then((_) => _pulseController.reverse());

        if (!_isTimeBased && _currentReps >= widget.targetReps) {
          _completeWorkout();
        }
      }
    };

    _cameraService.onPoseUpdate = (result) {
      if (mounted) {
        final now = DateTime.now();
        final shouldUpdateUI = _lastPoseUpdateTime == null ||
            now.difference(_lastPoseUpdateTime!) >= _poseUpdateThrottle;

        final wasFullBodyDetected = _isFullBodyDetected;

        // Always update critical state variables for logic, but throttle UI updates
        _feedbackMessage = result.feedbackMessage ?? 'Keep going!';
        _currentPhase = result.phase;
        _isFullBodyDetected = result.isFullBodyDetected;
        _isReadyToStart = result.isReadyToStart;

        // Update step completion states
        if (_isPositioning) {
          // All steps complete when whole body is visible
          _step1Completed = _isFullBodyDetected;
          _step2Completed = _isFullBodyDetected;
          _step3Completed = _isFullBodyDetected;
        }

        // Only update UI if enough time has passed, or if critical state changes
        final criticalStateChanged =
            (wasFullBodyDetected != _isFullBodyDetected) ||
                (_isPositioning &&
                    !_isCountingDown); // Always update during positioning

        if (shouldUpdateUI || criticalStateChanged) {
          _lastPoseUpdateTime = now;
          setState(() {
            // State variables already updated above
          });
        }

        // Auto-start countdown when ready to start (during positioning state)
        if (_isPositioning &&
            !_isCountingDown &&
            !_countdownTriggered &&
            _isReadyToStart) {
          debugPrint(
              '🎯 Full body detected! Auto-starting workout countdown...');
          _countdownTriggered = true;
          _triggerAutoCountdown();
        }

        // Pause logic - if active and body leaves frame (always run, not throttled)
        if (_cameraService.poseDetectionService?.workoutState ==
            WorkoutState.active) {
          if (!_isFullBodyDetected || !_isReadyToStart) {
            _cameraService.poseDetectionService?.pauseWorkout();
          }
        }

        // Resume logic - if paused and body back in frame (always run, not throttled)
        if (_cameraService.poseDetectionService?.workoutState ==
            WorkoutState.paused) {
          if (_isFullBodyDetected && _isReadyToStart) {
            _cameraService.poseDetectionService?.resumeWorkout();
          }
        }
      }
    };

    _cameraService.onTimerUpdate = (seconds) {
      if (mounted) {
        setState(() {
          _elapsedSeconds = seconds;
        });

        // Check if time-based workout is complete
        if (_isTimeBased && _elapsedSeconds >= _targetValue) {
          _completeWorkout();
        }
      }
    };

    try {
      debugPrint('Starting camera initialization...');
      // Add timeout to prevent infinite loading - increased to 30 seconds
      final success = await _cameraService
          .initialize(workoutType: widget.workoutType)
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Camera initialization timed out after 30 seconds');
          return false;
        },
      );

      debugPrint('Camera initialization result: $success');

      if (success && mounted) {
        debugPrint('Starting workout...');
        await _cameraService.startWorkout();
        setState(() {
          _isInitialized = true;
          _isInitializing = false;
          // Automatically enter positioning state
          _isPositioning = true;
        });
        _fadeController.forward();

        // Step 1 will be completed when we start receiving valid pose detection data

        // Notify pose detection service to enter positioning state immediately
        _cameraService.poseDetectionService?.enterPositioningState();

        debugPrint('Camera initialized successfully');
      } else {
        // Camera initialization failed
        debugPrint(
            'Camera initialization failed. Error: ${_cameraService.errorMessage}');
        if (mounted) {
          String errorMsg = _cameraService.errorMessage ??
              'Camera initialization failed. You can still count reps manually.';

          // Provide more helpful message for permission denied
          if (_cameraService.errorMessage?.contains('permission denied') ??
              false) {
            errorMsg =
                'Camera permission is required for AI rep counting. Please enable camera access in Settings > Privacy > Camera, then tap "Retry Camera". You can still count reps manually.';
          }

          setState(() {
            _isInitializing = false;
            _cameraFailed = true;
            _errorMessage = errorMsg;
          });
        }
      }
    } catch (e) {
      // Handle any exceptions during initialization
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

  void _addManualRep() {
    // For time-based workouts like plank, manually add 1 second
    if (_isTimeBased) {
      _cameraService.addManualSecond();
      setState(() {
        _elapsedSeconds = _cameraService.elapsedSeconds;
      });

      HapticFeedback.lightImpact();

      if (_elapsedSeconds >= _targetValue) {
        _completeWorkout();
      }
      return;
    }

    // For rep-based workouts
    if (_currentReps < widget.targetReps) {
      _cameraService.addManualRep();
      setState(() {
        _currentReps = _cameraService.repCount;
      });

      HapticFeedback.mediumImpact();
      _pulseController.forward().then((_) => _pulseController.reverse());

      if (_currentReps >= widget.targetReps) {
        _completeWorkout();
      }
    }
  }

  void _completeWorkout() async {
    // Prevent duplicate completion calls
    if (_workoutCompleted) {
      debugPrint('⚠️ _completeWorkout called but workout already completed');
      return;
    }

    _workoutCompleted = true;

    await _cameraService.stopWorkout();
    final controller = context.read<PushinAppController>();
    await controller.completeWorkout(_currentReps);

    if (!mounted) return;

    // Use push instead of pushReplacement to keep CameraRepCounterScreen in stack
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutCompletionScreen(
          workoutType: widget.workoutType,
          completedReps: _currentReps,
          earnedMinutes: widget.desiredScreenTimeMinutes,
        ),
      ),
    );
  }

  void _cancelWorkout() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(
                    0x99000000), // Same glass color as positioning overlay
                border: Border.all(color: Colors.white.withOpacity(0.1)),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  // Cancel Icon
                  Image.asset(
                    'assets/icons/cancel_icon.png',
                    width: 36,
                    height: 36,
                    color: const Color(0xFFEF4444),
                  ),
                  const SizedBox(height: 16),
                  // Title with improved typography
                  Text(
                    'Cancel Workout?',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  // Subtitle with improved styling
                  Text(
                    'Your progress will be lost!',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.4,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Buttons with enhanced styling
                  Row(
                    children: [
                      Expanded(
                        child: PressAnimationButton(
                          onTap: () async {
                            await _cameraService.stopWorkout();
                            if (mounted) {
                              context
                                  .read<PushinAppController>()
                                  .cancelWorkout();
                              Navigator.pop(context);
                              Navigator.pop(context);
                            }
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444), // Red color
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFEF4444).withOpacity(0.4),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: PressAnimationButton(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Continue',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2A2A6A),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    _cameraService.poseDetectionService?.startCountdown();

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
        });

        // Activate workout in pose detection service
        _cameraService.poseDetectionService?.activateWorkout();

        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraService.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _currentValue >= _targetValue;

    return WillPopScope(
      onWillPop: () async {
        // Cancel workout when user presses back button (Android)
        await _cameraService.stopWorkout();
        if (mounted) {
          context.read<PushinAppController>().cancelWorkout();
        }
        return true; // Allow navigation back
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Camera preview background
            _buildCameraPreview(),

            // Gradient overlay for better text visibility
            _buildGradientOverlay(),

            // Pose skeleton overlay
            if (_isInitialized && !_cameraFailed) _buildPoseOverlay(),

            // Main UI content (Header and Counter) - hide during positioning and countdown
            if (!_isPositioning && !_isCountingDown)
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Header
                      _buildHeader(),

                      // Small rep counter below header
                      _buildSmallRepCounter(),

                      // Large spacer for camera visibility
                      const Spacer(),
                    ],
                  ),
                ),
              ),

            // Bottom action buttons positioned at navigation pill level - hide during positioning and countdown
            if (!_isPositioning && !_isCountingDown)
              BottomActionContainer(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildBottomSectionWithFeedback(isComplete),
                ),
              ),

            // Positioning instructions overlay (show immediately when entering workout)
            if (_isPositioning && !_isCountingDown) _buildPositioningOverlay(),

            // Back button for positioning mode (top left) - hide when ready to avoid visual distraction
            if (_isPositioning && !_isCountingDown && !_isReadyToStart)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () async {
                      // Cancel the workout when navigating back
                      await _cameraService.stopWorkout();
                      if (mounted) {
                        context.read<PushinAppController>().cancelWorkout();
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),

            // Countdown overlay (3-2-1)
            if (_isCountingDown) _buildCountdownOverlay(),

            // Loading overlay
            (_isInitializing || _cameraFailed)
                ? _buildLoadingOverlay()
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  /// Build positioning instructions overlay with Google-designed glassmorphism UI
  Widget _buildPositioningOverlay() {
    final isReady = _isReadyToStart;

    // Premium color palette
    const accentColor = Color(0xFF10B981); // Emerald Green
    const glassColor = Color(0x99000000); // Dark semi-transparent black

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      color: Colors.black.withOpacity(0.1), // Very subtle scrim
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // CAMERA VIEWFINDER FRAME
              Expanded(
                flex: 7, // Takes up ~70% of vertical space visually
                child: _buildScannerFrame(isReady, accentColor),
              ),

              const SizedBox(height: 20),

              // INSTRUCTION HUD / STATUS CARD
              Expanded(
                flex: 3,
                child: _buildInstructionHUD(isReady, accentColor, glassColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET: The Camera Scanner Frame ---
  Widget _buildScannerFrame(bool isReady, Color accentColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        // Subtle background to highlight the active area
        color: isReady ? accentColor.withOpacity(0.1) : Colors.transparent,
        border: Border.all(
          color: isReady ? accentColor : Colors.white.withOpacity(0.3),
          width: isReady ? 4 : 2,
        ),
        borderRadius: BorderRadius.circular(24),
        // Add a glow effect when ready
        boxShadow: isReady
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Corner accents (Visual flair for 'Scanner' look)
          if (!isReady) ...[
            Positioned(top: 20, left: 20, child: _buildCorner(0)),
            Positioned(top: 20, right: 20, child: _buildCorner(1)),
            Positioned(bottom: 20, left: 20, child: _buildCorner(2)),
            Positioned(bottom: 20, right: 20, child: _buildCorner(3)),
          ],

          // Center Icon / Animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: isReady
                ? Container(
                    key: const ValueKey('Success'),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 64,
                      color: accentColor,
                    ),
                  )
                : Opacity(
                    key: const ValueKey('Guidance'),
                    opacity: 0.8,
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Colors.white.withOpacity(0.3),
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        'assets/icons/body_cutout.png',
                        width: MediaQuery.of(context).size.width * 0.35,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(int index) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: (index < 2)
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          bottom: (index >= 2)
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          left: (index % 2 == 0)
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
          right: (index % 2 != 0)
              ? const BorderSide(color: Colors.white, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }

  // --- WIDGET: The Bottom Instruction Glass Card ---
  Widget _buildInstructionHUD(
      bool isReady, Color accentColor, Color glassColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: glassColor,
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: isReady
                ? _buildReadyMessage(accentColor)
                : _buildStepsList(accentColor),
          ),
        ),
      ),
    );
  }

  Widget _buildReadyMessage(Color accentColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Perfect!",
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: accentColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Hold steady, starting workout...",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsList(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Hug content
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Position Yourself',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'AI Camera',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 1.0,
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 16),

        // Steps
        _buildStepRow(
          icon: Icons.smartphone_rounded,
          text: 'Place phone 2-3 feet away',
          isCompleted: _step1Completed,
          accentColor: accentColor,
        ),
        const SizedBox(height: 12),
        _buildStepRow(
          icon: Icons.accessibility_new_rounded,
          text: 'Step back until full body is visible',
          isCompleted: _step2Completed,
          accentColor: accentColor,
        ),
        const SizedBox(height: 12),
        _buildStepRow(
          icon: Icons.fit_screen_rounded,
          text: 'Ensure arms and legs are in frame',
          isCompleted: _step3Completed,
          accentColor: accentColor,
        ),
      ],
    );
  }

  Widget _buildStepRow({
    required IconData icon,
    required String text,
    required bool isCompleted,
    required Color accentColor,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity:
          isCompleted ? 1.0 : 0.7, // Dim unfinished steps slightly for focus
      child: Row(
        children: [
          // Icon Container
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted ? accentColor : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isCompleted ? accentColor : Colors.white.withOpacity(0.3),
              ),
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              size: 18,
              color: isCompleted ? Colors.white : Colors.white,
            ),
          ),
          const SizedBox(width: 16),

          // Text
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                color:
                    isCompleted ? Colors.white : Colors.white.withOpacity(0.8),
                decoration: isCompleted ? TextDecoration.none : null,
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }

  /// Build countdown overlay with large number
  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large countdown number
            TweenAnimationBuilder<double>(
              key: ValueKey(
                  _countdownValue), // Unique key for each countdown value
              tween: Tween(begin: 0.8, end: 1.2),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.5),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$_countdownValue',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Get Ready text
            Text(
              'Get Ready!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Workout starts in $_countdownValue...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized ||
        _cameraService.cameraController == null ||
        _cameraFailed) {
      return Container(color: Colors.black);
    }

    final controller = _cameraService.cameraController!;
    final size = MediaQuery.of(context).size;

    // Calculate scale to fill screen while maintaining aspect ratio
    final scale = size.aspectRatio * controller.value.aspectRatio;
    final fixedScale = scale < 1 ? 1 / scale : scale;

    return Transform.scale(
      scale: fixedScale,
      child: Center(
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.3),
            Colors.black.withOpacity(0.8),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildPoseOverlay() {
    final result = _cameraService.lastResult;
    if (!result.isPoseDetected || result.keyPoints.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _PoseOverlayPainter(
        keyPoints: result.keyPoints,
        phase: result.phase,
        primaryColor: _primaryColor,
        workoutType: widget.workoutType,
        cameraController: _cameraService.cameraController,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Close button
          GestureDetector(
            onTap: _cancelWorkout,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                color: Colors.white.withOpacity(0.9),
                size: 24,
              ),
            ),
          ),

          const Spacer(),

          // Workout name
          Column(
            children: [
              Text(
                _getWorkoutDisplayName(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ],
          ),

          const Spacer(),

          // AI detection indicator with ready state
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _cameraFailed
                  ? Colors.red.withOpacity(0.2)
                  : _isReadyToStart
                      ? const Color(0xFF10B981)
                          .withOpacity(0.3) // Green when ready
                      : _isFullBodyDetected
                          ? const Color(0xFFF59E0B)
                              .withOpacity(0.3) // Orange when body detected
                          : Colors.black
                              .withOpacity(0.4), // Gray when not detected
              shape: BoxShape.circle,
              border: _isReadyToStart
                  ? Border.all(
                      color: const Color(0xFF10B981),
                      width: 2,
                    )
                  : null,
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: Image.asset(
                  'assets/icons/body_cutout.png',
                  fit: BoxFit.contain,
                  color: _cameraFailed
                      ? Colors.red
                      : _isReadyToStart
                          ? const Color(0xFF10B981)
                          : _isFullBodyDetected
                              ? const Color(0xFFF59E0B)
                              : Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallRepCounter() {
    final progress = _currentValue / _targetValue;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: CustomPaint(
          painter: _ProgressBorderPainter(
            progress: progress,
            primaryColor: _primaryColor,
            secondaryColor: _secondaryColor,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current value (reps or time) in gradient
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    _isTimeBased
                        ? _formatTime(_currentValue)
                        : '$_currentValue',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _isTimeBased
                      ? '/${_formatTime(_targetValue)}'
                      : '/$_targetValue',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.4),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSectionWithFeedback(bool isComplete) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Positioning instruction with workout icon
        !isComplete &&
                (_isPositioning ||
                    _cameraService.poseDetectionService?.workoutState ==
                        WorkoutState.active ||
                    _cameraService.poseDetectionService?.workoutState ==
                        WorkoutState.paused)
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: _primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      _getWorkoutIconPath(),
                      width: 24,
                      height: 24,
                      color: _primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getPositioningInstruction(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),

        // MAIN BUTTON LOGIC
        isComplete
            // Workout complete button
            ? PressAnimationButton(
                onTap: () {},
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                    ),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Workout Complete!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : (_cameraService.poseDetectionService?.workoutState ==
                            WorkoutState.active ||
                        _cameraService.poseDetectionService?.workoutState ==
                            WorkoutState.paused) &&
                    (_showManualButton && (_isInitialized || _cameraFailed))
                // Manual rep button (during active workout)
                ? PressAnimationButton(
                    onTap: _addManualRep,
                    child: Container(
                      width: double.infinity,
                      height: 60,
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
                          _isTimeBased ? 'Hold Position' : '+ Add Rep',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A2A6A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    if (_cameraFailed) {
      return Container(
        color: Colors.black.withOpacity(0.9),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Camera Unavailable',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 32),
                PressAnimationButton(
                  onTap: () async {
                    // If permission was denied, open app settings
                    if (_cameraService.errorMessage
                            ?.contains('permission denied') ??
                        false) {
                      await openAppSettings();
                    }

                    setState(() {
                      _cameraFailed = false;
                      _isInitializing = true;
                    });
                    _initializeCameraService();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: _primaryColor,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (_cameraService.errorMessage
                                    ?.contains('permission denied') ??
                                false)
                            ? 'Open Settings'
                            : 'Retry Camera',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Or continue with manual counting',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Preparing camera...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Position yourself in frame for best detection',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWorkoutDisplayName() {
    return widget.workoutType.split('-').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _getWorkoutIconPath() {
    switch (widget.workoutType.toLowerCase()) {
      case 'push-ups':
        return 'assets/icons/pushup_icon.png';
      case 'squats':
        return 'assets/icons/squats_icon.png';
      case 'plank':
        return 'assets/icons/plank_icon.png';
      case 'jumping-jacks':
        return 'assets/icons/jumping_jacks_icon.png';
      case 'burpees':
        return 'assets/icons/pushup_icon.png'; // Use pushup icon as fallback for burpees
      case 'glute-bridge':
        return 'assets/icons/glutebridge_icon.png';
      default:
        return 'assets/icons/pushup_icon.png';
    }
  }

  String _getPositioningInstruction() {
    switch (widget.workoutType.toLowerCase()) {
      case 'push-ups':
        return 'Face the camera from the side';
      case 'squats':
        return 'Face the camera from the side';
      case 'plank':
        return 'Face the camera from the side';
      case 'jumping-jacks':
        return 'Face the camera from the front';
      case 'burpees':
        return 'Face the camera from the side';
      case 'glute-bridge':
        return 'Face the camera from the side';
      default:
        return 'Face the camera from the front';
    }
  }
}

/// Custom painter for animated progress border around counter pill
class _ProgressBorderPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  _ProgressBorderPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    );
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(size.height / 2));

    // Background border (unfilled)
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(rrect, backgroundPaint);

    // Progress border (filled portion)
    if (progress > 0) {
      // Glow effect
      final glowPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            primaryColor.withOpacity(0.5),
            secondaryColor.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final progressPaint = Paint()
        ..shader = LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      // Create path that follows the pill perimeter
      final metrics = _createPillPath(rrect).computeMetrics().first;
      final extractPath = metrics.extractPath(0, metrics.length * progress);

      canvas.drawPath(extractPath, glowPaint);
      canvas.drawPath(extractPath, progressPaint);
    }
  }

  Path _createPillPath(RRect rrect) {
    final path = Path();
    final rect = rrect.outerRect;
    final radius = rrect.tlRadius.x;

    // Start from top center, go clockwise
    path.moveTo(rect.center.dx, rect.top);

    // Top right to right side
    path.lineTo(rect.right - radius, rect.top);
    path.arcToPoint(
      Offset(rect.right, rect.top + radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );

    // Right side
    path.lineTo(rect.right, rect.bottom - radius);

    // Bottom right arc
    path.arcToPoint(
      Offset(rect.right - radius, rect.bottom),
      radius: Radius.circular(radius),
      clockwise: true,
    );

    // Bottom
    path.lineTo(rect.left + radius, rect.bottom);

    // Bottom left arc
    path.arcToPoint(
      Offset(rect.left, rect.bottom - radius),
      radius: Radius.circular(radius),
      clockwise: true,
    );

    // Left side
    path.lineTo(rect.left, rect.top + radius);

    // Top left arc
    path.arcToPoint(
      Offset(rect.left + radius, rect.top),
      radius: Radius.circular(radius),
      clockwise: true,
    );

    // Back to top center
    path.lineTo(rect.center.dx, rect.top);

    return path;
  }

  @override
  bool shouldRepaint(_ProgressBorderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Custom painter for pose skeleton overlay
class _PoseOverlayPainter extends CustomPainter {
  final Map<String, Offset> keyPoints;
  final dynamic phase;
  final Color primaryColor;
  final CameraController? cameraController;
  final String workoutType;

  _PoseOverlayPainter({
    required this.keyPoints,
    required this.phase,
    required this.primaryColor,
    required this.workoutType,
    this.cameraController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (keyPoints.isEmpty) return;

    final paint = Paint()
      ..color = primaryColor.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

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
          ..color = primaryColor.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );

      // Draw inner point
      canvas.drawCircle(scaledPoint, 5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(_PoseOverlayPainter oldDelegate) {
    return oldDelegate.keyPoints != keyPoints || oldDelegate.phase != phase;
  }
}
