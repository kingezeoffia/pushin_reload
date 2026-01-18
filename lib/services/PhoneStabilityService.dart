import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service for detecting phone stability using accelerometer sensors
/// Used to determine when phone has been placed and is no longer moving
class PhoneStabilityService {
  static const Duration _stabilityCheckDuration = Duration(seconds: 2);
  static const double _stabilityThreshold = 0.2; // m/s² tolerance for movement

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _stabilityTimer;

  bool _isStable = false;
  bool _isDetectingStability = false;
  int _stableReadingCount = 0;
  static const int _requiredStableReadings = 30; // ~1.5 seconds at typical sensor rate

  final StreamController<StabilityState> _stabilityController = StreamController<StabilityState>.broadcast();
  Stream<StabilityState> get onStabilityStateChanged => _stabilityController.stream;

  /// Current stability state
  StabilityState get currentState => StabilityState(
    isStable: _isStable,
    isDetecting: _isDetectingStability,
  );

  /// Start stability detection
  void startStabilityDetection() {
    if (_isDetectingStability) return;

    _isDetectingStability = true;
    _isStable = false;
    _stableReadingCount = 0;

    // Listen to accelerometer for movement detection
    _accelerometerSubscription = accelerometerEventStream().listen(
      _onAccelerometerEvent,
      onError: (error) => debugPrint('Accelerometer error: $error'),
    );

    _notifyStateChange();
    debugPrint('PhoneStabilityService: Started stability detection');
  }

  /// Stop stability detection
  void stopStabilityDetection() {
    _isDetectingStability = false;
    _isStable = false;
    _stableReadingCount = 0;

    _accelerometerSubscription?.cancel();
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
    // Any significant deviation indicates movement
    final isCurrentlyStable = (totalAccel - 9.81).abs() < _stabilityThreshold;

    if (isCurrentlyStable) {
      _stableReadingCount++;
      // Start timer when we get first stable reading
      if (_stableReadingCount == 1) {
        _startStabilityTimer();
      }
    } else {
      // Movement detected - reset counter
      if (_stableReadingCount > 0) {
        _stableReadingCount = 0;
        _stabilityTimer?.cancel();
        if (_isStable) {
          _isStable = false;
          _notifyStateChange();
          debugPrint('PhoneStabilityService: Movement detected, stability reset');
        }
      }
    }
  }

  void _startStabilityTimer() {
    _stabilityTimer?.cancel();

    _stabilityTimer = Timer(_stabilityCheckDuration, () {
      if (_isDetectingStability && _stableReadingCount >= _requiredStableReadings) {
        _isStable = true;
        _notifyStateChange();
        debugPrint('PhoneStabilityService: Phone detected as stable!');
      }
    });
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
  final bool isDetecting;

  const StabilityState({
    required this.isStable,
    required this.isDetecting,
  });

  @override
  String toString() {
    return 'StabilityState(isStable: $isStable, isDetecting: $isDetecting)';
  }
}