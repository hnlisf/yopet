import 'package:flutter/material.dart';

enum GrowthStage {
  fry,
  juvenile,
  adult;

  static GrowthStage fromJson(String value) => GrowthStage.values.firstWhere(
    (stage) => stage.name == value,
    orElse: () => GrowthStage.fry,
  );

  String get nameZh => switch (this) {
    GrowthStage.fry => '鱼苗',
    GrowthStage.juvenile => '幼鱼',
    GrowthStage.adult => '成鱼',
  };
}

class PersonalityTrait {
  const PersonalityTrait({
    required this.id,
    required this.code,
    required this.nameZh,
    required this.behaviorHint,
  });

  factory PersonalityTrait.fromMap(Map<String, dynamic> map) {
    return PersonalityTrait(
      id: map['id'] as String,
      code: map['code'] as String,
      nameZh: map['name_zh'] as String,
      behaviorHint:
          (map['behavior_hint'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }

  final String id;
  final String code;
  final String nameZh;
  final Map<String, dynamic> behaviorHint;
}

class FishVariant {
  const FishVariant({
    required this.id,
    required this.speciesId,
    required this.label,
    required this.colorHex,
    required this.assetFilename,
  });

  factory FishVariant.fromMap(Map<String, dynamic> map) {
    return FishVariant(
      id: map['id'] as String,
      speciesId: map['species_id'] as String,
      label: map['variant_label'] as String,
      colorHex: map['color_hex'] as String,
      assetFilename: map['asset_filename'] as String,
    );
  }

  final String id;
  final String speciesId;
  final String label;
  final String colorHex;
  final String assetFilename;

  Color get color {
    final value = int.tryParse(colorHex.substring(1), radix: 16) ?? 0x5BA8B5;
    return Color(0xFF000000 | value);
  }
}

class FishSpecies {
  const FishSpecies({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.variants,
    this.growthDaysToJuvenile = 7,
    this.growthDaysToAdult = 21,
  });

  factory FishSpecies.fromMap(Map<String, dynamic> map) {
    final variantRows = (map['fish_variants'] as List? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final variants = variantRows.map(FishVariant.fromMap).toList()
      ..sort((left, right) => left.label.compareTo(right.label));
    return FishSpecies(
      id: map['id'] as String,
      nameZh: map['common_name_zh'] as String,
      nameEn: map['common_name_en'] as String,
      variants: variants,
      growthDaysToJuvenile: map['growth_days_to_juvenile'] as int? ?? 7,
      growthDaysToAdult: map['growth_days_to_adult'] as int? ?? 21,
    );
  }

  final String id;
  final String nameZh;
  final String nameEn;
  final List<FishVariant> variants;
  final int growthDaysToJuvenile;
  final int growthDaysToAdult;

  String get assetPath => 'assets/fish/$id/base.png';

  String assetPathForStage(GrowthStage stage) =>
      'assets/fish/$id/${stage.name}.png';
}

class FishCatalog {
  const FishCatalog({required this.species, required this.traits});

  final List<FishSpecies> species;
  final List<PersonalityTrait> traits;
}

class FishInstance {
  const FishInstance({
    required this.id,
    required this.tankId,
    required this.speciesId,
    required this.variantId,
    required this.name,
    required this.traitIds,
    required this.growthStage,
    required this.satiety,
    required this.createdAt,
    required this.lastSeenAt,
  });

  factory FishInstance.fromMap(Map<String, dynamic> map) {
    return FishInstance(
      id: map['id'] as String,
      tankId: map['tank_id'] as String,
      speciesId: map['species_id'] as String,
      variantId: map['variant_id'] as String,
      name: map['name'] as String,
      traitIds: (map['traits'] as List).cast<String>(),
      growthStage: GrowthStage.fromJson(map['growth_stage'] as String),
      satiety: map['satiety'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastSeenAt: DateTime.parse(map['last_seen_at'] as String),
    );
  }

  final String id;
  final String tankId;
  final String speciesId;
  final String variantId;
  final String name;
  final List<String> traitIds;
  final GrowthStage growthStage;
  final int satiety;
  final DateTime createdAt;
  final DateTime lastSeenAt;
}
