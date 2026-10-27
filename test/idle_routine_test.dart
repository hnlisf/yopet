import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/presence/idle_routine.dart';
import 'package:yopet/features/presence/personality_profile.dart';
import 'package:yopet/features/home/fish_motion.dart';

void main() {
  test(
    'four personalities produce different sequences without interaction',
    () {
      final sequences = PersonalityProfile.presets
          .map(
            (profile) => List.generate(
              4,
              (step) => IdleRoutine.plan(
                profile,
                step,
                Alignment.center,
                Alignment.center,
              ),
            ),
          )
          .toList();
      expect(sequences[0].map((s) => s.phase).toSet(), {IdlePhase.patrol});
      expect(sequences[1].map((s) => s.phase).toSet(), {IdlePhase.glide});
      expect(sequences[2].map((s) => s.phase).toList(), [
        IdlePhase.explore,
        IdlePhase.observe,
        IdlePhase.explore,
        IdlePhase.observe,
      ]);
      expect(sequences[3].map((s) => s.phase).toList(), [
        IdlePhase.hover,
        IdlePhase.hover,
        IdlePhase.hover,
        IdlePhase.excursion,
      ]);
      final glide = sequences[1].first;
      expect(glide.speedEnvelope(0), lessThan(glide.speedEnvelope(10)));
      expect(glide.speedEnvelope(20), lessThan(glide.speedEnvelope(10)));
    },
  );
  test('real motion separates a stationary observer from a patrol', () {
    Offset simulate(PersonalityProfile profile) {
      final routine = IdleRoutine.plan(
        profile,
        0,
        Alignment.center,
        Alignment.center,
      );
      final motion = FishMotion(const Offset(400, 400));
      for (var i = 0; i < 100; i++) {
        motion.step(
          .05,
          target: routine.stationary
              ? motion.position
              : Offset(
                  (routine.target.x + 1) * 400,
                  (routine.target.y + 1) * 400,
                ),
          tank: const Size(800, 800),
          neighbours: [],
          speed: routine.stationary ? 3 : 39 * routine.speedEnvelope(i * .05),
        );
      }
      return motion.position;
    }

    expect(
      (simulate(PersonalityProfile.presets[0]) - const Offset(400, 400))
          .distance,
      greaterThan(100),
    );
    expect(
      (simulate(PersonalityProfile.presets[3]) - const Offset(400, 400))
          .distance,
      lessThan(1),
    );
  });
}
