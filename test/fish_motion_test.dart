import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/home/fish_motion.dart';

void main() {
  test('five fish disperse from a shared target without leaving the tank', () {
    final fish = List.generate(
      5,
      (i) => FishMotion(Offset(180 + i * 10, 290 + i * 5)),
    );
    for (var tick = 0; tick < 1800; tick++) {
      final positions = fish.map((item) => item.position).toList();
      for (var i = 0; i < fish.length; i++) {
        fish[i].step(
          1 / 60,
          target: const Offset(200, 300),
          tank: const Size(400, 600),
          neighbours: [
            for (var j = 0; j < fish.length; j++)
              if (i != j) positions[j],
          ],
        );
      }
    }
    for (var i = 0; i < fish.length; i++) {
      expect(fish[i].position.dx, inInclusiveRange(0, 400));
      expect(fish[i].position.dy, inInclusiveRange(0, 600));
      for (var j = i + 1; j < fish.length; j++) {
        expect((fish[i].position - fish[j].position).distance, greaterThan(45));
      }
    }
  });
  test('nearby fish separate even when attracted to the same destination', () {
    final a = FishMotion(const Offset(190, 300));
    final b = FishMotion(const Offset(210, 300));
    for (var i = 0; i < 1200; i++) {
      final oldA = a.position;
      final oldB = b.position;
      a.step(
        1 / 60,
        target: const Offset(200, 300),
        tank: const Size(400, 600),
        neighbours: [oldB],
      );
      b.step(
        1 / 60,
        target: const Offset(200, 300),
        tank: const Size(400, 600),
        neighbours: [oldA],
      );
    }
    expect((a.position - b.position).distance, greaterThan(60));
  });
  test('turning is acceleration limited and stalls cannot teleport a fish', () {
    final fish = FishMotion(
      const Offset(200, 300),
      velocity: const Offset(24, 0),
    );
    fish.step(
      10,
      target: const Offset(0, 300),
      tank: const Size(400, 600),
      neighbours: [],
    );
    expect(fish.velocity.dx, greaterThan(0));
    expect((fish.position - const Offset(200, 300)).distance, lessThan(2));
  });
}
