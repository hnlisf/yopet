import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'personality_profile.dart';

enum IdlePhase { patrol, glide, explore, observe, hover, excursion }

class IdleRoutine {
  const IdleRoutine(this.phase, this.target, this.seconds, this.pause);
  final IdlePhase phase;
  final Alignment target;
  final int seconds;
  final double pause;
  bool get stationary => phase == IdlePhase.observe || phase == IdlePhase.hover;

  double speedEnvelope(double elapsed) {
    if (stationary) return 0;
    if (phase != IdlePhase.glide) return 1;
    return .35 + .65 * math.sin(math.pi * (elapsed / seconds).clamp(0, 1));
  }

  static IdleRoutine plan(
    PersonalityProfile profile,
    int step,
    Alignment current,
    Alignment home,
  ) {
    Alignment bounded(double x, double y) =>
        Alignment(x.clamp(-.72, .72), y.clamp(-.65, .62));
    if (profile == PersonalityProfile.presets[0]) {
      return IdleRoutine(
        IdlePhase.patrol,
        bounded(step.isEven ? -.68 : .68, -.22 + (step % 3) * .18),
        16,
        .2,
      );
    }
    if (profile == PersonalityProfile.presets[1]) {
      return IdleRoutine(
        IdlePhase.glide,
        bounded(
          home.x + (step.isEven ? -.40 : .40),
          home.y + (step.isEven ? -.20 : .20),
        ),
        20,
        1,
      );
    }
    if (profile == PersonalityProfile.presets[2]) {
      if (step.isOdd) return IdleRoutine(IdlePhase.observe, current, 4, 4);
      final angle = (step ~/ 2 % 6) * math.pi / 3;
      return IdleRoutine(
        IdlePhase.explore,
        bounded(
          current.x + math.cos(angle) * .28,
          current.y + math.sin(angle) * .23,
        ),
        7,
        .3,
      );
    }
    if (step % 4 != 3) {
      return IdleRoutine(IdlePhase.hover, current, 8, 8);
    }
    return IdleRoutine(
      IdlePhase.excursion,
      bounded(home.x + (step % 8 == 3 ? .12 : -.12), home.y + .08),
      7,
      .5,
    );
  }
}
