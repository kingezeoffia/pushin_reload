/// Represents a workout activity that users must complete to earn unlock time.
/// Immutable domain model with earned time configuration.
class Workout {
  final String id;
  final String type; // 'walking', 'running', 'jumping_jacks'
  final int targetReps; // Required repetitions to complete workout
  final int earnedTimeSeconds; // Unlock duration earned upon completion
  final Map<String, dynamic>? metadata; // Optional additional data

  Workout({
    required this.id,
    required this.type,
    required this.targetReps,
    required this.earnedTimeSeconds,
    this.metadata,
  })  : assert(targetReps > 0, 'targetReps must be positive'),
        assert(earnedTimeSeconds > 0, 'earnedTimeSeconds must be positive'),
        assert(type.isNotEmpty, 'type cannot be empty');

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      type: json['type'] as String,
      targetReps: json['targetReps'] as int,
      earnedTimeSeconds: json['earnedTimeSeconds'] as int,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'targetReps': targetReps,
      'earnedTimeSeconds': earnedTimeSeconds,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  String toString() =>
      'Workout(id: $id, type: $type, targetReps: $targetReps, earnedTimeSeconds: $earnedTimeSeconds)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Workout && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
