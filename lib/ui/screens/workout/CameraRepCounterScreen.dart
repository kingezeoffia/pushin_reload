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
import '../../../services/PhoneStabilityService.dart';
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
  late PhoneStabilityService _stabilityService;
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

  // NEW: Workout initialization state
  bool _isFullBodyDetected = false;
  bool _isReadyToStart = false;
  bool _isPositioning = false; // In positioning state (starts immediately)
  int _countdownValue = 3;
  bool _isCountingDown = false;
  Timer? _countdownTimer;
  Timer? _stabilityTimer; // Timer to track stable pose before auto-countdown
  Timer? _step2Timer; // Timer for step 2 countdown
  Timer? _step3Timer; // Timer for step 3 countdown
  DateTime? _readyStateStartTime; // When pose became ready

  // Step completion state
  bool _step1Completed = false; // Phone positioned (stable)
  bool _step2Completed = false; // Full body visible
  bool _step3Completed = false; // Arms and legs in frame

  // Step countdown state for visual feedback
  bool _step2CountingDown = false;
  bool _step3CountingDown = false;

  // Phone stability state for visual feedback
  StabilityState _currentStabilityState = StabilityState(isStable: false, isDetecting: false);

  // Prevent duplicate workout completion calls
  bool _workoutCompleted = false;
  static const Duration _stabilityDuration =
      Duration(milliseconds: 1500); // 1.5 seconds stable

  // Mode colors
  late Color _primaryColor;
  late Color _secondaryColor;
  late LinearGradient _modeGradient;

  @override
  void initState() {
    super.initState();
    _setupModeColors();
    _setupAnimations();
    _setupStabilityService();

    // Reset rep count to ensure clean start
    _currentReps = 0;
    _elapsedSeconds = 0;
    _workoutCompleted = false;

    // Reset step completion states
    _step1Completed = false;
    _step2Completed = false;
    _step3Completed = false;

    // Reset step countdown states
    _step2CountingDown = false;
    _step3CountingDown = false;

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
        _modeGradient = const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF34D399)],
        );
        break;
      case 'tuff':
        _primaryColor = const Color(0xFFF59E0B); // Orange
        _secondaryColor = const Color(0xFFFBBF24);
        _modeGradient = const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        );
        break;
      default: // normal
        _primaryColor = const Color(0xFF6060FF); // Purple
        _secondaryColor = const Color(0xFF9090FF);
        _modeGradient = const LinearGradient(
          colors: [Color(0xFF6060FF), Color(0xFF9090FF)],
        );
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

  void _setupStabilityService() {
    _stabilityService = PhoneStabilityService();

    // Listen for stability state changes
    _stabilityService.onStabilityStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _currentStabilityState = state;

          if (_isPositioning) {
            // Step 1 is completed when phone is stable and flat
            final step1ShouldBeCompleted = state.isStable;

            if (step1ShouldBeCompleted && !_step1Completed) {
              _step1Completed = true;
              debugPrint('Step 1 completed: Phone positioned and stable (stability detection)');
            } else if (!step1ShouldBeCompleted && _step1Completed) {
              // Reset step 1 if phone becomes unstable
              _step1Completed = false;
              debugPrint('Step 1 reset: Phone moved (stability detection)');
            }
          }
        });
      }
    });
  }

  void _startStep2Countdown() {
    _step2CountingDown = true;
    _step2Timer?.cancel();

    _step2Timer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isPositioning && _step2CountingDown) {
        setState(() {
          _step2Completed = true;
          _step2CountingDown = false;
        });
        debugPrint('Step 2 completed: Full body visible (after countdown)');
      }
    });

    debugPrint('Started Step 2 countdown');
  }

  void _resetStep2Countdown() {
    _step2CountingDown = false;
    _step2Timer?.cancel();
    debugPrint('Step 2 countdown reset');
  }

  void _startStep3Countdown() {
    _step3CountingDown = true;
    _step3Timer?.cancel();

    _step3Timer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isPositioning && _step3CountingDown) {
        setState(() {
          _step3Completed = true;
          _step3CountingDown = false;
        });
        debugPrint('Step 3 completed: Arms and legs in frame (after countdown)');
      }
    });

    debugPrint('Started Step 3 countdown');
  }

  void _resetStep3Countdown() {
    _step3CountingDown = false;
    _step3Timer?.cancel();
    debugPrint('Step 3 countdown reset');
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
        final wasReady = _isReadyToStart;
        setState(() {
          _feedbackMessage = result.feedbackMessage ?? 'Keep going!';
          _currentPhase = result.phase;
          _isFullBodyDetected = result.isFullBodyDetected;
          _isReadyToStart = result.isReadyToStart;

          // Update step completion states
          if (_isPositioning) {
            // Step 1: Phone positioned - now handled by PhoneStabilityService
            // (was: complete when full body is scanned)

            // Step 2: Full body visible - start countdown when detected
            if (_isFullBodyDetected && !_step2Completed && !_step2CountingDown) {
              _startStep2Countdown();
            } else if (!_isFullBodyDetected && _step2CountingDown) {
              // Reset if body leaves frame during countdown
              _resetStep2Countdown();
            }

            // Step 3: Arms and legs in frame - start countdown when ready
            if (_isReadyToStart && !_step3Completed && !_step3CountingDown) {
              _startStep3Countdown();
            } else if (!_isReadyToStart && _step3CountingDown) {
              // Reset if pose becomes invalid during countdown
              _resetStep3Countdown();
            }
          }
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

        // Pause logic - if active and body leaves frame
        if (_cameraService.poseDetectionService?.workoutState ==
            WorkoutState.active) {
          if (!_isFullBodyDetected || !_isReadyToStart) {
            _cameraService.poseDetectionService?.pauseWorkout();
          }
        }

        // Resume logic - if paused and body back in frame
        if (_cameraService.poseDetectionService?.workoutState ==
            WorkoutState.paused) {
          if (_isFullBodyDetected && _isReadyToStart) {
            _cameraService.poseDetectionService?.resumeWorkout();
          }
        }

        // Countdown interruption logic - if user moves away during countdown, cancel it and go back to positioning
        if (_isCountingDown && !_isFullBodyDetected) {
          debugPrint(
              'User moved away during countdown - canceling countdown and returning to positioning');
          // Cancel timer safely to prevent race conditions
          final timer = _countdownTimer;
          _countdownTimer = null;
          timer?.cancel();

          // Reset pose detection service state first
          _cameraService.poseDetectionService?.cancelCountdown();

          if (mounted) {
            setState(() {
              _isCountingDown = false;
              _isPositioning = true;
              _countdownValue = 3;
              _readyStateStartTime = null; // Reset stability tracking
              // Reset step completion states to ensure clean restart
              _step1Completed = false;
              _step2Completed = false;
              _step3Completed = false;

              // Reset step countdown states
              _step2CountingDown = false;
              _step3CountingDown = false;
              _step2Timer?.cancel();
              _step3Timer?.cancel();
            });
            debugPrint(
                '✅ Countdown interrupted successfully - back to positioning mode');
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

        // Start phone stability detection for step 1
        _stabilityService.startStabilityDetection();

        // Step 1 will be completed when phone stability is detected

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

    Navigator.pushReplacement(
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
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 48,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Cancel Workout?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your progress will be lost.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () async {
                        await _cameraService.stopWorkout();
                        if (mounted) {
                          context.read<PushinAppController>().cancelWorkout();
                          Navigator.pop(context);
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PressAnimationButton(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Center(
                          child: Text(
                            'Keep Going',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2A2A6A),
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

    // Stop stability detection when starting countdown
    _stabilityService.stopStabilityDetection();

    // Notify pose detection service that countdown started
    _cameraService.poseDetectionService?.startCountdown();

    HapticFeedback.heavyImpact();

    // Countdown timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Safety check - if timer was canceled, don't execute
      if (_countdownTimer != timer) return;

      if (_countdownValue > 1) {
        if (mounted) {
          setState(() {
            _countdownValue--;
          });
        }
        HapticFeedback.lightImpact();
      } else {
        // Countdown complete!
        timer.cancel();
        _countdownTimer = null;

        if (mounted) {
          setState(() {
            _isCountingDown = false;
          });
        }

        // Activate workout in pose detection service
        _cameraService.poseDetectionService?.activateWorkout();

        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _stabilityTimer?.cancel();
    _step2Timer?.cancel();
    _step3Timer?.cancel();
    _cameraService.dispose();
    _stabilityService.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentValue / _targetValue;
    final isComplete = _currentValue >= _targetValue;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview background
          _buildCameraPreview(),

          // Gradient overlay for better text visibility
          _buildGradientOverlay(),

          // Pose skeleton overlay
          if (_isInitialized && !_cameraFailed) _buildPoseOverlay(),

          // Main UI content (Header and Counter) - hide during positioning
          if (!_isPositioning)
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

          // Bottom action buttons positioned at navigation pill level - hide during positioning
          if (!_isPositioning)
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
                  onTap: () => Navigator.pop(context),
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
          padding: const EdgeInsets.all(16),
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
      key: const ValueKey('ReadyMessage'),
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
      key: const ValueKey('StepsList'),
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
          showStabilityProgress: _isPositioning && !_step1Completed,
        ),
        const SizedBox(height: 16),
        _buildStepRow(
          icon: Icons.accessibility_new_rounded,
          text: 'Step back until full body is visible',
          isCompleted: _step2Completed,
          accentColor: accentColor,
          showStep2Progress: _isPositioning && !_step2Completed,
        ),
        const SizedBox(height: 16),
        _buildStepRow(
          icon: Icons.fit_screen_rounded,
          text: 'Ensure arms and legs are in frame',
          isCompleted: _step3Completed,
          accentColor: accentColor,
          showStep3Progress: _isPositioning && !_step3Completed,
        ),
      ],
    );
  }

  Widget _buildStepRow({
    required IconData icon,
    required String text,
    required bool isCompleted,
    required Color accentColor,
    bool showStabilityProgress = false,
    bool showStep2Progress = false,
    bool showStep3Progress = false,
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
            child: (showStabilityProgress && _currentStabilityState.isDetecting && !isCompleted) ||
                     (showStep2Progress && _step2CountingDown && !isCompleted) ||
                     (showStep3Progress && _step3CountingDown && !isCompleted)
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  )
                : Icon(
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
      key: ValueKey(
          'countdown_$_countdownValue'), // Force rebuild on value change
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large countdown number with safe animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Container(
                key: ValueKey(_countdownValue), // Force animation restart
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
            child: Icon(
              _cameraFailed
                  ? Icons.visibility_off
                  : _isReadyToStart
                      ? Icons.check_circle
                      : _isFullBodyDetected
                          ? Icons.person
                          : Icons.person_outline,
              color: _cameraFailed
                  ? Colors.red
                  : _isReadyToStart
                      ? const Color(0xFF10B981)
                      : _isFullBodyDetected
                          ? const Color(0xFFF59E0B)
                          : Colors.white.withOpacity(0.5),
              size: 22,
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
        // Feedback message or positioning instructions
        !isComplete &&
                !_isCountingDown && // Don't show during countdown
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
                    _buildPhaseIndicator(),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _getMotivationalMessage(
                            progress: _currentReps / widget.targetReps),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildPhaseIndicator() {
    IconData icon;
    Color color;

    // Use string representation for generic phase detection
    final phaseStr = _currentPhase.toString().toLowerCase();

    if (phaseStr.contains('.up') && !phaseStr.contains('going')) {
      icon = Icons.arrow_downward_rounded;
      color = _primaryColor;
    } else if (phaseStr.contains('goingdown')) {
      icon = Icons.arrow_downward_rounded;
      color = _secondaryColor;
    } else if (phaseStr.contains('.down')) {
      icon = Icons.arrow_upward_rounded;
      color = _primaryColor;
    } else if (phaseStr.contains('goingup')) {
      icon = Icons.arrow_upward_rounded;
      color = _secondaryColor;
    } else if (phaseStr.contains('holding')) {
      // For plank
      icon = Icons.accessibility_new_rounded;
      color = _primaryColor;
    } else if (phaseStr.contains('together') || phaseStr.contains('apart')) {
      // For jumping jacks
      icon = Icons.directions_run_rounded;
      color = _primaryColor;
    } else {
      icon = Icons.fitness_center_rounded;
      color = Colors.white.withOpacity(0.5);
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 18),
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

  String _getMotivationalMessage({required double progress}) {
    // Only show detection-related feedback messages (directional and form guidance)
    return _feedbackMessage;
  }

  // TEMPORARY DEBUG METHODS - Remove after testing
  String _getJumpingJackConfidence() {
    final poseService = _cameraService?.poseDetectionService;
    if (poseService == null) return '0';
    return poseService.jumpingJackConfidence.toString();
  }

  String _getCurrentRawPhase() {
    final poseService = _cameraService?.poseDetectionService;
    if (poseService == null) return 'unknown';

    final rawPhase = poseService.currentRawPhase;
    if (rawPhase == null) return 'unknown';

    // Convert enum to string
    if (rawPhase is JumpingJackPhase) {
      return rawPhase.toString().split('.').last;
    }
    return 'unknown';
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
      final path = Path();
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
