import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/presence/desktop_routine.dart';
import 'package:yopet/features/presence/personality_profile.dart';

void main() {
  test('all four personalities eventually visit every desktop zone', () {
    for (final profile in PersonalityProfile.presets) {
      final destinations = List.generate(
        36,
        (step) => desktopRoutine(
          profile,
          step,
          Alignment.center,
          const Size(1920, 1080),
          30,
        ),
      ).where((p) => !p.stationary).map((p) => p.target).toSet();
      expect(destinations.length, 9);
      expect(destinations.any((p) => p.x > .9 && p.y > .8), isTrue);
      expect(destinations.any((p) => p.x < -.9 && p.y < -.8), isTrue);
    }
  });
  test('distant desktop routes get enough time to travel', () {
    final plan = desktopRoutine(
      PersonalityProfile.presets[0],
      0,
      const Alignment(.9, .8),
      const Size(3840, 2160),
      30,
    );
    expect(plan.seconds, greaterThan(60));
  });
}
