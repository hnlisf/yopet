import '../weather/weather_models.dart';

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
    this.waterTemperature = 24,
    this.weather,
  });

  factory Tank.fromMap(Map<String, dynamic> map) {
    final hasWeather =
        map['weather_city_name'] != null &&
        map['weather_latitude'] != null &&
        map['weather_longitude'] != null &&
        map['weather_code'] != null &&
        map['weather_temperature_c'] != null &&
        map['weather_is_day'] != null &&
        map['weather_observed_at'] != null;
    return Tank(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      decorationSettings:
          (map['decoration_settings'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      createdAt: DateTime.parse(map['created_at'] as String),
      waterTemperature: (map['water_temperature_c'] as num?)?.round() ?? 24,
      weather: hasWeather ? WeatherSnapshot.fromTankMap(map) : null,
    );
  }

  final String id;
  final String ownerId;
  final Map<String, dynamic> decorationSettings;
  final DateTime createdAt;
  final int waterTemperature;
  final WeatherSnapshot? weather;
}
