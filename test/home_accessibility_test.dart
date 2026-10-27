import 'package:flutter/material.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/auth/auth_providers.dart';
import 'package:yopet/features/decorations/decoration_providers.dart';
import 'package:yopet/features/decorations/decoration_repository.dart';
import 'package:yopet/data/decorations.dart';
import 'package:yopet/features/decorations/tank_decoration.dart';
import 'package:yopet/features/fish/fish_models.dart';
import 'package:yopet/features/fish/fish_providers.dart';
import 'package:yopet/features/fish/fish_repository.dart';
import 'package:yopet/features/home/home_screen.dart';
import 'package:yopet/features/home/fish_turn.dart';
import 'package:yopet/features/home/tank.dart';

void main() {
  testWidgets(
    'slow blank-water hover makes a social fish follow without a profile',
    (tester) async {
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
      final start = tester.getCenter(find.byType(FishTurn));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: start + const Offset(90, -20));
      await mouse.moveTo(start + const Offset(95, -20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await mouse.moveTo(start + const Offset(120, -20));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        tester.getCenter(find.byType(FishTurn)).dx,
        greaterThan(start.dx + 20),
      );
      expect(find.byKey(const Key('release-fish')), findsNothing);
      await mouse.removePointer();
    },
  );
  testWidgets('clicking beside a fish does not open its profile', (
    tester,
  ) async {
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
    final fishRect = tester.getRect(find.byType(FishTurn));
    await tester.tapAt(fishRect.center + const Offset(90, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('release-fish')), findsNothing);
    expect(find.byKey(const ValueKey('companion-call-1')), findsOneWidget);
    // Exercise actual ticking motion, not just ripple creation or parameters.
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final responsePosition = tester.getCenter(find.byType(FishTurn));
    expect((responsePosition - fishRect.center).distance, greaterThan(20));
    await tester.tapAt(
      tester.getCenter(find.byType(FishTurn)) + const Offset(90, 0),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('companion-call-2')), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(FishTurn)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('release-fish')), findsOneWidget);
  });
  for (final scenario in [
    ('long_plant', false),
    ('moss_rock', false),
    ('driftwood', false),
    ('long_plant', true),
  ]) {
    final (code, fails) = scenario;
    testWidgets('$code removal without realtime (failure: $fails)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _RemoveDecorationRepository()..fails = fails;
      final definition = decorationForCode(code)!;
      final item = TankDecoration(
        id: 'remove-test',
        tankId: _tank.id,
        code: definition.code,
        type: definition.type,
        positionX: .2,
        positionY: .8,
        placedAt: DateTime.utc(2026, 10, 6),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tankStreamProvider.overrideWith((ref) => Stream.value(_tank)),
            fishRepositoryProvider.overrideWithValue(_HomeFishRepository()),
            decorationRepositoryProvider.overrideWithValue(repository),
            tankDecorationsProvider(_tank.id).overrideWith(
              (ref) => Stream.value(
                repository.removed ? <TankDecoration>[] : [item],
              ),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final object = find.byKey(const Key('placed-decoration-remove-test'));
      expect(object, findsOneWidget);
      await tester.tap(object);
      await tester.pump();
      await tester.tap(find.byKey(const Key('decoration-remove-remove-test')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(repository.removed, !fails);
      expect(object, fails ? findsOneWidget : findsNothing);
      if (fails) expect(find.text('暂时没能移除装饰，再试一次吧'), findsOneWidget);
    });
  }
  testWidgets(
    'successful farewell removes fish without a realtime event or page reload',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _HomeFishRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tankStreamProvider.overrideWith((ref) => Stream.value(_tank)),
            fishRepositoryProvider.overrideWithValue(repository),
            tankDecorationsProvider(
              _tank.id,
            ).overrideWith((ref) => Stream.value(const <TankDecoration>[])),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      tester.semantics.tap(find.semantics.byLabel('泡泡正在鱼缸里游动，打开档案'));
      await tester.pump(const Duration(milliseconds: 300));
      final release = find.byKey(const Key('release-fish'));
      await tester.ensureVisible(release);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(release);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('confirm-release-fish')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.hasFish, isFalse);
      expect(find.bySemanticsLabel('泡泡正在鱼缸里游动，打开档案'), findsNothing);
      handle.dispose();
    },
  );
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

    await tester.pump(const Duration(seconds: 1));
    final beforeMeal = tester.getCenter(find.byType(FishTurn));
    await tester.tap(find.byKey(const Key('feed-tank-confirm')));
    await tester.pump();
    for (var frame = 0; frame < 100; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      tester.getCenter(find.byType(FishTurn)).dx,
      lessThan(beforeMeal.dx - 20),
    );

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
  Future<void> updatePersonality(
    String fishId,
    List<PersonalityTrait> traits,
  ) async {}
  bool hasFish = true;
  @override
  Future<FishCatalog> fetchCatalog() async => _catalog;

  @override
  Stream<List<FishInstance>> watchFish(String tankId) {
    return Stream.value(hasFish ? [_fish] : <FishInstance>[]);
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
  Future<void> releaseFish(String fishId) async {
    hasFish = false;
  }
}

class _RemoveDecorationRepository implements DecorationRepository {
  bool removed = false;
  bool fails = false;
  @override
  Future<void> removeDecoration(String id) async {
    if (fails) throw StateError('simulated server failure');
    removed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
