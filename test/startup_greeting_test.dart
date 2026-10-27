import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/presence/presence_interaction.dart';

void main() {
  test('startup waits for residents and greets once after a long absence', () {
    final gate = StartupGreetingGate();
    final now = DateTime(2026, 10, 10, 12);
    expect(gate.check([], now), isFalse);
    final old = now.subtract(const Duration(minutes: 11));
    expect(gate.check([old], now), isTrue);
    expect(gate.check([old], now), isFalse);
  });
  test(
    'recent presence or future timestamp never triggers startup greeting',
    () {
      final now = DateTime(2026, 10, 10, 12);
      expect(
        StartupGreetingGate().check([
          now.subtract(const Duration(days: 1)),
          now.subtract(const Duration(minutes: 2)),
        ], now),
        isFalse,
      );
      expect(
        StartupGreetingGate().check([now.add(const Duration(minutes: 1))], now),
        isFalse,
      );
    },
  );
}
