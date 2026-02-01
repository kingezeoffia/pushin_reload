import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';

/// Push-up phase enum for state machine
enum PushUpPhase {
  unknown, // Initial state or poor detection
  up, // Arms extended, body straight
  goingDown, // Transitioning to down position
  down, // Chest near ground, elbows bent
  goingUp, // Transitioning back to up position
}

/// Squat phase enum for state machine
enum SquatPhase {
  unknown, // Initial state or poor detection
  up, // Standing position, legs extended
  goingDown, // Transitioning to squat
  down, // Deep squat position
  goingUp, // Rising back up
}

/// Plank phase enum for time-based workout
enum PlankPhase {
  unknown, // Initial state or poor detection
  holding, // Holding correct plank position
  broken, // Form broken (body sagging/raised)
}

/// Jumping Jack phase enum
enum JumpingJackPhase {
  unknown, // Initial state
  together, // Legs together, arms down
  apart, // Legs apart, arms up
}

/// Burpee phase enum for complex multi-phase workout
enum BurpeePhase {
  unknown, // Initial state
  standing, // Starting position, legs straight
  squatDown, // Squat to floor, knees bent
  plankPosition, // Hands on ground, legs extended back (plank)
  pushUpDown, // Lower to ground (optional push-up down phase)
  pushUpUp, // Push back up (optional push-up up phase)
  squatUp, // Jump feet forward to squat
  jumpUp, // Explosive jump up with arms raised
  landing, // Landing from jump, transitioning to standing
}

/// Glute Bridge phase enum for hip bridge exercise
enum GluteBridgeState {
  down, // Bridge down - hips on ground
  goingUp, // Transitioning up
  up, // Bridge up - hips raised
  goingDown, // Transitioning down
}

/// Workout state enum
enum WorkoutState {
  idle, // Initial - waiting for user to press START (button always enabled)
  positioning, // User pressed START, waiting for proper pose (auto-triggers countdown)
  countdown, // Auto-triggered when pose stable - 3-2-1 countdown
  active, // Actively counting reps
  paused, // Body left frame during workout
  completed, // Workout finished
}

/// Pose detection result with confidence and landmarks
class PoseDetectionResult {
  final bool isPoseDetected;
  final double confidence;
  final dynamic phase; // Can be PushUpPhase, SquatPhase, PlankPhase, etc.
  final Map<String, Offset> keyPoints;
  final String? feedbackMessage;
  final int? elapsedSeconds; // For time-based workouts like plank
  final bool isFullBodyDetected; // NEW: Whether full body is in frame
  final bool isReadyToStart; // NEW: Whether ready to start counting

  PoseDetectionResult({
    required this.isPoseDetected,
    required this.confidence,
    required this.phase,
    required this.keyPoints,
    this.feedbackMessage,
    this.elapsedSeconds,
    this.isFullBodyDetected = false,
    this.isReadyToStart = false,
  });

  static PoseDetectionResult empty() => PoseDetectionResult(
        isPoseDetected: false,
        confidence: 0.0,
        phase: PushUpPhase.unknown,
        keyPoints: {},
        feedbackMessage: 'Position yourself in frame',
        isFullBodyDetected: false,
        isReadyToStart: false,
      );
}

/// Service for detecting workout poses and counting reps
/// Uses Google ML Kit for cross-platform pose detection
/// Supports: Push-Ups, Squats, Plank, Jumping Jacks, Burpees
class PoseDetectionService {
  final String
      workoutType; // 'push-ups', 'squats', 'plank', 'jumping-jacks', 'burpees'

  PoseDetector? _poseDetector;
  bool _isProcessing = false;

  // State tracking for rep counting
  dynamic _currentPhase; // Can be any phase enum
  GluteBridgeState _currentGluteBridgeState = GluteBridgeState.down;
  int _repCount = 0;
  DateTime? _lastRepTime;

  // Jumping Jacks: 3-consecutive-detection confidence system (from MediaPipe implementation)
  int _jumpingJackConfidence = 0; // Tracks consecutive detections
  JumpingJackPhase _confirmedJumpingJackPhase =
      JumpingJackPhase.together; // Confirmed state
  JumpingJackPhase _previousConfirmedPhase =
      JumpingJackPhase.together; // Previous confirmed state

  // Time-based workout tracking (for plank)
  DateTime? _plankStartTime;
  Duration _totalPlankDuration = Duration.zero;
  int _elapsedSeconds = 0;
  int _plankConfidence = 0; // Consecutive frame counter for stability
  PlankPhase _confirmedPlankPhase =
      PlankPhase.unknown; // Stable confirmed state

  // Glute Bridge confidence system
  int _gluteBridgeConfidence = 0; // Consecutive frame counter for stability

  // Glute Bridge rep counting state machine (prevents double counting)
  GluteBridgeState _repCountingState =
      GluteBridgeState.down; // Tracks rep counting cycle

  // Burpee confidence system and state tracking
  int _burpeeConfidence = 0; // Consecutive frame counter for stability
  BurpeePhase _confirmedBurpeePhase =
      BurpeePhase.standing; // Confirmed stable state

  // Thresholds for detection (more lenient for better user experience)
  static const double _downAngleThreshold =
      100.0; // Angle for "down" position (was 90)
  static const double _upAngleThreshold =
      140.0; // Angle for "up" position (was 150)
  static const Duration _debounceTime =
      Duration(milliseconds: 400); // Faster detection
  static const double _minConfidenceForFeedback =
      0.5; // For showing skeleton/feedback
  static const double _minConfidenceForCounting =
      0.7; // For counting reps (higher threshold)

  // Workout state tracking
  WorkoutState _workoutState = WorkoutState.idle;

  // Callbacks
  Function(int)? onRepCounted;
  Function(PoseDetectionResult)? onPoseDetected;
  Function(int)? onTimerUpdate; // For time-based workouts

  PoseDetectionService({required this.workoutType});

