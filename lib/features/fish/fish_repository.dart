import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'fish_models.dart';

class TankFullException implements Exception {
  const TankFullException();
}

abstract class FishRepository {
  Future<FishCatalog> fetchCatalog();

  Stream<List<FishInstance>> watchFish(String tankId);

  /// Applies elapsed, non-punitive satiety decay when the tank opens.
  Future<void> syncTankSatiety(String tankId);

  /// Advances time-led growth stages when the tank opens.
  Future<void> syncTankGrowth(String tankId);

  /// Stores the last moment the player left the tank.
  ///
  /// This is current-state presence only. It deliberately does not create a
  /// history row or an interaction event.
  Future<void> updateLastSeen({
    required Iterable<String> fishIds,
    required DateTime at,
  });

  /// Adds one standard meal and returns the server's capped fish state.
  Future<FishInstance> feedFish(String fishId);

  /// Feeds every resident together in one owner-checked server transaction.
  /// Each fish keeps an individual log row, but the player never has to
  /// repeat the action one fish at a time.
  Future<List<FishInstance>> feedTank(String tankId);

  Future<FishInstance> adoptFish({
    required String tankId,
    required FishSpecies species,
    required FishVariant variant,
    required String name,
    required List<PersonalityTrait> availableTraits,
  });

  Future<FishInstance> adoptCustomFish({
    required String tankId,
    required String name,
    required CustomFishAppearance appearance,
    required List<PersonalityTrait> availableTraits,
  });

  /// Permanently removes one owned fish from its tank.
  ///
  /// The UI always places this behind an explicit, named confirmation. The
  /// database owner policy remains the final authority for the delete.
  Future<void> releaseFish(String fishId);
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
            'id, common_name_zh, common_name_en, growth_days_to_juvenile, '
            'growth_days_to_adult, preferred_temp_min, preferred_temp_max, '
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
  Future<void> syncTankSatiety(String tankId) {
    return _client.rpc('sync_tank_satiety', params: {'target_tank_id': tankId});
  }

  @override
  Future<void> syncTankGrowth(String tankId) {
    return _client.rpc('sync_tank_growth', params: {'target_tank_id': tankId});
  }

  @override
  Future<void> updateLastSeen({
    required Iterable<String> fishIds,
    required DateTime at,
  }) async {
    final ids = fishIds.toSet().toList(growable: false);
    if (ids.isEmpty) return;
    await _client
        .from('fish')
        .update({'last_seen_at': at.toUtc().toIso8601String()})
        .inFilter('id', ids);
  }

  @override
  Future<FishInstance> feedFish(String fishId) async {
    final row = await _client.rpc(
      'feed_fish',
      params: {'target_fish_id': fishId},
    );
    return FishInstance.fromMap((row as Map).cast<String, dynamic>());
  }

  @override
  Future<List<FishInstance>> feedTank(String tankId) async {
    final rows = await _client.rpc(
      'feed_tank',
      params: {'target_tank_id': tankId},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(FishInstance.fromMap)
        .toList(growable: false);
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

  @override
  Future<FishInstance> adoptCustomFish({
    required String tankId,
    required String name,
    required CustomFishAppearance appearance,
    required List<PersonalityTrait> availableTraits,
  }) async {
    final normalizedName = name.trim();
    try {
      final row = await _client
          .from('fish')
          .insert({
            'tank_id': tankId,
            'species_id': null,
            'variant_id': null,
            'name': normalizedName,
            'traits': selectRandomTraitIds(availableTraits, _random),
            ...appearance.toInsertMap(),
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

  @override
  Future<void> releaseFish(String fishId) async {
    await _client.from('fish').delete().eq('id', fishId);
  }
}
