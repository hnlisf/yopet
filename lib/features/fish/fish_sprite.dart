import 'package:flutter/material.dart';

import 'fish_models.dart';
import 'fish_fin_mesh.dart';

class FishSprite extends StatelessWidget {
  const FishSprite({
    required this.species,
    required this.variant,
    this.growthStage = GrowthStage.adult,
    this.facingLeft = false,
    this.width = 120,
    this.finPhase = 0,
    this.finStrength = 0,
    super.key,
  });

  final FishSpecies species;
  final FishVariant variant;
  final GrowthStage growthStage;
  final bool facingLeft;
  final double width;
  final double finPhase;
  final double finStrength;

  static double scaleForStage(GrowthStage stage) => switch (stage) {
    GrowthStage.fry => 0.44,
    GrowthStage.juvenile => 0.66,
    GrowthStage.adult => 0.99,
  };

  @override
  Widget build(BuildContext context) {
    final scale = scaleForStage(growthStage);
    if (finStrength > 0 && !MediaQuery.disableAnimationsOf(context)) {
      return Transform.flip(
        flipX: facingLeft,
        child: FishFinAsset(
          assetPath: species.assetPathForStage(growthStage),
          tint: variant.color,
          width: width * scale,
          phase: finPhase,
          strength: finStrength,
        ),
      );
    }
    final sprite = ColorFiltered(
      // `BlendMode.color` paints an opaque rectangle in Flutter Web. Modulate
      // keeps the PNG alpha channel intact while preserving watercolor light
      // and shade inside the chosen variant tint.
      colorFilter: ColorFilter.mode(variant.color, BlendMode.modulate),
      child: Image.asset(
        species.assetPathForStage(growthStage),
        width: width * scale,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => Icon(
          Icons.set_meal_rounded,
          size: width * scale * 0.7,
          color: variant.color,
        ),
      ),
    );
    return Transform.flip(flipX: facingLeft, child: sprite);
  }
}
