import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'PoseDetectionService.dart';

/// Camera workout service state
enum CameraServiceState {
  uninitialized,
  requestingPermission,
  permissionDenied,
  initializing,
  ready,
  running,
  paused,
  error,
  disposed,
}

/// Camera workout service for managing camera and pose detection
class CameraWorkoutService extends ChangeNotifier {
  CameraController? _cameraController;
  PoseDetectionService? _poseDetectionService;

  CameraServiceState _state = CameraServiceState.uninitialized;
  String? _errorMessage;
  bool _isProcessingFrame = false;
  int _frameSkipCounter = 0;
  String _workoutType = 'push-ups'; // Current workout type

  // Process every N frames to maintain performance
  int get _frameSkipRate => _workoutType == 'jumping-jacks'
      ? 1
      : 3; // Process 1 in every 1 frame for jumping jacks (~30 FPS), 3 for others (~10 FPS)

  // Current detection result
  PoseDetectionResult _lastResult = PoseDetectionResult.empty();

  // Rep count and timer
  int _repCount = 0;
  int _elapsedSeconds = 0;

  // Callbacks
  Function(int)? onRepCounted;
  Function(PoseDetectionResult)? onPoseUpdate;
  Function(int)? onTimerUpdate; // For time-based workouts

  /// Get current state
  CameraServiceState get state => _state;

  /// Get error message
  String? get errorMessage => _errorMessage;

  /// Get camera controller
  CameraController? get cameraController => _cameraController;

  /// Get current rep count
  int get repCount => _repCount;

  /// Get elapsed seconds (for time-based workouts)
  int get elapsedSeconds => _elapsedSeconds;

  /// Get last pose detection result
  PoseDetectionResult get lastResult => _lastResult;

  /// Check if camera is ready
  bool get isReady =>
      _state == CameraServiceState.ready ||
      _state == CameraServiceState.running;

  /// Get pose detection service (for accessing workout state)
  PoseDetectionService? get poseDetectionService => _poseDetectionService;

  /// Get current workout type
  String get workoutType => _workoutType;

  /// Initialize camera and pose detection
  Future<bool> initialize({
    required String workoutType,
    CameraLensDirection preferredCamera = CameraLensDirection.front,
  }) async {
    _workoutType = workoutType;
    if (_state != CameraServiceState.uninitialized &&
        _state != CameraServiceState.error &&
        _state != CameraServiceState.permissionDenied) {
      return isReady;
    }

    try {
      debugPrint('Checking camera permission...');

      // Try to get cameras first - this will fail if no permission
      debugPrint('Attempting to get available cameras...');
      List<CameraDescription> cameras;
      try {
        cameras = await availableCameras();
        debugPrint(
            'Successfully got ${cameras.length} cameras - permission likely granted');
      } catch (e) {
        debugPrint('Failed to get cameras: $e - permission likely denied');

        // Check permission status for better error message
        final currentStatus = await Permission.camera.status;
        debugPrint('Current camera permission status: $currentStatus');

        if (currentStatus.isPermanentlyDenied) {
          _state = CameraServiceState.permissionDenied;
          _errorMessage =
              'Camera permission permanently denied. Please enable in Settings > Privacy > Camera.';
          notifyListeners();
          return false;
        } else {
          debugPrint('Requesting camera permission...');
          _state = CameraServiceState.requestingPermission;
          notifyListeners();

          final status = await Permission.camera.request();
          debugPrint('Permission request result: $status');

          if (!status.isGranted) {
            debugPrint('Camera permission denied');
            _state = CameraServiceState.permissionDenied;
            _errorMessage = 'Camera permission denied';
            notifyListeners();
            return false;
          }
          debugPrint('Camera permission granted after request');

          // Try to get cameras again after permission granted
          try {
            cameras = await availableCameras();
            debugPrint(
                'Successfully got ${cameras.length} cameras after permission');
          } catch (e2) {
            debugPrint('Still failed to get cameras after permission: $e2');
            _state = CameraServiceState.error;
            _errorMessage =
                'Camera access failed even after permission granted';
            notifyListeners();
            return false;
          }
        }
      }

      _state = CameraServiceState.initializing;
      notifyListeners();

      // At this point, cameras should already be available from the permission check above
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        _state = CameraServiceState.error;
        _errorMessage = 'No cameras available on this device';
        notifyListeners();
        return false;
      }

      // Select camera based on preference, fallback to any available camera
      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == preferredCamera,
        orElse: () => cameras.first,
      );

      // Initialize camera controller
      debugPrint(
          'Initializing camera controller with ${preferredCamera == CameraLensDirection.front ? "front" : "back"} camera...');
      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium, // Balance quality and performance
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      debugPrint('Calling camera controller initialize...');
      try {
        await _cameraController!.initialize();
        debugPrint('Camera controller initialized successfully');
      } catch (e) {
        debugPrint('Camera controller initialization failed: $e');
        _state = CameraServiceState.error;
        _errorMessage = 'Camera controller failed to initialize: $e';
        notifyListeners();
        return false;
      }

      // Initialize pose detection service
      debugPrint('Initializing pose detection service for $workoutType...');
      _poseDetectionService = PoseDetectionService(workoutType: workoutType);
      await _poseDetectionService!.initialize();
      debugPrint('Pose detection service initialized successfully');

