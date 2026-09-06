import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yopet/features/auth/auth_providers.dart';
import 'package:yopet/features/fish/fish_models.dart';
import 'package:yopet/features/fish/fish_picker_screen.dart';
import 'package:yopet/features/fish/fish_providers.dart';
import 'package:yopet/features/fish/fish_repository.dart';
import 'package:yopet/features/home/tank.dart';

void main() {
  testWidgets('shows 12 species, validates the name, and adopts', (
    tester,
  ) async {
    final repository = _FakeFishRepository();
    await _pumpPicker(tester, repository);

    expect(find.text('金鱼'), findsOneWidget);
    expect(find.text('鼠鱼'), findsOneWidget);

    await _scrollToBottom(tester);
    await tester.tap(find.byKey(const Key('confirm-adoption')));
    await tester.pump();
    expect(find.text('请输入 1–20 个字符的名字'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  泡泡  ');
    await tester.tap(find.byKey(const Key('confirm-adoption')));
    await tester.pumpAndSettle();

    expect(repository.adoptedNames, ['泡泡']);
    expect(find.text('鱼缸'), findsOneWidget);
  });

  testWidgets('disables adoption and explains when the tank has five fish', (
    tester,
  ) async {
    final repository = _FakeFishRepository(fishCount: 5);
    await _pumpPicker(tester, repository);

    await _scrollToBottom(tester);
    final fullLabel = find.text('鱼缸住满了（5 / 5）');
    await tester.tap(fullLabel);
    await tester.pump();

    expect(find.text('鱼缸已经住满 5 条鱼啦'), findsOneWidget);
    expect(repository.adoptedNames, isEmpty);
  });
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollView = find.byType(CustomScrollView);
  for (var attempt = 0; attempt < 6; attempt++) {
    await tester.drag(scrollView, const Offset(0, -550));
    await tester.pumpAndSettle();
    if (find.byKey(const Key('confirm-adoption')).evaluate().isNotEmpty) return;
  }
  fail('The adoption button was not reached after scrolling');
}

Future<void> _pumpPicker(
  WidgetTester tester,
  _FakeFishRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/pick-fish',
    routes: [
      GoRoute(path: '/pick-fish', builder: (_, _) => const FishPickerScreen()),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Center(child: Text('鱼缸'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tankStreamProvider.overrideWith((ref) => Stream.value(_tank)),
        fishRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

final _tank = Tank(
  id: 'tank-1',
  ownerId: 'owner-1',
  decorationSettings: const {},
  createdAt: DateTime.utc(2026, 9, 5),
);

class _FakeFishRepository implements FishRepository {
  _FakeFishRepository({this.fishCount = 0});

  final int fishCount;
  final adoptedNames = <String>[];

  @override
  Future<FishCatalog> fetchCatalog() async => _catalog;

  @override
  Stream<List<FishInstance>> watchFish(String tankId) {
    return Stream.value(
      List.generate(fishCount, (index) => _fish('fish-$index', '鱼$index')),
    );
  }

  @override
  Future<void> syncTankSatiety(String tankId) async {}

  @override
  Future<void> syncTankGrowth(String tankId) async {}

  @override
  Future<void> updateLastSeen({
    required Iterable<String> fishIds,
    required DateTime at,
  }) async {}

  @override
  Future<FishInstance> feedFish(String fishId) async => _fish(fishId, '鱼');

  @override
  Future<FishInstance> adoptFish({
    required String tankId,
    required FishSpecies species,
    required FishVariant variant,
    required String name,
    required List<PersonalityTrait> availableTraits,
  }) async {
    adoptedNames.add(name);
    return _fish('adopted-1', name);
  }
}

FishInstance _fish(String id, String name) {
  return FishInstance(
    id: id,
    tankId: 'tank-1',
    speciesId: 'goldfish',
    variantId: 'goldfish_classic',
    name: name,
    traitIds: const ['trait-bold'],
    growthStage: GrowthStage.fry,
    satiety: 80,
    createdAt: DateTime.utc(2026, 9, 5),
    lastSeenAt: DateTime.utc(2026, 9, 5),
  );
}

final _catalog = FishCatalog(
  species:
      const [
            ('goldfish', '金鱼'),
            ('guppy', '孔雀鱼'),
            ('betta', '斗鱼'),
            ('angel', '神仙鱼'),
            ('koi', '锦鲤'),
            ('discus', '七彩神仙'),
            ('neon', '霓虹灯鱼'),
            ('zebra', '斑马鱼'),
            ('swordtail', '剑尾鱼'),
            ('molly', '玛丽鱼'),
            ('barb', '虎皮鱼'),
            ('cory', '鼠鱼'),
          ]
          .map(
            (item) => FishSpecies(
              id: item.$1,
              nameZh: item.$2,
              nameEn: item.$1,
              variants: [
                FishVariant(
                  id: item.$1 == 'goldfish'
                      ? 'goldfish_classic'
                      : '${item.$1}_classic',
                  speciesId: item.$1,
                  label: '水彩',
                  colorHex: '#5BA8B5',
                  assetFilename: 'base.png',
                ),
              ],
            ),
          )
          .toList(),
  traits: const [
    PersonalityTrait(
      id: 'trait-bold',
      code: 'bold',
      nameZh: '大胆',
      behaviorHint: {},
    ),
  ],
);
