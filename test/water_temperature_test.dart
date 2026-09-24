import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/temperature/water_temperature.dart';

void main() {
  test(
    'supported tank water temperature stays within the intentional range',
    () {
      expect(isSupportedWaterTemperature(18), isTrue);
      expect(isSupportedWaterTemperature(24), isTrue);
      expect(isSupportedWaterTemperature(30), isTrue);
      expect(isSupportedWaterTemperature(17), isFalse);
      expect(isSupportedWaterTemperature(31), isFalse);
    },
  );

  test('temperature comfort is calm and recognises preferred range edges', () {
    expect(
      comfortForWaterTemperature(
        temperature: 24,
        preferredMin: 22,
        preferredMax: 26,
      ),
      WaterTemperatureComfort.comfortable,
    );
    expect(
      comfortForWaterTemperature(
        temperature: 20,
        preferredMin: 22,
        preferredMax: 26,
      ),
      WaterTemperatureComfort.slightlyCool,
    );
    expect(
      comfortForWaterTemperature(
        temperature: 18,
        preferredMin: 22,
        preferredMax: 26,
      ),
      WaterTemperatureComfort.cool,
    );
    expect(
      comfortForWaterTemperature(
        temperature: 28,
        preferredMin: 22,
        preferredMax: 26,
      ),
      WaterTemperatureComfort.slightlyWarm,
    );
  });

  test('all temperature motion cues are deliberately gentle', () {
    for (final comfort in WaterTemperatureComfort.values) {
      expect(comfort.activityMultiplier, inInclusiveRange(0.8, 1.05));
    }
  });
}
