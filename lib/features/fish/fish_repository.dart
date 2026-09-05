import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'fish_models.dart';

class TankFullException implements Exception {
  const TankFullException();
}

abstract class FishRepository {
  Future<FishCatalog> fetchCatalog();

  Stream<List<FishInstance>> watchFish(String tankId);

  Future<FishInstance> adoptFish({
    required String tankId,
    required FishSpecies species,
    required FishVariant variant,
    required String name,
    required List<PersonalityTrait> availableTraits,
  });
}

List<String> selectRandomTraitIds(
  List<PersonalityTrait> traits,
  Random random,
) {
  if (traits.isEmpty) {
    throw StateError('At least one personality trait is required');
  }
  final shuffled = List<PersonalityTrait>.of(traits)..shuffle(random);
  final count = 1 + random.nextInt(min(3, shuffled.length));
  return shuffled.take(count).map((trait) => trait.id).toList(growable: false);
}

class SupabaseFishRepository implements FishRepository {
  SupabaseFishRepository(this._client, {Random? random})
    : _random = random ?? Random.secure();

  final SupabaseClient _client;
  final Random _random;

  @override
  Future<FishCatalog> fetchCatalog() async {
    final results = await Future.wait([
      _client
          .from('fish_species')
          .select(
            'id, common_name_zh, common_name_en, '
            'fish_variants(id, species_id, variant_label, color_hex, asset_filename)',
          )
          .order('common_name_zh'),
      _client
          .from('personality_traits')
          .select('id, code, name_zh, behavior_hint')
          .order('code'),
    ]);

    final species = (results[0] as List)
        .cast<Map<String, dynamic>>()
        .map(FishSpecies.fromMap)
        .where((item) => item.variants.isNotEmpty)
        .toList(growable: false);
    final traits = (results[1] as List)
        .cast<Map<String, dynamic>>()
        .map(PersonalityTrait.fromMap)
        .toList(growable: false);
    return FishCatalog(species: species, traits: traits);
  }

  @override
  Stream<List<FishInstance>> watchFish(String tankId) {
    return _client
        .from('fish')
        .stream(primaryKey: ['id'])
        .eq('tank_id', tankId)
        .order('created_at')
        .map((rows) => rows.map(FishInstance.fromMap).toList(growable: false));
  }

  @override
  Future<FishInstance> adoptFish({
    required String tankId,
    required FishSpecies species,
    required FishVariant variant,
    required String name,
    required List<PersonalityTrait> availableTraits,
  }) async {
    final normalizedName = name.trim();
    try {
      final row = await _client
          .from('fish')
          .insert({
            'tank_id': tankId,
            'species_id': species.id,
            'variant_id': variant.id,
            'name': normalizedName,
            'traits': selectRandomTraitIds(availableTraits, _random),
          })
          .select()
          .single();
      return FishInstance.fromMap(row);
    } on PostgrestException catch (error) {
      if (error.message.contains('tank_capacity_exceeded')) {
        throw const TankFullException();
      }
      rethrow;
    }
  }
}