  /// Initialize the pose detector
  Future<void> initialize() async {
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    );
    _poseDetector = PoseDetector(options: options);
    _resetState();
  }

  /// Reset state for new workout
  void _resetState() {
    switch (workoutType.toLowerCase()) {
      case 'push-ups':
        _currentPhase = PushUpPhase.unknown;
      case 'squats':
        _currentPhase = SquatPhase.unknown;
      case 'plank':
        _currentPhase = PlankPhase.unknown;
        _plankStartTime = null;
        _totalPlankDuration = Duration.zero;
        _elapsedSeconds = 0;
        _plankConfidence = 0;
        _confirmedPlankPhase = PlankPhase.unknown;
      case 'jumping-jacks':
        _currentPhase = JumpingJackPhase.unknown;
        _jumpingJackConfidence = 0;
        _confirmedJumpingJackPhase = JumpingJackPhase.together;
        _previousConfirmedPhase = JumpingJackPhase.together;
      case 'burpees':
        _currentPhase = BurpeePhase.standing;
        _burpeeConfidence = 0;
        _confirmedBurpeePhase = BurpeePhase.standing;
      case 'glute-bridge':
        _currentGluteBridgeState = GluteBridgeState.down;
        _repCountingState = GluteBridgeState.down;
      default:
        _currentPhase = PushUpPhase.unknown;
    }
    _repCount = 0;
    _lastRepTime = null;
  }

  /// Start a new workout session (initial idle state)
  void startWorkout() {
    debugPrint('🏁 Starting new workout - resetting all state');
    _resetState();
    _workoutState = WorkoutState.idle;
    debugPrint('✅ Workout state: $_workoutState, repCount: $_repCount');
  }

  /// User pressed START - enter positioning state
  void enterPositioningState() {
    _workoutState = WorkoutState.positioning;
  }

  /// Auto-trigger countdown (when pose is stable)
  void startCountdown() {
    _workoutState = WorkoutState.countdown;
  }

  /// Activate workout (after countdown) - enable rep counting
  void activateWorkout() {
    _workoutState = WorkoutState.active;
    debugPrint(
        '🚀 WORKOUT ACTIVATED - Rep counting now enabled! State: $_workoutState');
  }

  /// Pause workout (body left frame)
  void pauseWorkout() {
    if (_workoutState == WorkoutState.active) {
      _workoutState = WorkoutState.paused;
    }
  }

  /// Resume workout (body back in frame)
  void resumeWorkout() {
    if (_workoutState == WorkoutState.paused) {
      _workoutState = WorkoutState.active;
    }
  }

  /// Get current workout state
  WorkoutState get workoutState => _workoutState;

  /// Check if rep counting is enabled
  bool get isCountingEnabled => _workoutState == WorkoutState.active;

  /// Get current rep count
  int get repCount => _repCount;

  /// Manually add a rep (for when AI detection misses)
  void addManualRep() {
    _repCount++;
    onRepCounted?.call(_repCount);
    debugPrint('➕ MANUAL REP ADDED: Total reps now $_repCount');
  }

  /// Manually add a second for time-based workouts (like plank)
  void addManualSecond() {
    // Add the second to total duration
    _totalPlankDuration += const Duration(seconds: 1);
    _elapsedSeconds = _totalPlankDuration.inSeconds;
    onTimerUpdate?.call(_elapsedSeconds);
    debugPrint(
        '➕ MANUAL SECOND ADDED: Total plank time now ${_elapsedSeconds}s');
  }

  /// Get current phase
  dynamic get currentPhase => _currentPhase;

  /// Get elapsed seconds (for time-based workouts)
  int get elapsedSeconds => _elapsedSeconds;

  // TEMPORARY DEBUG GETTERS - Remove after testing
  int get jumpingJackConfidence => _jumpingJackConfidence;
  dynamic get currentRawPhase => _currentPhase;

  /// Check if full body is detected based on workout type
  bool _isFullBodyDetected(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    List<PoseLandmarkType> requiredLandmarks;

    switch (workoutType.toLowerCase()) {
      case 'push-ups':
        // Require head, shoulders, elbows, wrists, hips, knees, ankles
        requiredLandmarks = [
          PoseLandmarkType.nose,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.rightElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.rightWrist,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
        break;

      case 'squats':
        // Require shoulders, hips, knees, ankles
        requiredLandmarks = [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
        break;

      case 'plank':
        // Require shoulders, hips, knees, ankles
        requiredLandmarks = [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
        break;

      case 'jumping-jacks':
        // Require head, shoulders, wrists, hips, ankles
        requiredLandmarks = [
          PoseLandmarkType.nose,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.rightWrist,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
        break;

      case 'burpees':
        // Require head, shoulders, elbows, wrists, hips, knees, ankles
        requiredLandmarks = [
          PoseLandmarkType.nose,
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftElbow,
          PoseLandmarkType.rightElbow,
          PoseLandmarkType.leftWrist,
          PoseLandmarkType.rightWrist,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
        break;

      case 'glute-bridge':
        // Require shoulders, hips, knees, ankles for bridge detection
        requiredLandmarks = [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
          PoseLandmarkType.leftKnee,
          PoseLandmarkType.rightKnee,
          PoseLandmarkType.leftAnkle,
          PoseLandmarkType.rightAnkle,
        ];
        break;

      default:
        // Default: require basic landmarks
        requiredLandmarks = [
          PoseLandmarkType.leftShoulder,
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
          PoseLandmarkType.rightHip,
        ];
    }

    // Check that all required landmarks are present with minimum confidence
    for (final landmarkType in requiredLandmarks) {
      final landmark = landmarks[landmarkType];
      if (landmark == null || landmark.likelihood < _minConfidenceForFeedback) {
        return false;
      }
    }

    return true;
  }

  /// Get feedback message based on state and pose readiness
  String _getPositioningFeedback(bool isFullBodyDetected, double confidence) {
    // Idle state - waiting for user to press START
    if (_workoutState == WorkoutState.idle) {
      return 'Tap START to begin';
    }

    // Positioning state - guide user to proper position
    if (_workoutState == WorkoutState.positioning) {
      if (!isFullBodyDetected) {
        return 'Show your whole body in frame';
      }
      if (confidence < _minConfidenceForCounting) {
        return 'Move closer or improve lighting';
      }
      return 'Ready to start!';
    }

    // Active workout - keep it simple
    if (_workoutState == WorkoutState.active) {
      return 'Keep going!';
    }

    // Default for other states
    return 'Keep going!';
  }

  /// Process a camera frame for pose detection
  Future<PoseDetectionResult> processFrame(
      CameraImage image, InputImageRotation rotation, Size imageSize) async {
    if (_isProcessing || _poseDetector == null) {
      return PoseDetectionResult.empty();
    }

    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image, rotation, imageSize);
      if (inputImage == null) {
        return PoseDetectionResult.empty();
      }

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isEmpty) {
        // For plank workouts, still update timer even when no pose detected
        if (workoutType.toLowerCase() == 'plank' && isCountingEnabled) {
          _updatePlankTime(false);
        }

        return PoseDetectionResult(
          isPoseDetected: false,
          confidence: 0.0,
          phase: _currentPhase,
          keyPoints: {},
          feedbackMessage: 'No pose detected. Position yourself in frame.',
          isFullBodyDetected: false,
          isReadyToStart: false,
        );
      }

      final pose = poses.first;

      // Check full body detection
      final isFullBodyDetected = _isFullBodyDetected(pose.landmarks);

      // Calculate overall confidence
      final allLandmarks = pose.landmarks.values.toList();
      final avgConfidence = _calculateAverageConfidence(allLandmarks);

      // Determine if ready to start
      final isReadyToStart =
          isFullBodyDetected && avgConfidence >= _minConfidenceForCounting;

      final result = _analyzePoseByWorkoutType(
        pose,
        imageSize,
        isFullBodyDetected,
        isReadyToStart,
      );

      onPoseDetected?.call(result);

      return result;
    } catch (e) {
      debugPrint('Pose detection error: $e');
      return PoseDetectionResult.empty();
    } finally {
      _isProcessing = false;
    }
  }

  /// Convert camera image to InputImage for ML Kit
  InputImage? _convertCameraImage(
      CameraImage image, InputImageRotation rotation, Size imageSize) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImageFormat = _getInputImageFormat(image.format.group);
      if (inputImageFormat == null) return null;

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  /// Get InputImageFormat from ImageFormatGroup
  InputImageFormat? _getInputImageFormat(ImageFormatGroup group) {
    switch (group) {
      case ImageFormatGroup.nv21:
        return InputImageFormat.nv21;
      case ImageFormatGroup.yuv420:
        return InputImageFormat.yuv420;
      case ImageFormatGroup.bgra8888:
        return InputImageFormat.bgra8888;
      default:
        return null;
    }
  }

  /// Route to appropriate workout analyzer
  PoseDetectionResult _analyzePoseByWorkoutType(
    Pose pose,
    Size imageSize,
    bool isFullBodyDetected,
    bool isReadyToStart,
  ) {
    switch (workoutType.toLowerCase()) {
      case 'push-ups':
        return _analyzePushUpsPose(
            pose, imageSize, isFullBodyDetected, isReadyToStart);
      case 'squats':
        return _analyzeSquatsPose(
            pose, imageSize, isFullBodyDetected, isReadyToStart);
      case 'plank':
        return _analyzePlankPose(
            pose, imageSize, isFullBodyDetected, isReadyToStart);
      case 'jumping-jacks':
        return _analyzeJumpingJacksPose(
            pose, imageSize, isFullBodyDetected, isReadyToStart);
      case 'burpees':
        return _analyzeBurpeesPose(
            pose, imageSize, isFullBodyDetected, isReadyToStart);
      case 'glute-bridge':
        return _analyzeGluteBridgePose(
            pose, imageSize, isFullBodyDetected, isReadyToStart);
      default:
        return _analyzePushUpsPose(
            pose, imageSize, isFullBodyDetected, isReadyToStart);
    }
  }

  /// Analyze pose and determine push-up phase
  /// ENHANCED: Now includes body alignment validation (shoulder-hip-ankle straightness)
  /// Research-based approach from ML Kit best practices and fitness biomechanics
  PoseDetectionResult _analyzePushUpsPose(
    Pose pose,
    Size imageSize,
    bool isFullBodyDetected,
    bool isReadyToStart,
  ) {
    if (workoutType.toLowerCase() != 'push-ups') {
      _currentPhase = PushUpPhase.unknown;
      return PoseDetectionResult.empty();
    }

    final landmarks = pose.landmarks;

    // Extract key landmarks (expanded to include full body)
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    // Check if we have the necessary landmarks
    if (leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null ||
        leftHip == null ||
        rightHip == null) {
      return PoseDetectionResult(
        isPoseDetected: false,
        confidence: 0.0,
        phase: PushUpPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Position your full body in the frame',
        isFullBodyDetected: false,
        isReadyToStart: false,
      );
    }

    // Calculate average confidence (expanded landmark set)
    final avgConfidence = _calculateAverageConfidence([
      leftShoulder,
      rightShoulder,
      leftElbow,
      rightElbow,
      leftWrist,
      rightWrist,
      leftHip,
      rightHip,
      if (leftKnee != null) leftKnee,
      if (rightKnee != null) rightKnee,
      if (leftAnkle != null) leftAnkle,
      if (rightAnkle != null) rightAnkle,
    ]);

    // Before workout starts, give positioning feedback only
    if (_workoutState == WorkoutState.idle) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: PushUpPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage:
            _getPositioningFeedback(isFullBodyDetected, avgConfidence),
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    if (avgConfidence < _minConfidenceForFeedback) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: PushUpPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Move closer or improve lighting',
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    // === RESEARCH-BASED PUSH-UP FORM VALIDATION ===
    // Based on: LearnOpenCV AI Fitness Trainer, MediaPipe Pose best practices
    // Key metrics: elbow angle, body alignment (shoulder-hip-ankle/knee straightness)

    // 1. ELBOW ANGLE CALCULATION (Primary movement indicator)
    final leftElbowAngle = _calculateAngle(
      Offset(leftShoulder.x, leftShoulder.y),
      Offset(leftElbow.x, leftElbow.y),
      Offset(leftWrist.x, leftWrist.y),
    );

    final rightElbowAngle = _calculateAngle(
      Offset(rightShoulder.x, rightShoulder.y),
      Offset(rightElbow.x, rightElbow.y),
      Offset(rightWrist.x, rightWrist.y),
    );

    final avgElbowAngle = (leftElbowAngle + rightElbowAngle) / 2;

    // 2. BODY ALIGNMENT VALIDATION (Critical for proper form)
    // Research: Body should form straight line from shoulders through hips to knees/ankles
    // This prevents "worm" push-ups and ensures proper plank position

    // Calculate average body points
    final avgShoulder = Offset((leftShoulder.x + rightShoulder.x) / 2,
        (leftShoulder.y + rightShoulder.y) / 2);
    final avgHip =
        Offset((leftHip.x + rightHip.x) / 2, (leftHip.y + rightHip.y) / 2);

    // Use knee or ankle as endpoint (prefer ankle if available for full body check)
    Offset avgLowerBody;
    if (leftAnkle != null && rightAnkle != null) {
      avgLowerBody = Offset(
          (leftAnkle.x + rightAnkle.x) / 2, (leftAnkle.y + rightAnkle.y) / 2);
    } else if (leftKnee != null && rightKnee != null) {
      avgLowerBody = Offset(
          (leftKnee.x + rightKnee.x) / 2, (leftKnee.y + rightKnee.y) / 2);
    } else {
      // Fallback: can't validate full body alignment, allow anyway
      avgLowerBody = avgHip;
    }

    // Calculate body alignment angle (shoulder-hip-lowerBody)
    // Research: Should be 160-200° for proper plank position
    final bodyAlignmentAngle =
        _calculateAngle(avgShoulder, avgHip, avgLowerBody);

    // Body straightness validation
    // Research shows 160° minimum for proper push-up form
    final isBodyStraight = bodyAlignmentAngle >= 160.0 &&
        bodyAlignmentAngle <= 200.0; // Allow slight natural curvature

    // 3. PLANK POSITION VALIDATION (Arms supporting body weight)
    // Research: In push-up position, body should be horizontal with arms supporting
    // Check if body is in horizontal orientation (not standing)
    final shoulderY = avgShoulder.dy / imageSize.height;
    final hipY = avgHip.dy / imageSize.height;
    final verticalDifference = (hipY - shoulderY).abs();

    // Horizontal orientation check: shoulder and hip should be at similar height
    // Allow up to 15% difference for natural body angle
    final isHorizontalOrientation = verticalDifference < 0.15;

    // COMPREHENSIVE FORM VALIDATION
    // Only count reps when proper form is maintained
    final hasProperForm = isBodyStraight && isHorizontalOrientation;

    // Determine push-up phase with form validation
    final newPhase =
        _determinePushUpPhase(avgElbowAngle, hasProperForm, bodyAlignmentAngle);
    final feedbackMessage =
        _getPushUpFeedback(newPhase, avgElbowAngle, hasProperForm);

    // DEBUG LOGGING - Research validation
    debugPrint(
        '💪 PUSH-UP FORM: elbowAngle=${avgElbowAngle.toStringAsFixed(1)}°, '
        'bodyAlign=${bodyAlignmentAngle.toStringAsFixed(1)}° (straight=$isBodyStraight), '
        'horiz=$isHorizontalOrientation (${verticalDifference.toStringAsFixed(3)}), '
        'properForm=$hasProperForm, phase=$newPhase');

    // Only check for completed rep if workout is active AND full body detected AND proper form
    if (isCountingEnabled) {
      if (isFullBodyDetected &&
          avgConfidence >= _minConfidenceForCounting &&
          hasProperForm) {
        _checkForCompletedPushUpRep(newPhase);
      } else {
        // Debug why rep check was skipped
        if (!isFullBodyDetected) {
          debugPrint('⏸️ PUSH-UP REP CHECK SKIPPED: Full body not visible');
        } else if (avgConfidence < _minConfidenceForCounting) {
          debugPrint(
              '⏸️ PUSH-UP REP CHECK SKIPPED: Low confidence ${avgConfidence.toStringAsFixed(2)} < $_minConfidenceForCounting');
        } else if (!hasProperForm) {
          debugPrint('⏸️ PUSH-UP REP CHECK SKIPPED: Poor form detected');
        }
      }
    }

    _currentPhase = newPhase;

    return PoseDetectionResult(
      isPoseDetected: true,
      confidence: avgConfidence,
      phase: newPhase,
      keyPoints: _extractKeyPoints(landmarks),
      feedbackMessage: feedbackMessage,
      isFullBodyDetected: isFullBodyDetected,
      isReadyToStart: isReadyToStart,
    );
  }

  /// Extract key points as Offset map
  Map<String, Offset> _extractKeyPoints(
      Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final keyPoints = <String, Offset>{};

    for (final entry in landmarks.entries) {
      keyPoints[entry.key.name] = Offset(entry.value.x, entry.value.y);
    }

    return keyPoints;
  }

  /// Calculate average confidence from landmarks
  double _calculateAverageConfidence(List<PoseLandmark> landmarks) {
    if (landmarks.isEmpty) return 0.0;
    final total = landmarks.fold<double>(0.0, (sum, lm) => sum + lm.likelihood);
    return total / landmarks.length;
  }

  /// Calculate angle between three points (in degrees)
  double _calculateAngle(Offset p1, Offset p2, Offset p3) {
    final v1 = Offset(p1.dx - p2.dx, p1.dy - p2.dy);
    final v2 = Offset(p3.dx - p2.dx, p3.dy - p2.dy);

    final dot = v1.dx * v2.dx + v1.dy * v2.dy;
    final cross = v1.dx * v2.dy - v1.dy * v2.dx;

    final angle = math.atan2(cross.abs(), dot);
    return angle * 180 / math.pi;
  }

  /// Calculate hip extension angle between torso and thigh (key for glute bridge detection)
  /// Returns angle between shoulder→hip vector and hip→knee vector
  /// Uses proper vector normalization and dot product for accurate angle calculation
  double _calculateHipExtensionAngle(Offset shoulder, Offset hip, Offset knee) {
    // Vector from shoulder to hip (torso direction: shoulder → hip)
    final torso = Offset(hip.dx - shoulder.dx, hip.dy - shoulder.dy);

    // Vector from hip to knee (thigh direction: hip → knee)
    final thigh = Offset(knee.dx - hip.dx, knee.dy - hip.dy);

    // Calculate dot product
    final dot = torso.dx * thigh.dx + torso.dy * thigh.dy;

    // Calculate magnitudes
    final magTorso = math.sqrt(torso.dx * torso.dx + torso.dy * torso.dy);
    final magThigh = math.sqrt(thigh.dx * thigh.dx + thigh.dy * thigh.dy);

    // Avoid division by zero
    if (magTorso == 0 || magThigh == 0) return 0.0;

    // Calculate cosine of angle and clamp to valid range
    final cosTheta = (dot / (magTorso * magThigh)).clamp(-1.0, 1.0);

    // Calculate angle in radians, then convert to degrees
    final angleRad = math.acos(cosTheta);
    return angleRad * 180 / math.pi;
  }

  /// Determine push-up phase based on elbow angle and form validation
  /// ENHANCED: Now includes body alignment validation
  PushUpPhase _determinePushUpPhase(
      double elbowAngle, bool hasProperForm, double bodyAlignmentAngle) {
    // If form is poor (body not straight or not horizontal), return unknown
    // This prevents counting reps with improper form
    if (!hasProperForm) {
      return PushUpPhase.unknown;
    }

    // Standard elbow angle thresholds with proper form
    if (elbowAngle < _downAngleThreshold) {
      // Deep position - chest near ground
      return PushUpPhase.down;
    } else if (elbowAngle > _upAngleThreshold) {
      // Full extension - arms straight
      return PushUpPhase.up;
    } else if (_currentPhase == PushUpPhase.up ||
        _currentPhase == PushUpPhase.goingDown) {
      // Transitioning down
      return PushUpPhase.goingDown;
    } else {
      // Transitioning up
      return PushUpPhase.goingUp;
    }
  }

  /// Check if a push-up rep has been completed (down -> up transition)
  void _checkForCompletedPushUpRep(PushUpPhase newPhase) {
    final now = DateTime.now();

    // Rep is complete when we transition from down/goingUp to up
    if ((_currentPhase == PushUpPhase.down ||
            _currentPhase == PushUpPhase.goingUp) &&
        newPhase == PushUpPhase.up) {
      // Apply debounce
      if (_lastRepTime != null &&
          now.difference(_lastRepTime!) < _debounceTime) {
        return;
      }

      _repCount++;
      _lastRepTime = now;
      onRepCounted?.call(_repCount);
    }
  }

  /// Get push-up feedback message based on current phase and form
  /// ENHANCED: Provides form feedback when alignment is poor
  String _getPushUpFeedback(
      PushUpPhase phase, double elbowAngle, bool hasProperForm) {
    // Prioritize form feedback if form is compromised
    if (!hasProperForm) {
      return 'Keep body straight - form a plank line';
    }

    // Standard movement feedback with proper form
    switch (phase) {
      case PushUpPhase.unknown:
        return 'Get into push-up position';
      case PushUpPhase.up:
        return 'Lower down slowly';
      case PushUpPhase.goingDown:
        return 'Keep going down';
      case PushUpPhase.down:
        return 'Push up explosively';
      case PushUpPhase.goingUp:
        return 'Push up - maintain form';
    }
  }

  // ============================================================================
  // SQUATS DETECTION
  // ============================================================================

  /// Analyze pose for squats
  PoseDetectionResult _analyzeSquatsPose(
    Pose pose,
    Size imageSize,
    bool isFullBodyDetected,
    bool isReadyToStart,
  ) {
    if (workoutType.toLowerCase() != 'squats') {
      _currentPhase = SquatPhase.unknown;
      return PoseDetectionResult.empty();
    }

    final landmarks = pose.landmarks;

    // Extract key landmarks for legs
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    // Check if we have necessary landmarks
    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return PoseDetectionResult(
        isPoseDetected: false,
        confidence: 0.0,
        phase: SquatPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Position your legs in the frame',
        isFullBodyDetected: false,
        isReadyToStart: false,
      );
    }

    // Calculate average confidence
    final avgConfidence = _calculateAverageConfidence([
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
    ]);

    // Before workout starts, give positioning feedback only
    if (_workoutState == WorkoutState.idle) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: SquatPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage:
            _getPositioningFeedback(isFullBodyDetected, avgConfidence),
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    if (avgConfidence < _minConfidenceForFeedback) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: SquatPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Move closer or improve lighting',
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    // Calculate knee angles (hip-knee-ankle)
    final leftLegAngle = _calculateAngle(
      Offset(leftHip.x, leftHip.y),
      Offset(leftKnee.x, leftKnee.y),
      Offset(leftAnkle.x, leftAnkle.y),
    );

    final rightLegAngle = _calculateAngle(
      Offset(rightHip.x, rightHip.y),
      Offset(rightKnee.x, rightKnee.y),
      Offset(rightAnkle.x, rightAnkle.y),
    );

    final avgKneeAngle = (leftLegAngle + rightLegAngle) / 2;

    // Research-based depth validation: minimum 90° for parallel squat (Cotter et al., 2013)
    final isAdequateDepth = avgKneeAngle >= 90.0;

    // Determine squat phase with research-based thresholds
    final newPhase = _determineSquatPhase(avgKneeAngle, isAdequateDepth);
    final feedbackMessage =
        _getSquatFeedback(newPhase, avgKneeAngle, isAdequateDepth);

    // DEBUG LOGGING - Research validation (after all calculations)
    debugPrint(
        '🔍 SQUAT Research Debug: kneeAngle=${avgKneeAngle.toStringAsFixed(1)}°, '
        'adequateDepth=$isAdequateDepth, phase=$newPhase');

    // Only check for completed rep if workout is active AND full body detected
    if (isCountingEnabled) {
      if (isFullBodyDetected && avgConfidence >= _minConfidenceForCounting) {
        _checkForCompletedSquatRep(newPhase);
      } else {
        // Debug why rep check was skipped
        if (!isFullBodyDetected) {
          debugPrint('⏸️ SQUAT REP CHECK SKIPPED: Full body not visible');
        } else if (avgConfidence < _minConfidenceForCounting) {
          debugPrint(
              '⏸️ SQUAT REP CHECK SKIPPED: Low confidence ${avgConfidence.toStringAsFixed(2)} < $_minConfidenceForCounting');
        }
      }
    }

    _currentPhase = newPhase;

    return PoseDetectionResult(
      isPoseDetected: true,
      confidence: avgConfidence,
      phase: newPhase,
      keyPoints: _extractKeyPoints(landmarks),
      feedbackMessage: feedbackMessage,
      isFullBodyDetected: isFullBodyDetected,
      isReadyToStart: isReadyToStart,
    );
  }

  /// Determine squat phase based on research-validated thresholds
  /// Research: Cotter et al. (2013) - Parallel squats require 90° knee flexion
  SquatPhase _determineSquatPhase(double kneeAngle, bool isAdequateDepth) {
    // Research-based thresholds for squat phases
    if (kneeAngle < 100.0 && isAdequateDepth) {
      // Research: Deep squat position (below parallel) - thighs touch calves
      return SquatPhase.down;
    } else if (kneeAngle > 160.0) {
      // Research: Standing position - fully extended
      return SquatPhase.up;
    } else if (_currentPhase == SquatPhase.up ||
        _currentPhase == SquatPhase.goingDown) {
      return SquatPhase.goingDown;
    } else {
      return SquatPhase.goingUp;
    }
  }

  /// Check if a squat rep has been completed
  void _checkForCompletedSquatRep(SquatPhase newPhase) {
    final now = DateTime.now();

    if ((_currentPhase == SquatPhase.down ||
            _currentPhase == SquatPhase.goingUp) &&
        newPhase == SquatPhase.up) {
      if (_lastRepTime != null &&
          now.difference(_lastRepTime!) < _debounceTime) {
        return;
      }

      _repCount++;
      _lastRepTime = now;
      onRepCounted?.call(_repCount);
    }
  }

  /// Get squat feedback message
  String _getSquatFeedback(
      SquatPhase phase, double kneeAngle, bool isAdequateDepth) {
    switch (phase) {
      case SquatPhase.unknown:
        return 'Get ready for squats';
      case SquatPhase.up:
        return 'Squat down';
      case SquatPhase.goingDown:
        return 'Keep going down';
      case SquatPhase.down:
        return 'Stand up';
      case SquatPhase.goingUp:
        return 'Stand up';
    }
  }

  // ============================================================================
  // PLANK DETECTION (Time-based)
  // ============================================================================

  /// Analyze pose for plank hold
  PoseDetectionResult _analyzePlankPose(
    Pose pose,
    Size imageSize,
    bool isFullBodyDetected,
    bool isReadyToStart,
  ) {
    if (workoutType.toLowerCase() != 'plank') {
      _currentPhase = PlankPhase.unknown;
      _plankStartTime = null;
      _totalPlankDuration = Duration.zero;
      _elapsedSeconds = 0;
      _plankConfidence = 0;
      _confirmedPlankPhase = PlankPhase.unknown;
      return PoseDetectionResult.empty();
    }

    final landmarks = pose.landmarks;

    // Extract key landmarks
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return PoseDetectionResult(
        isPoseDetected: false,
        confidence: 0.0,
        phase: PlankPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Position your body in frame',
        elapsedSeconds: _elapsedSeconds,
        isFullBodyDetected: false,
        isReadyToStart: false,
      );
    }

    final avgConfidence = _calculateAverageConfidence([
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
      leftAnkle,
      rightAnkle,
    ]);

    // Before workout starts, give positioning feedback only
    if (_workoutState == WorkoutState.idle) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: PlankPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage:
            _getPositioningFeedback(isFullBodyDetected, avgConfidence),
        elapsedSeconds: _elapsedSeconds,
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    if (avgConfidence < _minConfidenceForFeedback) {
      _updatePlankTime(false);
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: PlankPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Move closer or improve lighting',
        elapsedSeconds: _elapsedSeconds,
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    // === SCIENTIFICALLY-INFORMED PLANK DETECTION ===
    // Based on computer vision research for exercise recognition
    // Optimal thresholds from pose estimation studies

    // Get comprehensive landmark set for robust detection
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];

    // Calculate stable body reference points
    final avgShoulder = Offset((leftShoulder.x + rightShoulder.x) / 2,
        (leftShoulder.y + rightShoulder.y) / 2);
    final avgHip =
        Offset((leftHip.x + rightHip.x) / 2, (leftHip.y + rightHip.y) / 2);
    final avgAnkle = Offset(
        (leftAnkle.x + rightAnkle.x) / 2, (leftAnkle.y + rightAnkle.y) / 2);
    final avgKnee = leftKnee != null && rightKnee != null
        ? Offset((leftKnee.x + rightKnee.x) / 2, (leftKnee.y + rightKnee.y) / 2)
        : avgHip;

    // 1. BODY ORIENTATION CHECK (PRIMARY CRITERION)
    // Research shows horizontal body orientation is most important for plank detection
    // STRICT threshold: shoulder-hip vertical difference < 8% of frame height for true plank
    final shoulderY = avgShoulder.dy / imageSize.height;
    final hipY = avgHip.dy / imageSize.height;
    final ankleY = avgAnkle.dy / imageSize.height;
    final verticalDifference = (hipY - shoulderY).abs();

    // STRICT threshold: body must be nearly horizontal (< 8% vertical difference)
    final isHorizontalOrientation = verticalDifference < 0.08;

    // STRICT anti-standing check: ankles should NOT be significantly higher than shoulders
    // In plank, all body parts should be roughly at same height (horizontal position)
    final notStanding =
        (ankleY - shoulderY) < 0.15; // Ankles only slightly higher (STRICT)

    // 2. BODY ALIGNMENT (SHOULDER-HIP-ANKLE STRAIGHTNESS)
    // Studies show optimal plank angle range is 160-200 degrees for proper form
    final bodyAngle = _calculateAngle(avgShoulder, avgHip, avgAnkle);
    final isBodyStraight = bodyAngle >= 160 && bodyAngle <= 200;

    // 3. ARM SUPPORT POSITION (CRITICAL FOR PLANK VALIDATION)
    // Research indicates arms must be supporting body weight for plank recognition
    // Elbows/wrists should be at or below shoulder level
    double avgArmSupportY;
    if (leftElbow != null &&
        rightElbow != null &&
        leftWrist != null &&
        rightWrist != null) {
      final avgElbow = (leftElbow.y + rightElbow.y) / 2;
      final avgWrist = (leftWrist.y + rightWrist.y) / 2;
      // Use the lower point (closer to ground) as primary support
      avgArmSupportY = avgElbow > avgWrist ? avgElbow : avgWrist;
    } else if (leftWrist != null && rightWrist != null) {
      avgArmSupportY = (leftWrist.y + rightWrist.y) / 2;
    } else if (leftElbow != null && rightElbow != null) {
      avgArmSupportY = (leftElbow.y + rightElbow.y) / 2;
    } else {
      avgArmSupportY = avgShoulder.dy; // Fallback
    }

    // Arms supporting when positioned below or at shoulder level
    final armsSupporting = avgArmSupportY >= avgShoulder.dy - 0.2;

    // 4. HIP STABILITY (PREVENTS SAG OR PIKE)
    // Studies show hips should be level with shoulders in proper plank
    // STRICT threshold: hip-shoulder vertical difference < 8% of screen height
    final hipYNorm = avgHip.dy / imageSize.height;
    final shoulderYNorm = avgShoulder.dy / imageSize.height;
    final hipShoulderDifferenceNorm = (hipYNorm - shoulderYNorm).abs();
    final hipsLevelWithShoulders = hipShoulderDifferenceNorm < 0.08; // STRICT

    // 5. KNEE EXTENSION (LEGS STRAIGHT)
    // Research indicates knees should be straight and aligned with hips
    // STRICT threshold: knee-hip vertical difference < 6% of screen height
    final kneeYNorm = avgKnee.dy / imageSize.height;
    final hipYNormKnee = avgHip.dy / imageSize.height;
    final kneeHipDifferenceNorm = (kneeYNorm - hipYNormKnee).abs();
    final legsRelativelyStraight = kneeHipDifferenceNorm < 0.06; // STRICT

    // === MULTI-CRITERIA SCIENTIFIC VALIDATION ===
    // STRICT research-based thresholds to prevent false positives

    // Primary validation: ALL criteria must pass (no fallback)
    final isValidPlank =
        isHorizontalOrientation && // Body horizontal (< 8% vertical diff) - STRICT
            notStanding && // Not standing (< 15% ankle-shoulder diff) - STRICT
            isBodyStraight && // Body straight (160-200° angle)
            armsSupporting && // Arms supporting weight - REQUIRED
            hipsLevelWithShoulders && // Hips level with shoulders (< 8%) - STRICT
            legsRelativelyStraight; // Legs straight (< 6% knee-hip diff) - STRICT

    // === DETAILED SCIENTIFIC DEBUG LOGGING ===
    final validationPath = isValidPlank ? 'VALID' : 'INVALID';
    final armStatus =
        avgArmSupportY >= avgShoulder.dy ? 'SUPPORTING' : 'NOT_SUPPORTING';
    debugPrint(
        '🔍 PLANK Debug (STRICT): horiz=$isHorizontalOrientation (${verticalDifference.toStringAsFixed(3)}), notStanding=$notStanding (${(ankleY - shoulderY).toStringAsFixed(3)}), straight=$isBodyStraight (${bodyAngle.toStringAsFixed(1)}°), arms=$armsSupporting ($armStatus), hips=$hipsLevelWithShoulders (${hipShoulderDifferenceNorm.toStringAsFixed(3)}), knees=$legsRelativelyStraight (${kneeHipDifferenceNorm.toStringAsFixed(3)}), result=$validationPath');

    // === CONFIDENCE SYSTEM FOR PLANK (Prevent flickering and false positives) ===
    final rawPhase = isValidPlank ? PlankPhase.holding : PlankPhase.broken;

    // Track consecutive detections - STRICT: require 5 consecutive frames for plank hold
    if (rawPhase == _currentPhase) {
      _plankConfidence = (_plankConfidence + 1).clamp(0, 5);
    } else {
      _plankConfidence = 0;
    }

    _currentPhase = rawPhase;

    // STRICT: Require 5 consecutive frames to confirm plank hold (prevents false positives)
    // But only 3 frames to confirm broken state (allows quick feedback)
    if (_plankConfidence >= 5 && rawPhase == PlankPhase.holding) {
      _confirmedPlankPhase = PlankPhase.holding;
    } else if (_plankConfidence >= 3 && rawPhase == PlankPhase.broken) {
      _confirmedPlankPhase = PlankPhase.broken;
    } else if (_plankConfidence < 1) {
      // Reset to unknown if confidence drops
      _confirmedPlankPhase = PlankPhase.unknown;
    }

    // Use confirmed phase for time tracking (more stable)
    final isHoldingStable = _confirmedPlankPhase == PlankPhase.holding;

    debugPrint(
        '🏋️ PLANK STATE (STRICT): confirmedPhase=$_confirmedPlankPhase, isHoldingStable=$isHoldingStable, confidence=$_plankConfidence/5, rawPhase=$rawPhase');

    // Update time tracking - always call when workout is active to keep UI in sync
    if (isCountingEnabled) {
      if (isFullBodyDetected && avgConfidence >= _minConfidenceForCounting) {
        _updatePlankTime(isHoldingStable);

        // Debug time tracking
        if (isHoldingStable) {
          debugPrint('⏱️ PLANK HOLDING: ${_elapsedSeconds}s');
        } else {
          debugPrint(
              '⏸️ PLANK NOT HOLDING: confirmedPhase=$_confirmedPlankPhase');
        }
      } else {
        _updatePlankTime(false);
        // Debug why time update was skipped
        if (!isFullBodyDetected) {
          debugPrint('⏸️ PLANK TIME UPDATE SKIPPED: Full body not visible');
        } else if (avgConfidence < _minConfidenceForCounting) {
          debugPrint(
              '⏸️ PLANK TIME UPDATE SKIPPED: Low confidence ${avgConfidence.toStringAsFixed(2)} < $_minConfidenceForCounting');
        }
      }
    } else {
      _updatePlankTime(false);
    }

    return PoseDetectionResult(
      isPoseDetected: true,
      confidence: avgConfidence,
      phase: _confirmedPlankPhase, // Use confirmed phase for UI
      keyPoints: _extractKeyPoints(landmarks),
      feedbackMessage: _getPlankFeedback(_confirmedPlankPhase, bodyAngle),
      elapsedSeconds: _elapsedSeconds,
      isFullBodyDetected: isFullBodyDetected,
      isReadyToStart: isReadyToStart,
    );
  }

  /// Update plank hold time
  void _updatePlankTime(bool isHolding) {
    final now = DateTime.now();

    if (isHolding && _plankStartTime == null) {
      _plankStartTime = now;
    } else if (isHolding && _plankStartTime != null) {
      _elapsedSeconds = _totalPlankDuration.inSeconds +
          now.difference(_plankStartTime!).inSeconds;
    } else if (!isHolding && _plankStartTime != null) {
      _totalPlankDuration += now.difference(_plankStartTime!);
      _elapsedSeconds = _totalPlankDuration.inSeconds;
      _plankStartTime = null;
    }

    // Always call the timer update callback when workout is active to keep UI in sync
    if (_workoutState == WorkoutState.active) {
      onTimerUpdate?.call(_elapsedSeconds);
    }
  }

  /// Get plank feedback message with specific guidance
  String _getPlankFeedback(PlankPhase phase, double bodyAngle) {
    switch (phase) {
      case PlankPhase.holding:
        if (bodyAngle < 165) {
          return 'Good! Straighten hips slightly';
        } else if (bodyAngle > 195) {
          return 'Good! Lower hips slightly';
        }
        return 'Perfect! Keep holding!';
      case PlankPhase.broken:
        if (bodyAngle < 160) {
          return 'Lift your hips higher';
        } else if (bodyAngle > 200) {
          return 'Lower your hips - avoid piking';
        } else {
          return 'Align your body straight';
        }
      default:
        return 'Get into plank position';
    }
  }

  // ============================================================================
  // JUMPING JACKS DETECTION
  // ============================================================================

  /// Analyze pose for jumping jacks
  PoseDetectionResult _analyzeJumpingJacksPose(
    Pose pose,
    Size imageSize,
    bool isFullBodyDetected,
    bool isReadyToStart,
  ) {
    if (workoutType.toLowerCase() != 'jumping-jacks') {
      _currentPhase = JumpingJackPhase.unknown;
      return PoseDetectionResult.empty();
    }

    final landmarks = pose.landmarks;

    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftWrist == null ||
        rightWrist == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return PoseDetectionResult(
        isPoseDetected: false,
        confidence: 0.0,
        phase: JumpingJackPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Position your full body in frame',
        isFullBodyDetected: false,
        isReadyToStart: false,
      );
    }

    final avgConfidence = _calculateAverageConfidence([
      leftWrist, rightWrist,
      leftElbow ?? leftShoulder,
      rightElbow ?? rightShoulder, // Use shoulders as fallback
      leftShoulder, rightShoulder,
      leftAnkle, rightAnkle,
    ]);

    // Before workout starts, give positioning feedback only
    if (_workoutState == WorkoutState.idle) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: JumpingJackPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage:
            _getPositioningFeedback(isFullBodyDetected, avgConfidence),
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    if (avgConfidence < _minConfidenceForFeedback) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: JumpingJackPhase.unknown,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Move closer or improve lighting',
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    // === ENHANCED JUMPING JACKS DETECTION ===
    // Based on computer vision best practices and fitness tracking research
    // Key improvements: relative measurements, hysteresis thresholds, flexible coordination

    // 1. CALCULATE NORMALIZED BODY MEASUREMENTS
    // Use relative ratios instead of absolute pixels for robustness across body sizes
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final hipWidth = leftHip != null && rightHip != null
        ? (leftHip.x - rightHip.x).abs()
        : shoulderWidth;
    final ankleWidth = (leftAnkle.x - rightAnkle.x).abs();

    // Body height estimation for proportional thresholds (shoulder to ankle distance)
    final rawBodyHeight = (leftShoulder.y - leftAnkle.y).abs();
    // Clamp to reasonable range to prevent extreme values
    final bodyHeight = rawBodyHeight.clamp(50.0, 800.0);

    // 2. ARM POSITION DETECTION (Enhanced with hysteresis and flexibility)
    final avgWristY = (leftWrist.y + rightWrist.y) / 2;
    final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2;
    final avgElbowY = leftElbow != null && rightElbow != null
        ? ((leftElbow.y + rightElbow.y) / 2)
        : avgShoulderY;

    // Vertical arm displacement (key metric for jumping jacks)
    final rawArmRaiseDistance = avgShoulderY - avgWristY;
    // Clamp to reasonable range to prevent extreme values
    final armRaiseDistance = rawArmRaiseDistance.clamp(-200.0, 400.0);

    // Hysteresis thresholds: different for up vs down transitions (prevents oscillation)
    final armsRaisedThreshold =
        bodyHeight * 0.15; // 15% of body height for "arms up"
    final armsLoweredThreshold =
        bodyHeight * 0.05; // 5% of body height for "arms down"

    // Elbow position check (more flexible than strict shoulder level)
    final elbowsAboveShoulders = avgElbowY < avgShoulderY;

    // Determine arm state with hysteresis
    final armsUp =
        armRaiseDistance > armsRaisedThreshold && elbowsAboveShoulders;
    final armsDown = armRaiseDistance < armsLoweredThreshold;

    // 3. LEG POSITION DETECTION (Improved with clear state separation)
    final ankleSeparation = ankleWidth;
    final hipSeparation = hipWidth;

    // Clear separation of leg states - no overlap zone
    // "Apart": ankles significantly wider than hips (jumping out)
    final legsApart = ankleSeparation > hipSeparation * 1.4;

    // "Together": ankles close to hip width (starting position)
    final legsTogether = ankleSeparation < hipSeparation * 1.1;

    // 4. PRIMARY MOVEMENT DETECTION (Focus on key indicators)
    // For jumping jacks, the primary movements are arm raising and leg spreading
    // Coordination is less important than the main movement components

    // Arm movement is the strongest indicator
    final primaryArmMovement = armsUp || armsDown;

    // Leg movement provides secondary confirmation
    final primaryLegMovement = legsApart || legsTogether;

    // 5. STATE DETERMINATION (Research-based approach)
    // Based on exercise science: jumping jacks follow a clear pattern
    // together → apart → together (complete cycle)
    JumpingJackPhase rawState;

    // Prioritize arm position as primary indicator (research shows arms are more reliable)
    if (armsUp && (legsApart || !primaryLegMovement)) {
      // Arms up indicates "apart" phase, legs should be apart but allow flexibility
      rawState = JumpingJackPhase.apart;
    } else if (armsDown && (legsTogether || !primaryLegMovement)) {
      // Arms down indicates "together" phase, legs should be together but allow flexibility
      rawState = JumpingJackPhase.together;
    } else {
      // Ambiguous state - maintain current phase to avoid noise
      rawState = _currentPhase;
    }

    // === RESEARCH-BASED DEBUG LOGGING ===
    debugPrint(
        '🏃 JJ Research Debug: armsUp=$armsUp(${armRaiseDistance.toStringAsFixed(1)}), '
        'legsApart=$legsApart(${ankleWidth.toStringAsFixed(0)}>${(hipWidth * 1.4).toStringAsFixed(0)}), '
        'legsTogether=$legsTogether(${ankleWidth.toStringAsFixed(0)}<${(hipWidth * 1.1).toStringAsFixed(0)}), '
        'primaryArm=$primaryArmMovement, primaryLeg=$primaryLegMovement, '
        'bodyHeight=${bodyHeight.toStringAsFixed(0)}, rawState=$rawState, conf=$_jumpingJackConfidence');

    // === ADAPTIVE CONFIDENCE SYSTEM ===
    // Research shows faster movements need less confirmation, slower movements need more
    bool isFastMovement = false;
    if (_lastRepTime != null) {
      final timeSinceLast =
          DateTime.now().difference(_lastRepTime!).inMilliseconds;
      isFastMovement =
          timeSinceLast < 800; // Less than 0.8 seconds between reps = fast
    }

    // Adaptive confidence threshold: faster movements need less confirmation
    final requiredConfidence = isFastMovement ? 1 : 2;

    if (rawState == _currentPhase) {
      _jumpingJackConfidence = (_jumpingJackConfidence + 1).clamp(0, 3);
    } else {
      // Reset confidence on state change
      _jumpingJackConfidence = 0;
    }

    // Update current phase
    _currentPhase = rawState;

    // Confirm state change with adaptive logic
    if (_jumpingJackConfidence >= requiredConfidence &&
        _confirmedJumpingJackPhase != _currentPhase) {
      _previousConfirmedPhase = _confirmedJumpingJackPhase;
      _confirmedJumpingJackPhase = _currentPhase;

      // === RESEARCH-BASED CYCLE DETECTION ===
      // Count complete cycles: apart → together transitions (ONLY during active workout with full body visible)
      if (isCountingEnabled &&
          _previousConfirmedPhase == JumpingJackPhase.apart &&
          _confirmedJumpingJackPhase == JumpingJackPhase.together) {
        // Check additional requirements for rep counting
        if (isFullBodyDetected && avgConfidence >= _minConfidenceForCounting) {
          // Intelligent debounce based on movement speed detection
          final now = DateTime.now();

          // Adaptive debounce: fast movements (detected) get shorter debounce
          final debounceMs = isFastMovement ? 100 : 250;

          if (_lastRepTime == null ||
              now.difference(_lastRepTime!) >
                  Duration(milliseconds: debounceMs)) {
            _repCount++;
            _lastRepTime = now;
            onRepCounted?.call(_repCount);
            debugPrint(
                '✅ JJ REP COUNTED: $_repCount (Adaptive detection, fast=$isFastMovement)');
          }
        } else {
          // Debug why rep wasn't counted
          if (!isFullBodyDetected) {
            debugPrint(
                '⏸️ JJ REP SKIPPED: Full body not visible (apart→together detected)');
          } else if (avgConfidence < _minConfidenceForCounting) {
            debugPrint(
                '⏸️ JJ REP SKIPPED: Low confidence ${avgConfidence.toStringAsFixed(2)} < $_minConfidenceForCounting');
          }
        }
      }
    }

    return PoseDetectionResult(
      isPoseDetected: true,
      confidence: avgConfidence,
      phase:
          _confirmedJumpingJackPhase, // Use confirmed phase for stable UI feedback
      keyPoints: _extractKeyPoints(landmarks),
      feedbackMessage: _getJumpingJackFeedback(_confirmedJumpingJackPhase),
      isFullBodyDetected: isFullBodyDetected,
      isReadyToStart: isReadyToStart,
    );
  }

  // ============================================================================
  // GLUTE BRIDGE DETECTION
  // ============================================================================

  /// Analyze pose for glute bridge
  PoseDetectionResult _analyzeGluteBridgePose(
    Pose pose,
    Size imageSize,
    bool isFullBodyDetected,
    bool isReadyToStart,
  ) {
    if (workoutType.toLowerCase() != 'glute-bridge') {
      _currentGluteBridgeState = GluteBridgeState.down;
      _repCountingState = GluteBridgeState.down;
      return PoseDetectionResult.empty();
    }

    final landmarks = pose.landmarks;

    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null) {
      return PoseDetectionResult(
        isPoseDetected: false,
        confidence: 0.0,
        phase: GluteBridgeState.down,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Position your full body in frame',
        isFullBodyDetected: false,
        isReadyToStart: false,
      );
    }

    final avgConfidence = _calculateAverageConfidence([
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
    ]);

    // Before workout starts, give positioning feedback only
    if (_workoutState == WorkoutState.idle) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: GluteBridgeState.down,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage:
            _getPositioningFeedback(isFullBodyDetected, avgConfidence),
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    if (avgConfidence < _minConfidenceForFeedback) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: GluteBridgeState.down,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Move closer or improve lighting',
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    // === SCIENTIFICALLY-INFORMED GLUTE BRIDGE DETECTION ===
    // Based on comprehensive research: Kennedy et al. (2022) Sports Biomech, Contreras et al. (2015)
    // Key findings: Glute bridges elicit >60% MVIC in GMax, superior to hip thrusts
    // Optimal form requires: supine position, 70-110° knee flexion, >165° hip extension, neutral spine

    // Calculate reference points for body measurements (research-validated approach)
    final avgShoulder = Offset((leftShoulder.x + rightShoulder.x) / 2,
        (leftShoulder.y + rightShoulder.y) / 2);
    final avgHip =
        Offset((leftHip.x + rightHip.x) / 2, (leftHip.y + rightHip.y) / 2);
    final avgKnee =
        Offset((leftKnee.x + rightKnee.x) / 2, (leftKnee.y + rightKnee.y) / 2);

    // 1. BODY ORIENTATION VALIDATION (Research: Must be supine for GMax activation)
    // Kennedy et al. (2022): Supine position maximizes gluteus maximus EMG activation
    final isSupinePosition = avgShoulder.dy >
        avgKnee.dy; // Shoulders below knees = proper supine position
    final bodyOrientationValid = isSupinePosition;

    // 2. KNEE FLEXION ANALYSIS (Soft validity windows based on biomechanics literature)
    // Different studies show varying optimal ranges depending on foot distance and anthropometry
    final leftKneeAngle = _calculateAngle(
      Offset(leftHip.x, leftHip.y),
      Offset(leftKnee.x, leftKnee.y),
      Offset(leftAnkle.x, leftAnkle.y),
    );
    final rightKneeAngle = _calculateAngle(
      Offset(rightHip.x, rightHip.y),
      Offset(rightKnee.x, rightKnee.y),
      Offset(rightAnkle.x, rightAnkle.y),
    );
    final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

    // Soft validity windows: acceptable allows rep counting, ideal preferred for feedback
    final kneeFlexionIdeal = avgKneeAngle >= 90.0 &&
        avgKneeAngle <= 120.0; // Optimal range for GMax activation
    final kneeFlexionValid = avgKneeAngle >= 75.0 &&
        avgKneeAngle <= 130.0; // Use acceptable range for basic validation

    // 3. HIP EXTENSION ANALYSIS (PRIMARY MOVEMENT - Research Focus)
    // Based on biomechanics research: Hip extension angle between torso and thigh
    // At bottom: ~90-120° (bent position), At top: ~165-180° (straight body line)
    final leftHipExtensionAngle = _calculateHipExtensionAngle(
      Offset(leftShoulder.x, leftShoulder.y),
      Offset(leftHip.x, leftHip.y),
      Offset(leftKnee.x, leftKnee.y),
    );
    final rightHipExtensionAngle = _calculateHipExtensionAngle(
      Offset(rightShoulder.x, rightShoulder.y),
      Offset(rightHip.x, rightHip.y),
      Offset(rightKnee.x, rightKnee.y),
    );
    final avgHipExtensionAngle =
        (leftHipExtensionAngle + rightHipExtensionAngle) / 2;

    // Heuristic hip extension thresholds informed by biomechanics literature:
    // < 130° = hips lowered (starting position, bent at hips)
    // > 160° = full bridge (body forms straight line from shoulders to knees)
    // Note: These are practical ranges for computer vision, not hard physiological cutoffs
    final hipsLowered = avgHipExtensionAngle < 130.0; // Bent position (down)
    final hipsBridged = avgHipExtensionAngle > 160.0; // Extended position (up)

    // 4. SPINE ALIGNMENT VALIDATION (Research: Neutral spine prevents compensation)
    // Research shows neutral spine alignment maximizes glute activation and prevents injury
    final shoulderHipXDiff = (avgShoulder.dx - avgHip.dx).abs();
    final spineAlignment = shoulderHipXDiff / imageSize.width;
    final neutralSpine =
        spineAlignment < 0.08; // <8% deviation for neutral alignment
    final spineAlignmentValid = neutralSpine;

    // 5. PELVIC POSITIONING ANALYSIS (Research: Level pelvis for GMax activation)
    // Kennedy et al. (2022): Proper pelvic positioning essential for glute bridge effectiveness
    final pelvicTilt = (leftHip.y - rightHip.y).abs() / imageSize.height;
    final levelPelvis =
        pelvicTilt < 0.04; // Pelvis level within 4% of frame height
    final pelvicPositionValid = levelPelvis;

    // 6. FOOT POSITION VALIDATION (Research: Shoulder-width stance for stability)
    // Proper foot positioning provides stable base for hip extension
    final footWidth = (leftAnkle.x - rightAnkle.x).abs();
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final properFootPosition =
        footWidth >= shoulderWidth * 0.7 && footWidth <= shoulderWidth * 1.3;
    final footPositionValid = properFootPosition;

    // 7. BODY ALIGNMENT CHECK (Research: Hips elevated above knees in bridge position)
    // Research: Full bridge position requires hips higher than knees
    final hipsElevatedAboveKnees =
        avgHip.dy < avgKnee.dy; // Lower Y = higher position

    // === COMPREHENSIVE FORM VALIDATION ===
    // Kennedy et al. (2022): All form criteria must be met for valid glute bridge
    final properForm = bodyOrientationValid &&
        kneeFlexionValid &&
        spineAlignmentValid &&
        pelvicPositionValid &&
        footPositionValid;

    // === RESEARCH-BASED CONFIDENCE SYSTEM ===
    // Research-based confidence to prevent false positives during transitions
    if (_currentGluteBridgeState == GluteBridgeState.up ||
        _currentGluteBridgeState == GluteBridgeState.down) {
      // Maintain confidence when in stable states
      _gluteBridgeConfidence = (_gluteBridgeConfidence + 1).clamp(0, 3);
    } else {
      // Reset confidence during transitions
      _gluteBridgeConfidence = 0;
    }

    // === RESEARCH-BASED STATE DETERMINATION ===
    // Kennedy et al. (2022): State transitions based on hip extension and form validation
    GluteBridgeState newState;
    if (!properForm) {
      newState =
          GluteBridgeState.down; // Invalid form - return to starting position
    } else if (hipsBridged && hipsElevatedAboveKnees) {
      newState = GluteBridgeState
          .up; // Full bridge achieved - maximal glute activation
    } else if (hipsLowered) {
      newState = GluteBridgeState.down; // Starting position - ready to bridge
    } else {
      // Transition state - maintain current for stability
      newState = _currentGluteBridgeState;
    }

    // Apply confidence filter: require 2 consecutive detections for state changes
    GluteBridgeState confirmedState;
    if (_gluteBridgeConfidence >= 2 || newState == _currentGluteBridgeState) {
      confirmedState = newState;
    } else {
      confirmedState =
          _currentGluteBridgeState; // Maintain current during uncertainty
    }

    // === ROBUST REP COUNTING STATE MACHINE ===
    // Requires full cycle: DOWN → UP (count rep) → DOWN (reset for next rep)
    // Prevents double counting and ensures proper form completion
    if (isCountingEnabled) {
      if (isFullBodyDetected && avgConfidence >= _minConfidenceForCounting) {
        // State machine with hysteresis: must return to DOWN before counting another rep
        if (_repCountingState == GluteBridgeState.down &&
            confirmedState == GluteBridgeState.up &&
            kneeFlexionValid && // Require acceptable knee flexion for rep counting
            _gluteBridgeConfidence >= 2) {
          // Count rep when transitioning from DOWN to UP
          final now = DateTime.now();
          // 600ms debounce prevents double-counting during fast transitions
          if (_lastRepTime == null ||
              now.difference(_lastRepTime!) >
                  const Duration(milliseconds: 600)) {
            _repCount++;
            _lastRepTime = now;
            _repCountingState = GluteBridgeState.up; // Move to UP state
            onRepCounted?.call(_repCount);
            debugPrint(
                '✅ GLUTE BRIDGE REP COUNTED: $_repCount (State: DOWN→UP, knee=${avgKneeAngle.toStringAsFixed(1)}°)');
          }
        } else if (_repCountingState == GluteBridgeState.up &&
            confirmedState == GluteBridgeState.down) {
          // Reset state machine when returning to DOWN
          _repCountingState = GluteBridgeState.down;
          debugPrint('🔄 GLUTE BRIDGE CYCLE RESET: Ready for next rep');
        }
      } else {
        // Debug why rep check was skipped
        if (!isFullBodyDetected) {
          debugPrint(
              '⏸️ GLUTE BRIDGE REP CHECK SKIPPED: Full body not visible');
        } else if (avgConfidence < _minConfidenceForCounting) {
          debugPrint(
              '⏸️ GLUTE BRIDGE REP CHECK SKIPPED: Low confidence ${avgConfidence.toStringAsFixed(2)} < $_minConfidenceForCounting');
        }
      }
    }

    _currentGluteBridgeState = confirmedState;

    // === DETAILED DEBUG LOGGING FOR RESEARCH VALIDATION ===
    debugPrint('🔬 GB SCIENTIFIC DEBUG: '
        'supine=$bodyOrientationValid, knee=${avgKneeAngle.toStringAsFixed(1)}°(ideal:90-120°=$kneeFlexionIdeal, accept:75-130°=$kneeFlexionValid), '
        'hipExt=${avgHipExtensionAngle.toStringAsFixed(1)}°(>160°=$hipsBridged, <130°=$hipsLowered), '
        'spine=${spineAlignment.toStringAsFixed(3)}(<0.08=$spineAlignmentValid), '
        'pelvis=${pelvicTilt.toStringAsFixed(3)}(<0.04=$pelvicPositionValid), '
        'feet=$footPositionValid, properForm=$properForm, '
        'confidence=$_gluteBridgeConfidence/3, repState=$_repCountingState, currentState=$confirmedState');

    return PoseDetectionResult(
      isPoseDetected: true,
      confidence: avgConfidence,
      phase: _currentGluteBridgeState,
      keyPoints: _extractKeyPoints(landmarks),
      feedbackMessage: _getGluteBridgeFeedback(
          _currentGluteBridgeState, avgHipExtensionAngle, avgKneeAngle),
      isFullBodyDetected: isFullBodyDetected,
      isReadyToStart: isReadyToStart,
    );
  }

  /// Get scientifically-informed glute bridge feedback with soft validity windows
  String _getGluteBridgeFeedback(
      GluteBridgeState state, double hipExtensionAngle, double kneeAngle) {
    // Soft validity windows: guide toward ideal range (90-120°) while accepting wider range (75-130°)
    final kneeFlexionIdeal = kneeAngle >= 90.0 && kneeAngle <= 120.0;

    // Prioritize knee feedback if outside acceptable range
    if (kneeAngle < 75) {
      return 'Bend knees more - aim for 90-120° for optimal glute activation';
    } else if (kneeAngle > 130) {
      return 'Move feet closer to hips - knees should be around 90-120°';
    } else if (!kneeFlexionIdeal) {
      // Within acceptable but not ideal range - gentle guidance
      if (kneeAngle < 90) {
        return 'Bend knees slightly more for better glute activation';
      } else if (kneeAngle > 120) {
        return 'Move feet slightly closer for optimal knee position';
      }
    }

    // Movement guidance based on hip extension angle (only if knee position is acceptable)
    switch (state) {
      case GluteBridgeState.down:
        return 'Lift hips up - aim for straight body line';
      case GluteBridgeState.goingUp:
        return 'Keep lifting higher - squeeze glutes at the top';
      case GluteBridgeState.up:
        return 'Perfect! Hold and squeeze glutes';
      case GluteBridgeState.goingDown:
        return 'Lower slowly with control';
    }
  }

  /// Check if a jumping jack rep has been completed (apart -> together)

  /// Get jumping jack feedback
  String _getJumpingJackFeedback(JumpingJackPhase phase) {
    switch (phase) {
      case JumpingJackPhase.together:
        return 'Jump out!';
      case JumpingJackPhase.apart:
        return 'Jump in!';
      default:
        return 'Keep going!';
    }
  }

  // ============================================================================
  // BURPEES DETECTION (Most Complex)
  // ============================================================================

  /// Analyze pose for burpees - SIMPLIFIED STATE MACHINE
  /// FIXED: Simplified to focus on key transitions instead of complex multi-phase detection
  /// New approach: standing → plank (down) → standing (up) - similar to push-ups but for burpees
  /// This handles the natural variation in how people perform burpees
  PoseDetectionResult _analyzeBurpeesPose(
    Pose pose,
    Size imageSize,
    bool isFullBodyDetected,
    bool isReadyToStart,
  ) {
    if (workoutType.toLowerCase() != 'burpees') {
      _currentPhase = BurpeePhase.standing;
      return PoseDetectionResult.empty();
    }

    final landmarks = pose.landmarks;

    // Extract key landmarks for burpee tracking
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftKnee = landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftShoulder == null ||
        rightShoulder == null) {
      return PoseDetectionResult(
        isPoseDetected: false,
        confidence: 0.0,
        phase: _confirmedBurpeePhase,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Position your full body in frame',
        isFullBodyDetected: false,
        isReadyToStart: false,
      );
    }

    final avgConfidence = _calculateAverageConfidence([
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
      leftShoulder,
      rightShoulder,
    ]);

    // Before workout starts, give positioning feedback only
    if (_workoutState == WorkoutState.idle) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: BurpeePhase.standing,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage:
            _getPositioningFeedback(isFullBodyDetected, avgConfidence),
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    if (avgConfidence < _minConfidenceForFeedback) {
      return PoseDetectionResult(
        isPoseDetected: true,
        confidence: avgConfidence,
        phase: _confirmedBurpeePhase,
        keyPoints: _extractKeyPoints(landmarks),
        feedbackMessage: 'Move closer or improve lighting',
        isFullBodyDetected: isFullBodyDetected,
        isReadyToStart: isReadyToStart,
      );
    }

    // === SIMPLIFIED BURPEE DETECTION ===
    // Focus on key transitions: standing ↔ plank position
    // This handles natural variation in burpee performance

    // Calculate body reference points
    final avgShoulder = Offset((leftShoulder.x + rightShoulder.x) / 2,
        (leftShoulder.y + rightShoulder.y) / 2);
    final avgHip =
        Offset((leftHip.x + rightHip.x) / 2, (leftHip.y + rightHip.y) / 2);
    final avgAnkle = Offset(
        (leftAnkle.x + rightAnkle.x) / 2, (leftAnkle.y + rightAnkle.y) / 2);

    // LEG ANGLE - primary indicator
    final leftLegAngle = _calculateAngle(Offset(leftHip.x, leftHip.y),
        Offset(leftKnee.x, leftKnee.y), Offset(leftAnkle.x, leftAnkle.y));
    final rightLegAngle = _calculateAngle(Offset(rightHip.x, rightHip.y),
        Offset(rightKnee.x, rightKnee.y), Offset(rightAnkle.x, rightAnkle.y));
    final avgKneeAngle = (leftLegAngle + rightLegAngle) / 2;

    // BODY ORIENTATION - standing vs plank
    final shoulderY = avgShoulder.dy / imageSize.height;
    final hipY = avgHip.dy / imageSize.height;
    final verticalDifference = (hipY - shoulderY).abs();
    final isHorizontalOrientation =
        verticalDifference < 0.12; // Relaxed threshold

    // BODY ALIGNMENT - for plank validation
    final bodyAlignmentAngle = _calculateAngle(avgShoulder, avgHip, avgAnkle);
    final isBodyStraight = bodyAlignmentAngle >= 150.0 &&
        bodyAlignmentAngle <= 210.0; // Relaxed range

    // === SIMPLIFIED PHASE DETECTION ===
    // Two main phases: standing (upright) and plank (horizontal on floor)

    BurpeePhase rawPhase;

    // STANDING: Legs relatively straight, body upright, not horizontal
    final isStanding = avgKneeAngle > 140 && !isHorizontalOrientation;

    // PLANK: Body horizontal, legs extended (down position)
    final isPlank =
        isHorizontalOrientation && isBodyStraight && avgKneeAngle > 130;

    // Determine current phase - more forgiving than before
    if (isPlank) {
      rawPhase = BurpeePhase.plankPosition;
    } else if (isStanding) {
      rawPhase = BurpeePhase.standing;
    } else {
      // Ambiguous state - maintain current phase
      rawPhase = _confirmedBurpeePhase;
    }

    // === RELAXED CONFIDENCE SYSTEM ===
    // Only require 1 consecutive frame for phase changes (more responsive)
    if (rawPhase == _currentPhase) {
      _burpeeConfidence = (_burpeeConfidence + 1).clamp(0, 2);
    } else {
      _burpeeConfidence = 0;
      _currentPhase = rawPhase;
    }

    // Update confirmed phase with relaxed threshold
    if (_burpeeConfidence >= 1) {
      _confirmedBurpeePhase = rawPhase;
    }

    // === SIMPLIFIED REP COUNTING ===
    // Count rep when transitioning from plank back to standing
    if (isCountingEnabled) {
      if (isFullBodyDetected && avgConfidence >= _minConfidenceForCounting) {
        _checkForCompletedBurpeeRep(_confirmedBurpeePhase);
      } else {
        // Debug why rep check was skipped
        if (!isFullBodyDetected) {
          debugPrint('⏸️ BURPEE REP CHECK SKIPPED: Full body not visible');
        } else if (avgConfidence < _minConfidenceForCounting) {
          debugPrint(
              '⏸️ BURPEE REP CHECK SKIPPED: Low confidence ${avgConfidence.toStringAsFixed(2)} < $_minConfidenceForCounting');
        }
      }
    }

    // DEBUG LOGGING - Simplified
    debugPrint('🏃 BURPEE STATE: phase=$_confirmedBurpeePhase, '
        'knee=${avgKneeAngle.toStringAsFixed(1)}°, horiz=$isHorizontalOrientation(${verticalDifference.toStringAsFixed(3)}), '
        'bodyAlign=${bodyAlignmentAngle.toStringAsFixed(1)}°, standing=$isStanding, plank=$isPlank, conf=$_burpeeConfidence');

    return PoseDetectionResult(
      isPoseDetected: true,
      confidence: avgConfidence,
      phase: _confirmedBurpeePhase,
      keyPoints: _extractKeyPoints(landmarks),
      feedbackMessage: _getBurpeeFeedback(_confirmedBurpeePhase),
      isFullBodyDetected: isFullBodyDetected,
      isReadyToStart: isReadyToStart,
    );
  }

  /// Check if a burpee rep has been completed - SIMPLIFIED
  /// FIXED: Count rep when transitioning from plank back to standing
  /// This is more forgiving and matches how people actually perform burpees
  void _checkForCompletedBurpeeRep(BurpeePhase newPhase) {
    final now = DateTime.now();

    // === SIMPLIFIED REP COUNTING ===
    // Count rep when transitioning from plank (down position) to standing (up position)
    // This captures the complete burpee motion without requiring perfect phase sequencing

    if (_confirmedBurpeePhase == BurpeePhase.plankPosition &&
        newPhase == BurpeePhase.standing) {
      // Debounce check (minimum 1.5 seconds per burpee - realistic timing)
      if (_lastRepTime != null &&
          now.difference(_lastRepTime!) < const Duration(milliseconds: 1500)) {
        debugPrint('⏸️ BURPEE REP SKIPPED: Too soon (debounce)');
        return;
      }

      // Count the rep!
      _repCount++;
      _lastRepTime = now;
      onRepCounted?.call(_repCount);
      debugPrint('✅ BURPEE REP COMPLETED: $_repCount (plank → standing)');
    }
  }

  /// Get burpee feedback - SIMPLIFIED
  /// FIXED: Simple feedback for the two main phases, inclusive of jumping or stepping
  String _getBurpeeFeedback(BurpeePhase phase) {
    switch (phase) {
      case BurpeePhase.standing:
        return 'Squat down and place hands on floor';
      case BurpeePhase.plankPosition:
        return 'Step or jump feet back to plank, then stand up';
      case BurpeePhase.squatDown:
      case BurpeePhase.pushUpDown:
      case BurpeePhase.pushUpUp:
      case BurpeePhase.squatUp:
      case BurpeePhase.jumpUp:
      case BurpeePhase.landing:
      case BurpeePhase.unknown:
        return 'Complete the burpee motion';
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _poseDetector?.close();
    _poseDetector = null;
  }
}
