import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:yopet/features/auth/auth_providers.dart';
import 'package:yopet/features/fish/custom_fish_screen.dart';
import 'package:yopet/features/fish/fish_models.dart';
import 'package:yopet/features/fish/fish_providers.dart';
import 'package:yopet/features/fish/fish_repository.dart';
import 'package:yopet/features/home/tank.dart';

void main() {
  testWidgets('offers an eight-by-eight-by-twelve custom fish and saves it', (
    tester,
  ) async {
    final repository = _CustomFishRepository();
    await _pumpEditor(tester, repository);

    expect(find.text('水下工作台'), findsOneWidget);
    expect(find.text('鱼一直留在画布中央'), findsOneWidget);
    expect(find.text('每条都不同 · 换个个体'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('studio-tool-体型')));
    await tester.pump();
    final box = find.byKey(const ValueKey('studio-choice-箱形'));
    await tester.ensureVisible(box);
    await tester.tap(box);

    await tester.tap(find.byKey(const ValueKey('studio-tool-尾鳍')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-choice-扇形尾')));

    await tester.tap(find.byKey(const ValueKey('studio-tool-纹样')));
    await tester.pump();
    final zebra = find.byKey(const ValueKey('studio-pattern-zebra'));
    await tester.ensureVisible(zebra);
    await tester.tap(zebra);

    await tester.tap(find.byKey(const ValueKey('studio-tool-水彩')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('studio-color-blue')));

    await tester.tap(find.byKey(const ValueKey('studio-tool-名字')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('custom-fish-name')), '小蓝');
    await tester.tap(find.byKey(const Key('save-custom-fish')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(repository.savedName, '小蓝');
    expect(repository.savedAppearance?.body, 'box');
    expect(repository.savedAppearance?.tail, 'fan');
    expect(repository.savedAppearance?.pattern, 'zebra');
    expect(repository.savedAppearance?.color, 'blue');
    expect(find.text('鱼缸'), findsOneWidget);
  });

  testWidgets('saves the replacement wave pattern and opens the tank', (
    tester,
  ) async {
    final repository = _CustomFishRepository();
    await _pumpEditor(tester, repository);

    await tester.tap(find.byKey(const ValueKey('studio-tool-纹样')));
    await tester.pump();

    final patternList = find.byWidgetPredicate(
      (widget) =>
          widget is ListView && widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(patternList, const Offset(-420, 0));
    await tester.pumpAndSettle();
    final wave = find.byKey(const ValueKey('studio-pattern-wave'));
    await tester.ensureVisible(wave);
    await tester.tap(wave);

    await tester.tap(find.byKey(const ValueKey('studio-tool-名字')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('custom-fish-name')));
    await tester.enterText(find.byKey(const Key('custom-fish-name')), '波波');
    await tester.tap(find.byKey(const Key('save-custom-fish')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(repository.savedName, '波波');
    expect(repository.savedAppearance?.pattern, 'wave');
    expect(find.text('鱼缸'), findsOneWidget);
  });

  testWidgets('disables saving before editing when the tank is full', (
    tester,
  ) async {
    final repository = _CustomFishRepository(fishCount: 5);
    await _pumpEditor(tester, repository);

    expect(find.text('鱼缸住满了（5 / 5）'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save-custom-fish')),
    );
    expect(saveButton.onPressed, isNull);
    expect(repository.savedAppearance, isNull);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester,
  _CustomFishRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/custom-fish',
    routes: [
      GoRoute(
        path: '/custom-fish',
        builder: (_, _) => const CustomFishScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Center(child: Text('鱼缸'))),
      ),
      GoRoute(
        path: '/pick-fish',
        builder: (_, _) => const Scaffold(body: Center(child: Text('领养'))),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

final _tank = Tank(
  id: 'tank-1',
  ownerId: 'owner-1',
  decorationSettings: const {},
  createdAt: DateTime.utc(2026, 9, 8),
);

class _CustomFishRepository implements FishRepository {
  _CustomFishRepository({this.fishCount = 0});

  final int fishCount;
  String? savedName;
  CustomFishAppearance? savedAppearance;

  @override
  Future<FishCatalog> fetchCatalog() async => _catalog;

  @override
  Stream<List<FishInstance>> watchFish(String tankId) => Stream.value(
    List.generate(
      fishCount,
      (index) => FishInstance(
        id: 'resident-$index',
        tankId: tankId,
        name: '住民$index',
        traitIds: const ['gentle'],
        growthStage: GrowthStage.fry,
        satiety: 80,
        createdAt: DateTime.utc(2026, 9, 8),
        lastSeenAt: DateTime.utc(2026, 9, 8),
      ),
    ),
  );

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
      Future.error(UnimplementedError());

  @override
  Future<List<FishInstance>> feedTank(String tankId) async => const [];

  @override
  Future<FishInstance> adoptFish({
    required String tankId,
    required FishSpecies species,
    required FishVariant variant,
    required String name,
    required List<PersonalityTrait> availableTraits,
  }) => Future.error(UnimplementedError());

  @override
  Future<FishInstance> adoptCustomFish({
    required String tankId,
    required String name,
    required CustomFishAppearance appearance,
    required List<PersonalityTrait> availableTraits,
  }) async {
    savedName = name;
    savedAppearance = appearance;
    return FishInstance(
      id: 'custom-fish-1',
      tankId: tankId,
      name: name,
      customAppearance: appearance,
      traitIds: const ['gentle'],
      growthStage: GrowthStage.fry,
      satiety: 80,
      createdAt: DateTime.utc(2026, 9, 8),
      lastSeenAt: DateTime.utc(2026, 9, 8),
    );
  }

  @override
  Future<void> releaseFish(String fishId) async {}
}

final _catalog = FishCatalog(
  species: const [],
  traits: const [
    PersonalityTrait(
      id: 'gentle',
      code: 'gentle',
      nameZh: '温柔',
      behaviorHint: {},
    ),
  ],
);
