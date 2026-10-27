import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/weather/weather_models.dart';
import 'package:yopet/features/weather/weather_repository.dart';

void main() {
  test('WMO codes map to calm, recognizable aquarium conditions', () {
    expect(WeatherCondition.fromWmoCode(0), WeatherCondition.clear);
    expect(WeatherCondition.fromWmoCode(2), WeatherCondition.partlyCloudy);
    expect(WeatherCondition.fromWmoCode(45), WeatherCondition.fog);
    expect(WeatherCondition.fromWmoCode(63), WeatherCondition.rain);
    expect(WeatherCondition.fromWmoCode(73), WeatherCondition.snow);
    expect(WeatherCondition.fromWmoCode(95), WeatherCondition.rain);
    expect(WeatherCondition.clear.labelZh(isDay: false), '晴夜');
  });

  test('every weather activity adjustment remains a non-punitive mood cue', () {
    for (final condition in WeatherCondition.values) {
      expect(condition.activityMultiplier, greaterThanOrEqualTo(0.7));
      expect(condition.activityMultiplier, lessThanOrEqualTo(1.2));
    }
  });

  test(
    'Open-Meteo city and current-weather responses become a saved snapshot',
    () {
      const cityPayload = '''
      {"results":[{"name":"上海","latitude":31.2304,"longitude":121.4737,"country":"中国","admin1":"上海市"}]}
    ''';
      final cities = weatherCitiesFromResponse(cityPayload);
      expect(cities, hasLength(1));
      expect(cities.single.name, '上海');
      expect(cities.single.subtitle, '上海市 · 中国');

      const forecastPayload = '''
      {"current":{"time":"2026-09-06T09:00","temperature_2m":24.5,"weather_code":63,"is_day":1}}
    ''';
      final snapshot = weatherSnapshotFromResponse(
        city: cities.single,
        body: forecastPayload,
      );
      expect(snapshot.cityName, '上海');
      expect(snapshot.condition, WeatherCondition.rain);
      expect(snapshot.temperatureLabel, '25°');
      expect(snapshot.toTankUpdate()['weather_is_day'], isTrue);
      expect(snapshot.toTankUpdate()['weather_code'], 63);
    },
  );
}
