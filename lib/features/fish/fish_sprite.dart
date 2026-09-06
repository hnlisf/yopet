import 'package:flutter/material.dart';

import 'fish_models.dart';

class FishSprite extends StatelessWidget {
  const FishSprite({
    required this.species,
    required this.variant,
    this.growthStage = GrowthStage.adult,
    this.facingLeft = false,
    this.width = 120,
    super.key,
  });

  final FishSpecies species;
  final FishVariant variant;
  final GrowthStage growthStage;
  final bool facingLeft;
  final double width;

  static double scaleForStage(GrowthStage stage) => switch (stage) {
    GrowthStage.fry => 0.44,
    GrowthStage.juvenile => 0.66,
    GrowthStage.adult => 0.99,
  };

  @override
  Widget build(BuildContext context) {
    final scale = scaleForStage(growthStage);
    final sprite = ColorFiltered(
      colorFilter: ColorFilter.mode(variant.color, BlendMode.color),
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
