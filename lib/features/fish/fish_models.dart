import 'package:flutter/material.dart';
import '../presence/personality_profile.dart';

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
    this.preferredTemperatureMin = 22,
    this.preferredTemperatureMax = 26,
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
      preferredTemperatureMin:
          (map['preferred_temp_min'] as num?)?.round() ?? 22,
      preferredTemperatureMax:
          (map['preferred_temp_max'] as num?)?.round() ?? 26,
    );
  }

  final String id;
  final String nameZh;
  final String nameEn;
  final List<FishVariant> variants;
  final int growthDaysToJuvenile;
  final int growthDaysToAdult;
  final int preferredTemperatureMin;
  final int preferredTemperatureMax;

  String get assetPath => 'assets/fish/$id/base.png';

  String assetPathForStage(GrowthStage stage) =>
      'assets/fish/$id/${stage.name}.png';
}

class FishCatalog {
  const FishCatalog({required this.species, required this.traits});

  final List<FishSpecies> species;
  final List<PersonalityTrait> traits;
}

/// The four visual choices that make a player-designed fish unique.
///
/// A custom fish deliberately has no catalogue species or variant.  Keeping
/// the appearance as first-class data (rather than a derived image name)
/// means it can be restored consistently on every device.
class CustomFishAppearance {
  const CustomFishAppearance({
    required this.body,
    required this.tail,
    required this.pattern,
    required this.color,
  });

  factory CustomFishAppearance.fromMap(Map<String, dynamic> map) {
    return CustomFishAppearance(
      body: map['custom_body'] as String,
      tail: map['custom_tail'] as String,
      pattern: map['custom_pattern'] as String,
      color: map['custom_color'] as String,
    );
  }

  final String body;
  final String tail;
  final String pattern;
  final String color;

  Map<String, String> toInsertMap() => {
    'custom_body': body,
    'custom_tail': tail,
    'custom_pattern': pattern,
    'custom_color': color,
  };

  String get summary =>
      '${customFishBodyForId(body).label}体型 · '
      '${customFishTailForId(tail).label} · '
      '${customFishPatternForId(pattern).label}';
}

class CustomFishBody {
  const CustomFishBody({
    required this.id,
    required this.label,
    required this.note,
    required this.jointX,
  });

  final String id;
  final String label;
  final String note;
  final double jointX;

  String get assetPath => 'assets/custom_fish/custom-body-$id.png';
}

class CustomFishTail {
  const CustomFishTail({
    required this.id,
    required this.label,
    required this.rootX,
    required this.scale,
  });

  final String id;
  final String label;
  final double rootX;
  final double scale;

  String get assetPath => 'assets/custom_fish/custom-tail-$id.png';
}

/// A complete, pre-illustrated fish silhouette for one body/tail pairing.
///
/// Each body has one three-row sheet: petal, fan, then ribbon tail.  A row is
/// a single transparent illustration, so the fish's caudal peduncle and tail
/// are painted as one continuous outline rather than composited in the UI.
@immutable
class CustomFishCompleteSprite {
  const CustomFishCompleteSprite({
    required this.assetPath,
    required this.torsoMaskAssetPath,
    required this.row,
    this.rows = 3,
  });

  final String assetPath;
  final String torsoMaskAssetPath;
  final int row;
  final int rows;
}

CustomFishCompleteSprite customFishCompleteSpriteFor({
  required CustomFishBody body,
  required CustomFishTail tail,
}) {
  // This revision is a single canvas rather than a row in a legacy sheet.
  // The caudal peduncle is painted continuously into the petal tail, so the
  // most frequently chosen round-disc pairing cannot look assembled.
  if (body.id == 'disc' && tail.id == 'petal') {
    return const CustomFishCompleteSprite(
      assetPath: 'assets/custom_fish/complete/disc-petal-v3.png',
      torsoMaskAssetPath: 'assets/custom_fish/masks/disc-petal-v3-mask.png',
      row: 0,
      rows: 1,
    );
  }
  final row = switch (tail.id) {
    'petal' => 0,
    'fan' => 1,
    'ribbon' => 2,
    _ => 0,
  };
  final assetPath = switch (body.id) {
    // The original AI sprite sheets contained an opaque checkerboard preview.
    // These background-extracted revisions retain the exact one-piece fish
    // artwork while working over every aquarium backdrop.
    'disc' => 'assets/custom_fish/complete/disc-sheet-v2.png',
    'round' => 'assets/custom_fish/complete/round-sheet-v2.png',
    _ => 'assets/custom_fish/complete/${body.id}-sheet.png',
  };
  return CustomFishCompleteSprite(
    assetPath: assetPath,
    torsoMaskAssetPath: 'assets/custom_fish/masks/${body.id}-sheet-mask.png',
    row: row,
  );
}

class CustomFishPattern {
  const CustomFishPattern({required this.id, required this.label});

  final String id;
  final String label;

  String get assetPath => 'assets/custom_fish/custom-pattern-$id.png';
}

