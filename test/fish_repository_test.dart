import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/fish/fish_models.dart';
import 'package:yopet/features/fish/fish_repository.dart';

void main() {
  group('selectRandomTraitIds', () {
    final traits = List.generate(
      4,
      (index) => PersonalityTrait(
        id: 'trait-$index',
        code: 'code-$index',
        nameZh: '性格$index',
        behaviorHint: const {},
      ),
    );

    test('returns one to three unique catalogue traits', () {
      final random = Random(42);
      final observedCounts = <int>{};

      for (var attempt = 0; attempt < 100; attempt++) {
        final ids = selectRandomTraitIds(traits, random);
        observedCounts.add(ids.length);
        expect(ids.length, inInclusiveRange(1, 3));
        expect(ids.toSet().length, ids.length);
        expect(ids.every((id) => id.startsWith('trait-')), isTrue);
      }

      expect(observedCounts, containsAll(<int>[1, 2, 3]));
    });

    test('requires a non-empty trait catalogue', () {
      expect(() => selectRandomTraitIds(const [], Random(1)), throwsStateError);
    });
  });

  test('FishInstance maps database defaults and trait UUIDs', () {
    final fish = FishInstance.fromMap({
      'id': 'fish-1',
      'tank_id': 'tank-1',
      'species_id': 'goldfish',
      'variant_id': 'goldfish_classic',
      'name': '泡泡',
      'traits': ['trait-1', 'trait-2'],
      'growth_stage': 'fry',
      'satiety': 80,
      'created_at': '2026-09-05T00:00:00Z',
      'last_seen_at': '2026-09-05T00:00:00Z',
    });

    expect(fish.growthStage, GrowthStage.fry);
    expect(fish.satiety, 80);
    expect(fish.traitIds, ['trait-1', 'trait-2']);
  });
}
