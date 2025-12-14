/// Represents a period of unlocked access earned through workout completion.
/// Immutable domain model tracking session duration and reason.
class UnlockSession {
  final String id;
  final DateTime startTime;
  final int durationSeconds; // Total allowed access time
  final String reason; // 'workout_completed', 'emergency_override', etc.

  UnlockSession({
    required this.id,
    required this.startTime,
    required this.durationSeconds,
    required this.reason,
  }) : assert(durationSeconds > 0, 'durationSeconds must be positive'),
       assert(reason.isNotEmpty, 'reason cannot be empty');

  // Pure calculations - no side effects
  DateTime get endTime => startTime.add(Duration(seconds: durationSeconds));
  
  int getRemainingSeconds(DateTime now) {
    final remaining = endTime.difference(now).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
  
  bool isExpired(DateTime now) => now.isAfter(endTime);

  factory UnlockSession.fromJson(Map<String, dynamic> json) {
    return UnlockSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      durationSeconds: json['durationSeconds'] as int,
      reason: json['reason'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'durationSeconds': durationSeconds,
      'reason': reason,
    };
  }

  @override
  String toString() => 'UnlockSession(id: $id, durationSeconds: $durationSeconds, reason: $reason)';

  @override
  bool operator ==(Object other) => 
    identical(this, other) || 
    other is UnlockSession && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

