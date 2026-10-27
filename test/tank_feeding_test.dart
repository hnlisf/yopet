import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/feeding/tank_feeding.dart';
import 'package:yopet/features/fish/fish_models.dart';
import 'package:yopet/features/fish/fish_providers.dart';
import 'package:yopet/features/fish/fish_repository.dart';

void main() {
  testWidgets('remounting after companion mode does not replay an old meal', (
    tester,
  ) async {
    Widget scene(int token) => MaterialApp(
      home: SizedBox(
        width: 400,
        height: 400,
        child: TankFeedingAnimation(token: token),
      ),
    );
    await tester.pumpWidget(scene(0));
    await tester.pumpWidget(scene(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LayoutBuilder), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(scene(1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LayoutBuilder), findsNothing);
    await tester.pumpWidget(scene(2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LayoutBuilder), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('summarises the tank and delegates one shared feeding action', (
    tester,
  ) async {
    final repository = _FakeFishRepository();
    var fed = 0;

    await _openSheet(
      tester,
      repository: repository,
      fish: const [
        _FishFixture(name: '云尾', satiety: 20),
        _FishFixture(name: '微光', satiety: 80),
        _FishFixture(name: '泡泡', satiety: 100),
      ],
      onFed: () => fed += 1,
    );

    expect(find.text('全缸平均饱腹度 66%'), findsOneWidget);
    expect(find.text('1 条小鱼有点饿了。'), findsOneWidget);
    expect(find.text('撒下鱼食 · 全缸 +25'), findsOneWidget);

    await tester.tap(find.byKey(const Key('feed-tank-confirm')));
    await tester.pumpAndSettle();

    expect(repository.fedTankIds, ['tank-1']);
    expect(fed, 1);
    expect(find.text('3 条小鱼一起开饭啦'), findsOneWidget);
  });

  testWidgets('does not submit a meal when every fish is already satisfied', (
    tester,
  ) async {
    final repository = _FakeFishRepository();

    await _openSheet(
      tester,
      repository: repository,
      fish: const [
        _FishFixture(name: '云尾', satiety: 100),
        _FishFixture(name: '微光', satiety: 100),
      ],
      onFed: () {},
    );

    expect(find.text('大家都吃得很满足'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('feed-tank-confirm')))
          .onPressed,
      isNull,
    );
    expect(repository.fedTankIds, isEmpty);
  });
}

Future<void> _openSheet(
  WidgetTester tester, {
  required _FakeFishRepository repository,
  required List<_FishFixture> fish,
  required VoidCallback onFed,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [fishRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              key: const Key('open-tank-feeding'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => TankFeedingSheet(
                  tankId: 'tank-1',
                  fish: fish.map((item) => item.toFish()).toList(),
                  onFed: onFed,
                ),
              ),
              child: const Text('一起喂食'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('open-tank-feeding')));
  await tester.pumpAndSettle();
}

class _FishFixture {
  const _FishFixture({required this.name, required this.satiety});

  final String name;
  final int satiety;

  FishInstance toFish() => FishInstance(
    id: name,
    tankId: 'tank-1',
    speciesId: 'goldfish',
    variantId: 'goldfish_classic',
    name: name,
    traitIds: const ['trait-bold'],
    growthStage: GrowthStage.adult,
    satiety: satiety,
    createdAt: DateTime.utc(2026, 9, 1),
    lastSeenAt: DateTime.utc(2026, 9, 1),
  );
}

class _FakeFishRepository implements FishRepository {
  @override
  Future<void> updatePersonality(
    String fishId,
    List<PersonalityTrait> traits,
  ) async {}
  final fedTankIds = <String>[];

  @override
  Future<FishCatalog> fetchCatalog() async =>
      const FishCatalog(species: [], traits: []);

  @override
  Stream<List<FishInstance>> watchFish(String tankId) => const Stream.empty();

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
  Future<FishInstance> feedFish(String fishId) =>
      Future<FishInstance>.error(UnimplementedError());

  @override
  Future<List<FishInstance>> feedTank(String tankId) async {
    fedTankIds.add(tankId);
    return const [];
  }

  @override
  Future<FishInstance> adoptFish({
    required String tankId,
    required FishSpecies species,
    required FishVariant variant,
    required String name,
    required List<PersonalityTrait> availableTraits,
  }) => Future<FishInstance>.error(UnimplementedError());

  @override
  Future<FishInstance> adoptCustomFish({
    required String tankId,
    required String name,
    required CustomFishAppearance appearance,
    required List<PersonalityTrait> availableTraits,
  }) => Future<FishInstance>.error(UnimplementedError());

  @override
  Future<void> releaseFish(String fishId) async {}
}
