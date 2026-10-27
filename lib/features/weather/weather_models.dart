import 'package:flutter/material.dart';

/// The deliberately small set of aquarium moods derived from the WMO weather
/// codes returned by Open-Meteo. They are presentation-only: no case is a
/// warning, failure, or a health state for a fish.
enum WeatherCondition {
  clear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  rain,
  snow;

  static WeatherCondition fromWmoCode(int code) => switch (code) {
    0 => WeatherCondition.clear,
    1 || 2 => WeatherCondition.partlyCloudy,
    3 => WeatherCondition.overcast,
    45 || 48 => WeatherCondition.fog,
    51 || 53 || 55 || 56 || 57 => WeatherCondition.drizzle,
    61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => WeatherCondition.rain,
    71 || 73 || 75 || 77 || 85 || 86 => WeatherCondition.snow,
    95 || 96 || 99 => WeatherCondition.rain,
    _ => WeatherCondition.partlyCloudy,
  };

  String labelZh({required bool isDay}) => switch (this) {
    WeatherCondition.clear => isDay ? '晴朗' : '晴夜',
    WeatherCondition.partlyCloudy => '少云',
    WeatherCondition.overcast => '多云',
    WeatherCondition.fog => '薄雾',
    WeatherCondition.drizzle => '细雨',
    WeatherCondition.rain => '雨天',
    WeatherCondition.snow => '雪天',
  };

  IconData get icon => switch (this) {
    WeatherCondition.clear => Icons.wb_sunny_outlined,
    WeatherCondition.partlyCloudy => Icons.wb_cloudy_outlined,
    WeatherCondition.overcast => Icons.cloud_outlined,
    WeatherCondition.fog => Icons.foggy,
    WeatherCondition.drizzle ||
    WeatherCondition.rain => Icons.water_drop_outlined,
    WeatherCondition.snow => Icons.ac_unit_rounded,
  };

  /// Relative activity, not a welfare score. A value below one only makes the
  /// next free-swim destination arrive more slowly.
  double get activityMultiplier => switch (this) {
    WeatherCondition.clear => 1.14,
    WeatherCondition.partlyCloudy => 1.04,
    WeatherCondition.overcast => 0.92,
    WeatherCondition.fog => 0.76,
    WeatherCondition.drizzle => 0.86,
    WeatherCondition.rain => 0.80,
    WeatherCondition.snow => 0.72,
  };
}

class WeatherCity {
  const WeatherCity({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.country,
    this.admin1,
  });

  factory WeatherCity.fromOpenMeteo(Map<String, dynamic> map) {
    return WeatherCity(
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      country: map['country'] as String? ?? '',
      admin1: map['admin1'] as String?,
    );
  }

  final String name;
  final double latitude;
  final double longitude;
  final String country;
  final String? admin1;

  String get subtitle => [
    admin1,
    country,
  ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
}

class WeatherSnapshot {
  const WeatherSnapshot({
    required this.cityName,
    required this.latitude,
    required this.longitude,
    required this.wmoCode,
    required this.temperatureCelsius,
    required this.isDay,
    required this.observedAt,
  });

  factory WeatherSnapshot.fromTankMap(Map<String, dynamic> map) {
    return WeatherSnapshot(
      cityName: map['weather_city_name'] as String,
      latitude: (map['weather_latitude'] as num).toDouble(),
      longitude: (map['weather_longitude'] as num).toDouble(),
      wmoCode: map['weather_code'] as int,
      temperatureCelsius: (map['weather_temperature_c'] as num).toDouble(),
      isDay: map['weather_is_day'] as bool,
      observedAt: DateTime.parse(map['weather_observed_at'] as String),
    );
  }

  factory WeatherSnapshot.fromOpenMeteo({
    required WeatherCity city,
    required Map<String, dynamic> payload,
  }) {
    final current = (payload['current'] as Map).cast<String, dynamic>();
    return WeatherSnapshot(
      cityName: city.name,
      latitude: city.latitude,
      longitude: city.longitude,
      wmoCode: (current['weather_code'] as num).toInt(),
      temperatureCelsius: (current['temperature_2m'] as num).toDouble(),
      isDay: current['is_day'] == 1 || current['is_day'] == true,
      observedAt: DateTime.parse(current['time'] as String),
    );
  }

  factory WeatherSnapshot.preview(WeatherCondition condition) {
    final code = switch (condition) {
      WeatherCondition.clear => 0,
      WeatherCondition.partlyCloudy => 2,
      WeatherCondition.overcast => 3,
      WeatherCondition.fog => 45,
      WeatherCondition.drizzle => 51,
      WeatherCondition.rain => 63,
      WeatherCondition.snow => 73,
    };
    return WeatherSnapshot(
      cityName: '效果预览',
      latitude: 0,
      longitude: 0,
      wmoCode: code,
      temperatureCelsius: 24,
      isDay: true,
      observedAt: DateTime.now(),
    );
  }

  final String cityName;
  final double latitude;
  final double longitude;
  final int wmoCode;
  final double temperatureCelsius;
  final bool isDay;
  final DateTime observedAt;

  WeatherCondition get condition => WeatherCondition.fromWmoCode(wmoCode);

  String get labelZh => condition.labelZh(isDay: isDay);

  String get temperatureLabel => '${temperatureCelsius.round()}°';

  Map<String, dynamic> toTankUpdate() => {
    'weather_city_name': cityName,
    'weather_latitude': latitude,
    'weather_longitude': longitude,
    'weather_code': wmoCode,
    'weather_temperature_c': temperatureCelsius,
    'weather_is_day': isDay,
    'weather_observed_at': observedAt.toUtc().toIso8601String(),
  };
}
