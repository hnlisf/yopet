/// Hand-rolled `Tank` model. F4 stays YAGNI — no freezed /
/// json_serializable yet (F5 introduces that codegen toolchain).
/// F4 ships the bare-minimum data class so the home screen can
/// render what `tankStreamProvider` emits.
class Tank {
  Tank({
    required this.id,
    required this.ownerId,
    required this.decorationSettings,
    required this.createdAt,
  });

  factory Tank.fromMap(Map<String, dynamic> map) {
    return Tank(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      decorationSettings:
          (map['decoration_settings'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  final String id;
  final String ownerId;
  final Map<String, dynamic> decorationSettings;
  final DateTime createdAt;
}
