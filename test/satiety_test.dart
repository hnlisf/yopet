import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/feeding/satiety.dart';

void main() {
  test('feeding raises satiety but never exceeds 100', () {
    expect(satietyAfterFeeding(60), 85);
    expect(satietyAfterFeeding(90), 100);
  });

  test('five hours without feeding can enter the low-satiety mood', () {
    final satiety = satietyAfterElapsed(35, const Duration(hours: 5));
    expect(satiety, 25);
    expect(isLowSatiety(satiety), isTrue);
  });

  test('partial intervals are retained until a full thirty minutes pass', () {
    expect(decayIntervalsFor(const Duration(minutes: 29)), 0);
    expect(decayIntervalsFor(const Duration(minutes: 30)), 1);
    expect(satietyAfterElapsed(1, const Duration(days: 365)), 0);
  });
}
