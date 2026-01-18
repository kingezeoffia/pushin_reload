import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

/// Service for detecting phone stability using accelerometer and gyroscope sensors
/// Used to determine when phone has been placed down and is stable
class PhoneStabilityService {
  static const Duration _stabilityCheckDuration = Duration(seconds: 2);
  static const double _stabilityThreshold = 0.15; // m/s² tolerance for movement
  static const double _flatOrientationThreshold = 0.4; // radians tolerance for flat orientation

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<UserAccelerometerEvent>? _userAccelSubscription;
  Timer? _stabilityTimer;

  bool _isStable = false;
  bool _isFlat = false;
  bool _isDetectingStability = false;

  final StreamController<StabilityState> _stabilityController = StreamController<StabilityState>.broadcast();
  Stream<StabilityState> get onStabilityStateChanged => _stabilityController.stream;

  /// Current stability state
  StabilityState get currentState => StabilityState(
    isStable: _isStable,
    isFlat: _isFlat,
    isDetecting: _isDetectingStability,
  );

  /// Start stability detection
  void startStabilityDetection() {
    if (_isDetectingStability) return;

    _isDetectingStability = true;
    _isStable = false;
    _isFlat = false;
    _stabilityStartTime = null;

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
    _isFlat = false;
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

    // Check if phone is lying flat (Z-axis acceleration close to 0)
    // When phone is flat on surface, Z-axis should be close to 0 (against gravity)
    final isCurrentlyFlat = event.z.abs() < _flatOrientationThreshold;

    final wasFlat = _isFlat;
    _isFlat = isCurrentlyFlat;

    // If orientation changed from flat to not flat, reset stability
    if (wasFlat && !isCurrentlyFlat && _isStable) {
      _resetStability();
    }

    _notifyStateChange();
  }

  void _startStabilityTimer() {
    _stabilityStartTime = DateTime.now();
    _stabilityTimer?.cancel();

    _stabilityTimer = Timer(_stabilityCheckDuration, () {
      if (_isFlat && _isDetectingStability) {
        _isStable = true;
        _notifyStateChange();
        debugPrint('PhoneStabilityService: Phone detected as stable and flat!');
      }
    });
  }

  void _resetStability() {
    _isStable = false;
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