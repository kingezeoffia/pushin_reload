import 'package:health/health.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for fetching health data from Apple Health (iOS)
/// and Google Fit (Android)
class HealthKitService {
  static final HealthKitService _instance = HealthKitService._internal();
  factory HealthKitService() => _instance;
  HealthKitService._internal();

  final Health _health = Health();
  bool _isAuthorized = false;

  // SharedPreferences key for caching permission state
  static const String _permissionKey = 'health_kit_permission_granted';

  /// Health data types we want to read
  static final List<HealthDataType> _dataTypes = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.FLIGHTS_CLIMBED,
  ];

  /// Request authorization to access health data
  Future<bool> requestAuthorization() async {
    try {
      // Check if platform supports Health
      if (!Platform.isIOS && !Platform.isAndroid) {
        print('HealthKitService: Platform not supported');
        return false;
      }

      // Request permissions
      _isAuthorized = await _health.requestAuthorization(
        _dataTypes,
        permissions: _dataTypes.map((type) => HealthDataAccess.READ).toList(),
      );

      print('HealthKitService: Authorization ${_isAuthorized ? "granted" : "denied"}');

      // Save permission state to persistent storage
      if (_isAuthorized) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_permissionKey, true);
        print('HealthKitService: Permission saved to storage');
      }

      return _isAuthorized;
    } catch (e) {
      print('HealthKitService: Authorization error: $e');
      return false;
    }
  }

  /// Check if we have authorization (checks cache first for better UX)
  Future<bool> hasPermissions() async {
    try {
      // First check cached permission state (faster, prevents flicker)
      final prefs = await SharedPreferences.getInstance();
      final cachedPermission = prefs.getBool(_permissionKey) ?? false;

      if (cachedPermission) {
        print('HealthKitService: Using cached permission state: granted');
        _isAuthorized = true;
        return true;
      }

      // If not cached, check with Health API
      final hasPermissions = await _health.hasPermissions(
        _dataTypes,
        permissions: _dataTypes.map((type) => HealthDataAccess.READ).toList(),
      );

      final result = hasPermissions ?? false;

      // Cache the result if granted
      if (result) {
        await prefs.setBool(_permissionKey, true);
        print('HealthKitService: Permission granted and cached');
      }

      _isAuthorized = result;
      return result;
    } catch (e) {
      print('HealthKitService: Error checking permissions: $e');
      return false;
    }
  }

  /// Fetch today's step count
  Future<int> getTodaySteps() async {
    try {
      // Ensure we have permissions
      if (!_isAuthorized) {
        final authorized = await requestAuthorization();
        if (!authorized) {
          print('HealthKitService: Not authorized to read steps');
          return 0;
        }
      }

      // Get today's date range (midnight to now)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Fetch steps data
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: startOfDay,
        endTime: now,
      );

      if (healthData.isEmpty) {
        print('HealthKitService: No step data found for today');
        return 0;
      }

      // Sum up all the step counts
      int totalSteps = 0;
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          totalSteps += (data.value as NumericHealthValue).numericValue.toInt();
        }
      }

      print('HealthKitService: Total steps today: $totalSteps');
      return totalSteps;
    } catch (e) {
      print('HealthKitService: Error fetching steps: $e');
      return 0;
    }
  }

  /// Fetch today's walking/running distance in kilometers
  Future<double> getTodayDistance() async {
    try {
      if (!_isAuthorized) {
        final authorized = await requestAuthorization();
        if (!authorized) return 0.0;
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.DISTANCE_WALKING_RUNNING],
        startTime: startOfDay,
        endTime: now,
      );

      if (healthData.isEmpty) return 0.0;

      double totalDistance = 0.0;
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          // Distance is in meters, convert to kilometers
          totalDistance += (data.value as NumericHealthValue).numericValue / 1000.0;
        }
      }

      print('HealthKitService: Total distance today: ${totalDistance.toStringAsFixed(2)} km');
      return totalDistance;
    } catch (e) {
      print('HealthKitService: Error fetching distance: $e');
      return 0.0;
    }
  }

  /// Fetch today's active calories burned
  Future<int> getTodayCalories() async {
    try {
      if (!_isAuthorized) {
        final authorized = await requestAuthorization();
        if (!authorized) return 0;
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: now,
      );

      if (healthData.isEmpty) return 0;

      double totalCalories = 0.0;
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          totalCalories += (data.value as NumericHealthValue).numericValue;
        }
      }

      print('HealthKitService: Total calories today: ${totalCalories.toInt()} kcal');
      return totalCalories.toInt();
    } catch (e) {
      print('HealthKitService: Error fetching calories: $e');
      return 0;
    }
  }

  /// Fetch today's floors climbed
  Future<int> getTodayFloors() async {
    try {
      if (!_isAuthorized) {
        final authorized = await requestAuthorization();
        if (!authorized) return 0;
      }

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.FLIGHTS_CLIMBED],
        startTime: startOfDay,
        endTime: now,
      );

      if (healthData.isEmpty) return 0;

      int totalFloors = 0;
      for (var data in healthData) {
        if (data.value is NumericHealthValue) {
          totalFloors += (data.value as NumericHealthValue).numericValue.toInt();
        }
      }

      print('HealthKitService: Total floors today: $totalFloors');
      return totalFloors;
    } catch (e) {
      print('HealthKitService: Error fetching floors: $e');
      return 0;
    }
  }

  /// Clear cached permission state (useful for testing/debugging)
  Future<void> clearPermissionCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_permissionKey);
      _isAuthorized = false;
      print('HealthKitService: Permission cache cleared');
    } catch (e) {
      print('HealthKitService: Error clearing cache: $e');
    }
  }

  /// Get all today's health stats in one call
  Future<HealthStats> getTodayStats() async {
    try {
      // Request authorization if needed
      if (!_isAuthorized) {
        final authorized = await requestAuthorization();
        if (!authorized) {
          return HealthStats.empty();
        }
      }

      // Fetch all data in parallel for better performance
      final results = await Future.wait([
        getTodaySteps(),
        getTodayDistance(),
        getTodayCalories(),
        getTodayFloors(),
      ]);

      return HealthStats(
        steps: results[0] as int,
        distance: results[1] as double,
        calories: results[2] as int,
        floors: results[3] as int,
      );
    } catch (e) {
      print('HealthKitService: Error fetching today stats: $e');
      return HealthStats.empty();
    }
  }
}

/// Container for health statistics
class HealthStats {
  final int steps;
  final double distance;
  final int calories;
  final int floors;

  HealthStats({
    required this.steps,
    required this.distance,
    required this.calories,
    required this.floors,
  });

  factory HealthStats.empty() => HealthStats(
        steps: 0,
        distance: 0.0,
        calories: 0,
        floors: 0,
      );

  @override
  String toString() {
    return 'HealthStats(steps: $steps, distance: ${distance.toStringAsFixed(2)}km, calories: $calories, floors: $floors)';
  }
}
