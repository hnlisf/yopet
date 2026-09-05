import '../../data/decorations.dart';

class TankDecoration {
  const TankDecoration({
    required this.id,
    required this.tankId,
    required this.code,
    required this.type,
    required this.positionX,
    required this.positionY,
    required this.placedAt,
  });

  factory TankDecoration.fromMap(Map<String, dynamic> map) {
    return TankDecoration(
      id: map['id'] as String,
      tankId: map['tank_id'] as String,
      code: map['decoration_code'] as String,
      type: DecorationType.values.firstWhere(
        (type) => type.name == map['decoration_type'],
      ),
      positionX: (map['position_x'] as num).toDouble(),
      positionY: (map['position_y'] as num).toDouble(),
      placedAt: DateTime.parse(map['placed_at'] as String),
    );
  }

  final String id;
  final String tankId;
  final String code;
  final DecorationType type;
  final double positionX;
  final double positionY;
  final DateTime placedAt;
}
