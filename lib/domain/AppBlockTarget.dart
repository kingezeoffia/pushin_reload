/// Represents content that can be blocked/allowed based on user state.
/// Immutable domain model defining blockable targets across platforms.
class AppBlockTarget {
  final String id;
  final String name; // Human-readable display name
  final String type; // 'app', 'category', 'website'
  final String platformAgnosticIdentifier; // Platform-neutral identifier

  AppBlockTarget({
    required this.id,
    required this.name,
    required this.type,
    required this.platformAgnosticIdentifier,
  })  : assert(type.isNotEmpty, 'type cannot be empty'),
        assert(platformAgnosticIdentifier.isNotEmpty,
            'platformAgnosticIdentifier cannot be empty');

  factory AppBlockTarget.fromJson(Map<String, dynamic> json) {
    return AppBlockTarget(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      platformAgnosticIdentifier: json['platformAgnosticIdentifier'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'platformAgnosticIdentifier': platformAgnosticIdentifier,
    };
  }

  @override
  String toString() => 'AppBlockTarget(id: $id, name: $name, type: $type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppBlockTarget &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
