import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/presence/companion_behavior.dart';

void main() {
  test('greetings stagger and stay near each fish instead of converging', () {
    final bold = CompanionBehavior(['bold']);
    final shy = CompanionBehavior(['shy']);
    final lazy = CompanionBehavior(['lazy']);
    const current = Alignment(.5, .3);
    expect(bold.greetingDelay(1), greaterThan(bold.greetingDelay(0)));
    expect(lazy.greetingDelay(0), greaterThan(bold.greetingDelay(0)));
    expect(
      (lazy.greetingDestination(current, 0).x - current.x).abs(),
      lessThan((shy.greetingDestination(current, 0).x - current.x).abs()),
    );
    expect(bold.greetingDestination(current, 0).x, greaterThan(current.x));
    expect(bold.greetingDestination(current, 1).x, lessThan(current.x));
    expect(
      bold.greetingDestination(const Alignment(.77, -.71), 0).x,
      lessThanOrEqualTo(.78),
    );
  });
  test('feeding staggers personalities and allocates separate portions', () {
    final bold = CompanionBehavior(['bold']);
    final lazy = CompanionBehavior(['lazy']);
    final shy = CompanionBehavior(['shy']);
    expect(bold.feedingDelay(0), lessThan(lazy.feedingDelay(0)));
    expect(bold.feedingDelay(1), greaterThan(bold.feedingDelay(0)));
    expect(List.generate(5, bold.feedingDestination).toSet().length, 5);
    expect(
      shy.feedingDestination(0).y,
      greaterThan(bold.feedingDestination(0).y),
    );
  });
  test(
    'social mixed personalities can follow while non-social fish do not',
    () {
      expect(CompanionBehavior(['curious']).followsPointer, isTrue);
      expect(CompanionBehavior(['bold']).followsPointer, isTrue);
      expect(CompanionBehavior(['curious', 'shy']).followsPointer, isTrue);
      expect(CompanionBehavior(['bold', 'lazy']).followsPointer, isTrue);
      expect(CompanionBehavior(['shy', 'lazy']).followsPointer, isFalse);
    },
  );
  test(
    'follow turns rotate instead of the nearest fish monopolising input',
    () {
      final selector = CompanionFollowSelector();
      final start = DateTime(2026);
      expect(selector.select(['wowo', 'other'], start), 'wowo');
      expect(
        selector.select([
          'wowo',
          'other',
        ], start.add(const Duration(seconds: 2))),
        'wowo',
      );
      expect(
        selector.select([
          'wowo',
          'other',
        ], start.add(const Duration(seconds: 4))),
        'other',
      );
      expect(
        selector.select([
          'other',
          'wowo',
        ], start.add(const Duration(seconds: 8))),
        'wowo',
      );
      expect(
        selector.select([], start.add(const Duration(seconds: 9))),
        isNull,
      );
    },
  );
  test('low satiety preserves personality differences and call energy', () {
    final bold = CompanionBehavior(['bold']);
    final lazy = CompanionBehavior(['lazy']);
    expect(
      bold.speedFor(lowSatiety: true),
      greaterThan(lazy.speedFor(lowSatiety: true)),
    );
    expect(
      lazy.speedFor(lowSatiety: true, responding: true),
      greaterThan(lazy.speedFor(lowSatiety: true)),
    );
  });
  test('personalities have distinct speed, pauses and attention timing', () {
    final bold = CompanionBehavior(['bold']);
    final curious = CompanionBehavior(['curious']);
    final shy = CompanionBehavior(['shy']);
    final lazy = CompanionBehavior(['lazy']);
    expect(bold.speed, greaterThan(curious.speed));
    expect(lazy.speed, lessThan(shy.speed));
    expect(lazy.rest, greaterThan(curious.rest));
    expect(shy.attentionDelay, greaterThan(bold.attentionDelay));
  });
  test(
    'shy curious fish investigate with more space, lazy approach partially',
    () {
      const current = Alignment(-.7, .2);
      const call = Alignment(.3, .2);
      final bold = CompanionBehavior(['bold']).approach(current, call, 0);
      final shy = CompanionBehavior([
        'shy',
        'curious',
      ]).approach(current, call, 0);
      final lazy = CompanionBehavior(['lazy']).approach(current, call, 0);
      expect(shy.x, lessThan(bold.x));
      expect(shy.x, greaterThan(current.x));
      expect(lazy.x, lessThan(bold.x));
      expect(
        CompanionBehavior(['bold']).approach(current, call, 1),
        isNot(bold),
      );
    },
  );
}
