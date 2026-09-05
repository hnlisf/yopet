import 'package:flutter/material.dart';

enum DecorationType { plant, stone, driftwood, background }

extension DecorationTypeLabel on DecorationType {
  String get label => switch (this) {
    DecorationType.plant => '水草',
    DecorationType.stone => '石景',
    DecorationType.driftwood => '沉木',
    DecorationType.background => '背景',
  };
}

class DecorationDefinition {
  const DecorationDefinition({
    required this.code,
    required this.nameZh,
    required this.type,
    required this.assetPath,
    required this.defaultPosition,
    this.widthFactor = 0.28,
  });

  final String code;
  final String nameZh;
  final DecorationType type;
  final String assetPath;
  final Offset defaultPosition;
  final double widthFactor;
}

/// The approved watercolor decoration catalogue. It intentionally has no price,
/// rarity, or unlock state: every item is a visual-only choice.
const decorationCatalog = <DecorationDefinition>[
  DecorationDefinition(
    code: 'long_plant',
    nameZh: '长叶水草',
    type: DecorationType.plant,
    assetPath: 'assets/decorations/plants/long.png',
    defaultPosition: Offset(0.16, 0.76),
    widthFactor: 0.26,
  ),
  DecorationDefinition(
    code: 'round_plant',
    nameZh: '圆叶水草',
    type: DecorationType.plant,
    assetPath: 'assets/decorations/plants/round.png',
    defaultPosition: Offset(0.79, 0.74),
    widthFactor: 0.25,
  ),
  DecorationDefinition(
    code: 'ribbon_plant',
    nameZh: '缎带水草',
    type: DecorationType.plant,
    assetPath: 'assets/decorations/plants/ribbon.png',
    defaultPosition: Offset(0.67, 0.78),
    widthFactor: 0.24,
  ),
  DecorationDefinition(
    code: 'moss_rock',
    nameZh: '青苔石景',
    type: DecorationType.stone,
    assetPath: 'assets/decorations/stones/moss.png',
    defaultPosition: Offset(0.27, 0.83),
    widthFactor: 0.28,
  ),
  DecorationDefinition(
    code: 'moon_sand',
    nameZh: '月光砂',
    type: DecorationType.stone,
    assetPath: 'assets/decorations/stones/sand.png',
    defaultPosition: Offset(0.51, 0.9),
    widthFactor: 0.44,
  ),
  DecorationDefinition(
    code: 'arch_rock',
    nameZh: '月石拱门',
    type: DecorationType.stone,
    assetPath: 'assets/decorations/stones/arch.png',
    defaultPosition: Offset(0.74, 0.8),
    widthFactor: 0.31,
  ),
  DecorationDefinition(
    code: 'driftwood',
    nameZh: '缓流沉木',
    type: DecorationType.driftwood,
    assetPath: 'assets/decorations/driftwood/driftwood.png',
    defaultPosition: Offset(0.47, 0.78),
    widthFactor: 0.34,
  ),
  DecorationDefinition(
    code: 'branch_wood',
    nameZh: '枝桠沉木',
    type: DecorationType.driftwood,
    assetPath: 'assets/decorations/driftwood/branch.png',
    defaultPosition: Offset(0.29, 0.7),
    widthFactor: 0.31,
  ),
  DecorationDefinition(
    code: 'rootwood',
    nameZh: '根系小屋',
    type: DecorationType.driftwood,
    assetPath: 'assets/decorations/driftwood/rootwood.png',
    defaultPosition: Offset(0.74, 0.72),
    widthFactor: 0.31,
  ),
  DecorationDefinition(
    code: 'midnight',
    nameZh: '静谧深海',
    type: DecorationType.background,
    assetPath: 'assets/tank/background.png',
    defaultPosition: Offset(0.5, 0.5),
  ),
  DecorationDefinition(
    code: 'moonlit',
    nameZh: '月光浅湾',
    type: DecorationType.background,
    assetPath: 'assets/decorations/backgrounds/moonlit.png',
    defaultPosition: Offset(0.5, 0.5),
  ),
  DecorationDefinition(
    code: 'aurora',
    nameZh: '青绿极光',
    type: DecorationType.background,
    assetPath: 'assets/decorations/backgrounds/aurora.png',
    defaultPosition: Offset(0.5, 0.5),
  ),
];

DecorationDefinition? decorationForCode(String code) {
  for (final decoration in decorationCatalog) {
    if (decoration.code == code) return decoration;
  }
  return null;
}
