import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/weather/weather_models.dart';

void main() {
  test('thunderstorm codes are ordinary rain, with no storm option', () {
    for (final code in [95, 96, 99]) {
      final condition = WeatherCondition.fromWmoCode(code);
      expect(condition, WeatherCondition.rain);
      expect(condition.labelZh(isDay: true), '雨天');
    }
    expect(
      WeatherCondition.values.map((c) => c.name),
      isNot(contains('storm')),
    );
  });
}
