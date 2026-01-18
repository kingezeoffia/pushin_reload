import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service for detecting phone stability using accelerometer and gyroscope sensors
/// Used to determine when phone has been placed down and is stable
class PhoneStabilityService {
  static const Duration _stabilityCheckDuration = Duration(seconds: 2);
  static const double _stabilityThreshold = 0.15; // m/s² tolerance for movement
  static const double _orientationThreshold = 0.2; // threshold for reasonable workout orientation

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<UserAccelerometerEvent>? _userAccelSubscription;
  Timer? _stabilityTimer;

  bool _isStable = false;
  bool _isProperlyOriented = false;
  bool _isDetectingStability = false;
  DateTime? _stabilityStartTime;

  final StreamController<StabilityState> _stabilityController = StreamController<StabilityState>.broadcast();
  Stream<StabilityState> get onStabilityStateChanged => _stabilityController.stream;

  /// Current stability state
  StabilityState get currentState => StabilityState(
    isStable: _isStable,
    isFlat: _isProperlyOriented, // For backwards compatibility, represents proper workout orientation
    isDetecting: _isDetectingStability,
  );

  /// Start stability detection
  void startStabilityDetection() {
    if (_isDetectingStability) return;

    _isDetectingStability = true;
    _isStable = false;
    _isProperlyOriented = false;

    // Listen to accelerometer for absolute movement detection
    _accelerometerSubscription = accelerometerEventStream().listen(
      _onAccelerometerEvent,
      onError: (error) => debugPrint('Accelerometer error: $error'),
    );

    // Listen to user accelerometer for device-relative movement (without gravity)
    _userAccelSubscription = userAccelerometerEventStream().listen(
      _onUserAccelerometerEvent,
      onError: (error) => debugPrint('User Accelerometer error: $error'),
    );

    _notifyStateChange();
    debugPrint('PhoneStabilityService: Started stability detection');
  }

  /// Stop stability detection
  void stopStabilityDetection() {
    _isDetectingStability = false;
    _isStable = false;
    _isProperlyOriented = false;
    _stabilityStartTime = null;

    _accelerometerSubscription?.cancel();
    _userAccelSubscription?.cancel();
    _stabilityTimer?.cancel();

    _notifyStateChange();
    debugPrint('PhoneStabilityService: Stopped stability detection');
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    if (!_isDetectingStability) return;

    // Calculate total acceleration magnitude
    final totalAccel = math.sqrt(
      event.x * event.x +
      event.y * event.y +
      event.z * event.z
    );

    // Check if phone is stable (close to gravity acceleration of ~9.81 m/s²)
    final isCurrentlyStable = (totalAccel - 9.81).abs() < _stabilityThreshold;

    if (isCurrentlyStable && !_isStable) {
      // Movement stopped - start stability timer
      _startStabilityTimer();
    } else if (!isCurrentlyStable && _isStable) {
      // Movement detected - reset stability
      _resetStability();
    }
  }

  void _onUserAccelerometerEvent(UserAccelerometerEvent event) {
    if (!_isDetectingStability) return;

    // For workout positioning, we need the phone to be in a reasonable orientation
    // The phone should be placed at an angle where the camera can see the user
    // Z-axis user acceleration should be between -2.0 (almost flat) and 0.2 (slightly tilted up)
    final isReasonableOrientation = event.z > -2.0 && event.z < _orientationThreshold;

    final wasReasonable = _isProperlyOriented;
    _isProperlyOriented = isReasonableOrientation;

    // If orientation becomes unreasonable (phone upside down or too tilted), reset stability
    if (wasReasonable && !isReasonableOrientation && _isStable) {
      _resetStability();
    }

    _notifyStateChange();
  }

  void _startStabilityTimer() {
    _stabilityStartTime = DateTime.now();
    _stabilityTimer?.cancel();

    _stabilityTimer = Timer(_stabilityCheckDuration, () {
      if (_isProperlyOriented && _isDetectingStability) {
        _isStable = true;
        _notifyStateChange();
        debugPrint('PhoneStabilityService: Phone detected as stable and properly oriented for workout!');
      }
    });
  }

  void _resetStability() {
    _isStable = false;
    _stabilityStartTime = null;
    _stabilityTimer?.cancel();
    _notifyStateChange();
    debugPrint('PhoneStabilityService: Stability reset due to movement');
  }

  void _notifyStateChange() {
    if (!_stabilityController.isClosed) {
      _stabilityController.add(currentState);
    }
  }

  /// Dispose of resources
  void dispose() {
    stopStabilityDetection();
    _stabilityController.close();
  }
}

/// State class for stability detection
class StabilityState {
  final bool isStable;
  final bool isFlat;
  final bool isDetecting;

  const StabilityState({
    required this.isStable,
    required this.isFlat,
    required this.isDetecting,
  });

  @override
  String toString() {
    return 'StabilityState(isStable: $isStable, isFlat: $isFlat, isDetecting: $isDetecting)';
  }
}