import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/presence/personality_profile.dart';
import 'package:yopet/features/presence/companion_behavior.dart';

void main() {
  test('four idle routines differ in speed, pause, fins and range', () {
    final behaviors = PersonalityProfile.presets
        .map((p) => CompanionBehavior(p.legacyCodes))
        .toList();
    expect(behaviors.map((b) => b.speed).toSet().length, 4);
    expect(behaviors.map((b) => b.routineRestSeconds).toSet().length, 4);
    expect(behaviors.map((b) => b.finTempo).toSet().length, 4);
    expect(behaviors[3].finPower, lessThan(behaviors[1].finPower));
    expect(behaviors[1].steering, lessThan(behaviors[0].steering));
    const destination = Alignment(.7, .6);
    final routes = behaviors
        .map((b) => b.routeDestination(destination, Alignment.center))
        .toList();
    expect(routes.map((p) => p.x).toSet().length, 4);
    expect(routes[3].x.abs(), lessThan(routes[1].x.abs()));
    expect(
      behaviors[3].routeSeconds,
      greaterThan(behaviors[3].routineRestSeconds),
    );
  });
  test('only cautious explorers take a bounded side approach', () {
    final cautious = CompanionBehavior(['shy', 'curious']);
    const start = Alignment(-.5, 0);
    const end = Alignment(.5, 0);
    final upper = cautious.approachWaypoint(start, end, 0)!;
    final lower = cautious.approachWaypoint(start, end, 1)!;
    expect(upper.y, greaterThan(0));
    expect(lower.y, lessThan(0));
    expect(upper.x, closeTo(0, .001));
    expect(cautious.approachWaypoint(start, start, 0), isNull);
    expect(
      CompanionBehavior(['bold', 'curious']).approachWaypoint(start, end, 0),
      isNull,
    );
  });
  test('four profiles have separate dimensions and compatible storage', () {
    expect(PersonalityProfile.presets.map((p) => p.name).toSet().length, 4);
    for (final profile in PersonalityProfile.presets) {
      expect(
        profile.legacyCodes.contains('bold') &&
            profile.legacyCodes.contains('shy'),
        isFalse,
      );
      expect(PersonalityProfile.fromLegacy(profile.legacyCodes), profile);
    }
    expect(PersonalityProfile.fromLegacy({'bold', 'shy'}), isNull);
  });
  test('activity is independent of slow-warm social style', () {
    final eager = CompanionBehavior(['bold', 'curious']);
    final cautious = CompanionBehavior(['shy', 'curious']);
    final gentle = CompanionBehavior(['bold', 'lazy']);
    final quiet = CompanionBehavior(['shy', 'lazy']);
    expect(cautious.speed, greaterThan(gentle.speed));
    expect(cautious.speed, lessThan(eager.speed));
    expect(cautious.attentionDelay, greaterThan(eager.attentionDelay));
    expect(gentle.followsPointer, isTrue);
    expect(quiet.followsPointer, isFalse);
    expect(
      quiet.approach(const Alignment(.5, .3), const Alignment(-.5, -.3), 0).x,
      greaterThan(.5),
    );
    const route = Alignment(.6, .6);
    expect(eager.routeDestination(route, Alignment.center), route);
    expect(gentle.routeDestination(route, Alignment.center).x, lessThan(.3));
  });
}
