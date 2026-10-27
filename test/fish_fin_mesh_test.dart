import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/fish/fish_fin_mesh.dart';

void main() {
  const body = Rect.fromLTRB(.2, .3, .6, .7);
  test('tail sweeps horizontally and alternates between open and folded', () {
    const upper = Offset(.9, .25);
    const lower = Offset(.9, .75);
    final open = fishFinOffset(upper, body, -1.57079632679, 1);
    final folded = fishFinOffset(upper, body, 1.57079632679, 1);
    expect((open.dx - folded.dx).abs(), greaterThan(.03));
    final foldedLower = fishFinOffset(lower, body, 1.57079632679, 1);
    expect(folded.dy, greaterThan(0));
    expect(foldedLower.dy, lessThan(0));
  });
  test('torso and tail root stay fixed throughout the fin cycle', () {
    for (var i = 0; i < 60; i++) {
      for (final p in [
        const Offset(.4, .5),
        const Offset(.6, .5),
        const Offset(.3, .4),
      ]) {
        expect(fishFinOffset(p, body, i * .1, 1), Offset.zero);
      }
    }
  });
  test('fin tips move with phase and swimming strength', () {
    const tip = Offset(.9, .5);
    expect(
      fishFinOffset(tip, body, 0, 1),
      isNot(fishFinOffset(tip, body, 2, 1)),
    );
    expect(
      fishFinOffset(tip, body, 1, .3).distance,
      lessThan(fishFinOffset(tip, body, 1, 1).distance),
    );
    expect(fishFinOffset(tip, body, 1, 0), Offset.zero);
    expect(
      fishFinOffset(const Offset(.4, .1), body, 1, 1).distance,
      greaterThan(0),
    );
    expect(
      fishFinOffset(const Offset(.4, .9), body, 1, 1).distance,
      greaterThan(0),
    );
  });
}
