import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/auth/auth_providers.dart';
import 'package:yopet/features/decorations/decoration_providers.dart';
import 'package:yopet/features/decorations/tank_decoration.dart';
import 'package:yopet/features/fish/fish_models.dart';
import 'package:yopet/features/fish/fish_providers.dart';
import 'package:yopet/features/fish/fish_repository.dart';
import 'package:yopet/features/home/home_screen.dart';
import 'package:yopet/features/home/tank.dart';

void main() {
  testWidgets('exposes whole-tank feeding and fish profiles as actions', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tankStreamProvider.overrideWith((ref) => Stream.value(_tank)),
          fishRepositoryProvider.overrideWithValue(_HomeFishRepository()),
          tankDecorationsProvider(
            _tank.id,
          ).overrideWith((ref) => Stream.value(const <TankDecoration>[])),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final feedControl = find.bySemanticsLabel('一起喂食');
    expect(feedControl, findsOneWidget);
    await tester.tap(feedControl);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('全缸平均饱腹度 80%'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 300));

    final fishProfileControl = find.bySemanticsLabel('泡泡正在鱼缸里游动，打开档案');
    expect(fishProfileControl, findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('泡泡正在鱼缸里游动，打开档案'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('金鱼 · 暖橙'), findsOneWidget);
    expect(find.text('让它去新的水域'), findsOneWidget);
    semanticsHandle.dispose();
  });
}

final _tank = Tank(
  id: 'tank-home-test',
  ownerId: 'owner-home-test',
  decorationSettings: const {},
  createdAt: DateTime.utc(2026, 9, 5),
);

final _catalog = FishCatalog(
  species: const [
    FishSpecies(
      id: 'goldfish',
      nameZh: '金鱼',
      nameEn: 'Goldfish',
      variants: [
        FishVariant(
          id: 'goldfish_classic',
          speciesId: 'goldfish',
          label: '暖橙',
          colorHex: '#F4AB66',
          assetFilename: 'goldfish_classic.png',
        ),
      ],
    ),
  ],
  traits: const [
    PersonalityTrait(
      id: 'trait-bold',
      code: 'bold',
      nameZh: '大胆',
      behaviorHint: {},
    ),
  ],
);

final _fish = FishInstance(
  id: 'fish-home-test',
  tankId: _tank.id,
  speciesId: 'goldfish',
  variantId: 'goldfish_classic',
  name: '泡泡',
  traitIds: const ['trait-bold'],
  growthStage: GrowthStage.juvenile,
  satiety: 80,
  createdAt: DateTime.utc(2026, 9, 5),
  lastSeenAt: DateTime.utc(2026, 9, 14),
);

class _HomeFishRepository implements FishRepository {
  @override
  Future<FishCatalog> fetchCatalog() async => _catalog;

  @override
  Stream<List<FishInstance>> watchFish(String tankId) {
    return Stream.value([_fish]);
  }

  @override
  Future<void> syncTankGrowth(String tankId) async {}

  @override
  Future<void> syncTankSatiety(String tankId) async {}

  @override
  Future<void> updateLastSeen({
    required Iterable<String> fishIds,
    required DateTime at,
  }) async {}

  @override
  Future<FishInstance> feedFish(String fishId) async => _fish;

  @override
  Future<List<FishInstance>> feedTank(String tankId) async => [_fish];

  @override
  Future<FishInstance> adoptFish({
    required String tankId,
    required FishSpecies species,
    required FishVariant variant,
    required String name,
    required List<PersonalityTrait> availableTraits,
  }) async => _fish;

  @override
  Future<FishInstance> adoptCustomFish({
    required String tankId,
    required String name,
    required CustomFishAppearance appearance,
    required List<PersonalityTrait> availableTraits,
  }) async => _fish;

  @override
  Future<void> releaseFish(String fishId) async {}
}
