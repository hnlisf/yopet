import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'idle_routine.dart';
import 'personality_profile.dart';

IdleRoutine desktopRoutine(
  PersonalityProfile profile,
  int step,
  Alignment current,
  Size size,
  double speed,
) {
  // Visit all nine screen zones over time, in an interleaved order.
  const zones = [0, 8, 2, 6, 4, 1, 7, 3, 5];
  final quiet = profile == PersonalityProfile.presets[3];
  final cautious = profile == PersonalityProfile.presets[2];
  final cycle = quiet
      ? 4
      : cautious
      ? 2
      : 1;
  if (step % cycle != 0) {
    return IdleRoutine(
      quiet ? IdlePhase.hover : IdlePhase.observe,
      current,
      quiet ? 8 : 4,
      quiet ? 8 : 4,
    );
  }
  final zone = zones[(step ~/ cycle) % zones.length];
  final edgeX = (1 - 140 / math.max(size.width, 200)).clamp(0.0, .98);
  final edgeY = (1 - 140 / math.max(size.height, 200)).clamp(0.0, .98);
  final target = Alignment((zone % 3 - 1) * edgeX, (zone ~/ 3 - 1) * edgeY);
  final distance = Offset(
    (target.x - current.x) * size.width / 2,
    (target.y - current.y) * size.height / 2,
  ).distance;
  final seconds = (distance / math.max(speed, 5) * 1.5 + 5).ceil();
  return IdleRoutine(
    profile == PersonalityProfile.presets[1]
        ? IdlePhase.glide
        : quiet
        ? IdlePhase.excursion
        : cautious
        ? IdlePhase.explore
        : IdlePhase.patrol,
    target,
    seconds,
    quiet ? 1 : .3,
  );
}
