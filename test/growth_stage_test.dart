import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/fish/fish_models.dart';
import 'package:yopet/features/fish/fish_sprite.dart';

void main() {
  test(
    'growth stages have approved Chinese labels and distinct asset paths',
    () {
      const species = FishSpecies(
        id: 'goldfish',
        nameZh: '金鱼',
        nameEn: 'Goldfish',
        variants: [],
      );

      expect(GrowthStage.fry.nameZh, '鱼苗');
      expect(GrowthStage.juvenile.nameZh, '幼鱼');
      expect(GrowthStage.adult.nameZh, '成鱼');
      expect(species.assetPathForStage(GrowthStage.fry), endsWith('fry.png'));
      expect(
        species.assetPathForStage(GrowthStage.juvenile),
        endsWith('juvenile.png'),
      );
      expect(
        species.assetPathForStage(GrowthStage.adult),
        endsWith('adult.png'),
      );
    },
  );

  test('each visual growth step is one and a half times the prior stage', () {
    final fry = FishSprite.scaleForStage(GrowthStage.fry);
    final juvenile = FishSprite.scaleForStage(GrowthStage.juvenile);
    final adult = FishSprite.scaleForStage(GrowthStage.adult);

    expect(juvenile / fry, closeTo(1.5, 0.0001));
    expect(adult / juvenile, closeTo(1.5, 0.0001));
  });
}