      // Set up callbacks
      _poseDetectionService!.onRepCounted = (count) {
        debugPrint(
            '📊 REP COUNT CALLBACK: Received count $count, setting _repCount to $count');
        _repCount = count;
        onRepCounted?.call(count);
        notifyListeners();
      };

      _poseDetectionService!.onTimerUpdate = (seconds) {
        debugPrint(
            '⏱️ TIMER UPDATE CALLBACK: Received seconds $seconds, setting _elapsedSeconds to $seconds');
        _elapsedSeconds = seconds;
        onTimerUpdate?.call(seconds);
        notifyListeners();
      };

      _poseDetectionService!.onPoseDetected = (result) {
        _lastResult = result;
        onPoseUpdate?.call(result);
        notifyListeners();
      };

      _poseDetectionService!.onTimerUpdate = (seconds) {
        _elapsedSeconds = seconds;
        onTimerUpdate?.call(seconds);
        notifyListeners();
      };

      _state = CameraServiceState.ready;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('CameraWorkoutService init exception: $e');
      _state = CameraServiceState.error;
      _errorMessage = 'Failed to initialize camera: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start workout session with pose detection
  Future<void> startWorkout() async {
    if (_state != CameraServiceState.ready &&
        _state != CameraServiceState.paused) {
      debugPrint('Cannot start workout in state: $_state');
      return;
    }

    try {
      debugPrint(
          '📸 CameraWorkoutService: Starting workout, resetting repCount to 0');
      _repCount = 0;
      _poseDetectionService?.startWorkout();

      // Start image stream for pose detection
      await _cameraController?.startImageStream(_onCameraFrame);

      _state = CameraServiceState.running;
      notifyListeners();
    } catch (e) {
      _state = CameraServiceState.error;
      _errorMessage = 'Failed to start workout: $e';
      notifyListeners();
      debugPrint('Start workout error: $e');
    }
  }

  /// Process camera frame
  void _onCameraFrame(CameraImage image) async {
    // Skip frames to maintain performance
    _frameSkipCounter++;
    if (_frameSkipCounter < _frameSkipRate) {
      return;
    }
    _frameSkipCounter = 0;

    // Prevent concurrent processing
    if (_isProcessingFrame ||
        _poseDetectionService == null ||
        _cameraController == null) {
      return;
    }

    _isProcessingFrame = true;

    try {
      final rotation = _getImageRotation();
      final imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final result = await _poseDetectionService!.processFrame(
        image,
        rotation,
        imageSize,
      );

      _lastResult = result;
      onPoseUpdate?.call(result);
      notifyListeners();
    } catch (e) {
      debugPrint('Frame processing error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Get image rotation based on camera and device orientation
  InputImageRotation _getImageRotation() {
    // For front camera, we need to account for mirroring
    final camera = _cameraController?.description;
    if (camera == null) return InputImageRotation.rotation0deg;

    final sensorOrientation = camera.sensorOrientation;

    // Map sensor orientation to InputImageRotation
    switch (sensorOrientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  /// Pause workout (stop image stream but keep camera initialized)
  Future<void> pauseWorkout() async {
    if (_state != CameraServiceState.running) return;

    try {
      await _cameraController?.stopImageStream();
      _state = CameraServiceState.paused;
      notifyListeners();
    } catch (e) {
      debugPrint('Pause workout error: $e');
    }
  }

  /// Resume workout
  Future<void> resumeWorkout() async {
    if (_state != CameraServiceState.paused) return;

    try {
      await _cameraController?.startImageStream(_onCameraFrame);
      _state = CameraServiceState.running;
      notifyListeners();
    } catch (e) {
      debugPrint('Resume workout error: $e');
    }
  }

  /// Stop workout and reset state
  Future<void> stopWorkout() async {
    try {
      if (_cameraController?.value.isStreamingImages ?? false) {
        await _cameraController?.stopImageStream();
      }
      _repCount = 0;
      _lastResult = PoseDetectionResult.empty();
      _state = CameraServiceState.ready;
      notifyListeners();
    } catch (e) {
      debugPrint('Stop workout error: $e');
    }
  }

  /// Manually add a rep (fallback for when detection fails)
  void addManualRep() {
    debugPrint('➕ MANUAL REP REQUEST: Current count $_repCount');
    _poseDetectionService?.addManualRep();
    // Update our local count to match
    _repCount = _poseDetectionService?.repCount ?? _repCount;
    debugPrint('✅ MANUAL REP ADDED: New count $_repCount');
    notifyListeners();
  }

  /// Manually add a second for time-based workouts (like plank)
  void addManualSecond() {
    debugPrint('➕ MANUAL SECOND REQUEST: Adding to pose detection service');
    _poseDetectionService?.addManualSecond();
    // Update our local count to match
    _elapsedSeconds = _poseDetectionService?.elapsedSeconds ?? _elapsedSeconds;
    notifyListeners();
  }

  /// Dispose resources
  @override
  Future<void> dispose() async {
    _state = CameraServiceState.disposed;

    try {
      if (_cameraController?.value.isStreamingImages ?? false) {
        await _cameraController?.stopImageStream();
      }
      await _cameraController?.dispose();
      await _poseDetectionService?.dispose();
    } catch (e) {
      debugPrint('Dispose error: $e');
    }

    _cameraController = null;
    _poseDetectionService = null;

    super.dispose();
  }
}