class CustomFishColor {
  const CustomFishColor({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}

const customFishBodies = <CustomFishBody>[
  CustomFishBody(id: 'round', label: '圆润', note: '柔和椭圆', jointX: 0.685),
  CustomFishBody(id: 'light', label: '流线', note: '灯鱼式细长', jointX: 0.705),
  CustomFishBody(id: 'diamond', label: '菱形', note: '神仙鱼式高身', jointX: 0.75),
  CustomFishBody(id: 'disc', label: '圆盘', note: '七彩神仙式圆盘', jointX: 0.68),
  CustomFishBody(id: 'torpedo', label: '梭形', note: '斑马鱼式高速身形', jointX: 0.8),
  CustomFishBody(id: 'bottom', label: '底栖', note: '鼠鱼式平腹拱背', jointX: 0.72),
  CustomFishBody(id: 'box', label: '箱形', note: '箱鲀式软方轮廓', jointX: 0.72),
  CustomFishBody(id: 'eel', label: '鳗形', note: '鳗鲡式蜿蜒长身', jointX: 0.82),
];

const customFishTails = <CustomFishTail>[
  CustomFishTail(id: 'petal', label: '花瓣尾', rootX: 0.376, scale: 0.5),
  CustomFishTail(id: 'fan', label: '扇形尾', rootX: 0.303, scale: 0.46),
  CustomFishTail(id: 'ribbon', label: '飘带尾', rootX: 0.303, scale: 0.42),
];

const customFishPatterns = <CustomFishPattern>[
  CustomFishPattern(id: 'cloud', label: '云锦'),
  CustomFishPattern(id: 'pearl', label: '珍珠斑'),
  CustomFishPattern(id: 'tiger', label: '虎纹'),
  CustomFishPattern(id: 'zebra', label: '横纹'),
  CustomFishPattern(id: 'neon', label: '霓虹带'),
  CustomFishPattern(id: 'saddle', label: '鞍斑'),
  CustomFishPattern(id: 'wave', label: '波浪纹'),
  CustomFishPattern(id: 'belly', label: '双色腹'),
];

const customFishColors = <CustomFishColor>[
  CustomFishColor(id: 'orange', label: '暖橙', color: Color(0xFFF4AB66)),
  CustomFishColor(id: 'yellow', label: '月光黄', color: Color(0xFFEDCA7B)),
  CustomFishColor(id: 'red', label: '朱砂红', color: Color(0xFFE85B63)),
  CustomFishColor(id: 'coral', label: '珊瑚红', color: Color(0xFFEE7B74)),
  CustomFishColor(id: 'pink', label: '玫瑰粉', color: Color(0xFFEE9AB0)),
  CustomFishColor(id: 'green', label: '青苔绿', color: Color(0xFF6FB87A)),
  CustomFishColor(id: 'mint', label: '薄荷青', color: Color(0xFF7DD3B4)),
  CustomFishColor(id: 'teal', label: '湖水青', color: Color(0xFF4AB4AC)),
  CustomFishColor(id: 'cyan', label: '晴空蓝', color: Color(0xFF57B9D9)),
  CustomFishColor(id: 'blue', label: '深海蓝', color: Color(0xFF4E79CD)),
  CustomFishColor(id: 'violet', label: '鸢尾紫', color: Color(0xFF9570CC)),
  CustomFishColor(id: 'indigo', label: '靛青', color: Color(0xFF464D9F)),
];

CustomFishBody customFishBodyForId(String id) => customFishBodies.firstWhere(
  (item) => item.id == id,
  orElse: () => customFishBodies.first,
);

CustomFishTail customFishTailForId(String id) => customFishTails.firstWhere(
  (item) => item.id == id,
  orElse: () => customFishTails.first,
);

CustomFishPattern customFishPatternForId(String id) {
  // Existing saved fish may still carry the retired `eye` identifier. Render
  // them as the replacement wave pattern instead of silently falling back to
  // cloud, so old fish remain visually intact after this library update.
  final resolvedId = id == 'eye' ? 'wave' : id;
  return customFishPatterns.firstWhere(
    (item) => item.id == resolvedId,
    orElse: () => customFishPatterns.first,
  );
}

CustomFishColor customFishColorForId(String id) => customFishColors.firstWhere(
  (item) => item.id == id,
  orElse: () => customFishColors.first,
);

class FishInstance {
  const FishInstance({
    required this.id,
    required this.tankId,
    this.speciesId,
    this.variantId,
    this.customAppearance,
    required this.name,
    required this.traitIds,
    this.personalityCode,
    required this.growthStage,
    required this.satiety,
    required this.createdAt,
    required this.lastSeenAt,
  });

  factory FishInstance.fromMap(Map<String, dynamic> map) {
    return FishInstance(
      id: map['id'] as String,
      tankId: map['tank_id'] as String,
      speciesId: map['species_id'] as String?,
      variantId: map['variant_id'] as String?,
      customAppearance: map['custom_body'] == null
          ? null
          : CustomFishAppearance.fromMap(map),
      name: map['name'] as String,
      traitIds: (map['traits'] as List).cast<String>(),
      personalityCode: map['personality_code'] as String?,
      growthStage: GrowthStage.fromJson(map['growth_stage'] as String),
      satiety: map['satiety'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastSeenAt: DateTime.parse(map['last_seen_at'] as String),
    );
  }

  final String id;
  final String tankId;
  final String? speciesId;
  final String? variantId;
  final CustomFishAppearance? customAppearance;
  final String name;
  final List<String> traitIds;
  final String? personalityCode;
  bool hasPersonalityTrait(PersonalityTrait trait) {
    final named = PersonalityProfile.fromCode(personalityCode);
    return named != null ? named.legacyCodes.contains(trait.code) : traitIds.contains(trait.id);
  }
  final GrowthStage growthStage;
  final int satiety;
  final DateTime createdAt;
  final DateTime lastSeenAt;
}
