import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/feeding/fish_action_sheet.dart';
import 'package:yopet/features/fish/fish_models.dart';

void main() {
  testWidgets('shows a preset fish identity, age, and personality', (
    tester,
  ) async {
    await _openSheet(
      tester,
      fish: _presetFish,
      species: _goldfish,
      variant: _goldfish.variants.single,
      traits: _traits,
      onRelease: () async {},
    );

    expect(find.text('泡泡'), findsOneWidget);
    expect(find.text('金鱼 · 暖橙'), findsOneWidget);
    expect(find.text('幼鱼 · 来到鱼缸第 10 天'), findsOneWidget);
    expect(find.textContaining('大胆'), findsWidgets);
    expect(find.textContaining('好奇'), findsWidgets);
    expect(find.textContaining('常游到水面'), findsOneWidget);
    expect(find.textContaining('主动靠近看看'), findsOneWidget);
  });

  testWidgets('shows the saved combination for a custom fish', (tester) async {
    await _openSheet(
      tester,
      fish: _customFish,
      traits: _traits.take(1).toList(),
      onRelease: () async {},
    );

    expect(find.text('组合式自定义鱼 · 圆盘体型 · 花瓣尾 · 云锦'), findsOneWidget);
  });

  testWidgets('release requires a named confirmation and can be cancelled', (
    tester,
  ) async {
    var releaseCount = 0;
    await _openSheet(
      tester,
      fish: _presetFish,
      species: _goldfish,
      variant: _goldfish.variants.single,
      traits: _traits,
      onRelease: () async => releaseCount += 1,
    );

    await _tapRelease(tester);
    expect(find.text('和泡泡说再见？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('keep-fish')));
    await tester.pumpAndSettle();

    expect(releaseCount, 0);
    expect(find.text('泡泡'), findsOneWidget);

    await _tapRelease(tester);
    await tester.tap(find.byKey(const Key('confirm-release-fish')));
    await tester.pumpAndSettle();

    expect(releaseCount, 1);
    expect(find.text('泡泡'), findsNothing);
  });

  testWidgets('a failed release keeps the sheet open for retry', (
    tester,
  ) async {
    await _openSheet(
      tester,
      fish: _presetFish,
      species: _goldfish,
      variant: _goldfish.variants.single,
      traits: _traits,
      onRelease: () => Future<void>.error(Exception('offline')),
    );

    await _tapRelease(tester);
    await tester.tap(find.byKey(const Key('confirm-release-fish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('release-fish-error')), findsOneWidget);
    expect(find.text('暂时没能送别，再试一次吧。'), findsOneWidget);
    expect(find.text('泡泡'), findsOneWidget);
  });
}

Future<void> _openSheet(
  WidgetTester tester, {
  required FishInstance fish,
  required List<PersonalityTrait> traits,
  required Future<void> Function() onRelease,
  FishSpecies? species,
  FishVariant? variant,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const Key('open-fish-sheet'),
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FishActionSheet(
                  fish: fish,
                  traits: traits,
                  species: species,
                  variant: variant,
                  now: DateTime.utc(2026, 9, 14),
                  onRelease: onRelease,
                ),
              ),
              child: const Text('查看鱼'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-fish-sheet')));
  await tester.pumpAndSettle();
}

Future<void> _tapRelease(WidgetTester tester) async {
  final releaseButton = find.byKey(const Key('release-fish'));
  await tester.ensureVisible(releaseButton);
  await tester.tap(releaseButton);
  await tester.pumpAndSettle();
}

final _presetFish = FishInstance(
  id: 'fish-1',
  tankId: 'tank-1',
  speciesId: 'goldfish',
  variantId: 'goldfish-orange',
  name: '泡泡',
  traitIds: const ['trait-bold', 'trait-curious'],
  growthStage: GrowthStage.juvenile,
  satiety: 76,
  createdAt: DateTime.utc(2026, 9, 5),
  lastSeenAt: DateTime.utc(2026, 9, 14),
);

final _customFish = FishInstance(
  id: 'fish-custom',
  tankId: 'tank-1',
  name: '云尾',
  traitIds: const ['trait-bold'],
  growthStage: GrowthStage.fry,
  satiety: 80,
  createdAt: DateTime.utc(2026, 9, 8),
  lastSeenAt: DateTime.utc(2026, 9, 14),
  customAppearance: const CustomFishAppearance(
    body: 'disc',
    tail: 'petal',
    pattern: 'cloud',
    color: 'orange',
  ),
);

final _goldfish = FishSpecies(
  id: 'goldfish',
  nameZh: '金鱼',
  nameEn: 'Goldfish',
  variants: const [
    FishVariant(
      id: 'goldfish-orange',
      speciesId: 'goldfish',
      label: '暖橙',
      colorHex: '#F4AB66',
      assetFilename: 'base.png',
    ),
  ],
);

const _traits = [
  PersonalityTrait(
    id: 'trait-bold',
    code: 'bold',
    nameZh: '大胆',
    behaviorHint: {},
  ),
  PersonalityTrait(
    id: 'trait-curious',
    code: 'curious',
    nameZh: '好奇',
    behaviorHint: {},
  ),
];
