import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/data/decorations.dart';
import 'package:yopet/features/decorations/decoration_providers.dart';
import 'package:yopet/features/decorations/decoration_layout.dart';
import 'package:yopet/features/decorations/decoration_layer.dart';
import 'package:yopet/features/decorations/decoration_repository.dart';
import 'package:yopet/features/decorations/decoration_sheet.dart';
import 'package:yopet/features/decorations/tank_decoration.dart';

void main() {
  test('approved decoration catalogue has three choices in every category', () {
    expect(decorationCatalog, hasLength(12));
    expect(
      decorationCatalog.map((decoration) => decoration.code).toSet(),
      hasLength(12),
    );
    for (final type in DecorationType.values) {
      expect(
        decorationCatalog.where((decoration) => decoration.type == type),
        hasLength(3),
      );
    }
    expect(
      decorationCatalog.every(
        (decoration) =>
            decoration.defaultPosition.dx >= 0 &&
            decoration.defaultPosition.dx <= 1 &&
            decoration.defaultPosition.dy >= 0 &&
            decoration.defaultPosition.dy <= 1,
      ),
      isTrue,
    );
  });

  test('TankDecoration maps realtime rows', () {
    final decoration = TankDecoration.fromMap({
      'id': 'decor-1',
      'tank_id': 'tank-1',
      'decoration_code': 'long_plant',
      'decoration_type': 'plant',
      'position_x': 0.25,
      'position_y': 0.75,
      'placed_at': '2026-09-06T00:00:00Z',
    });

    expect(decoration.type, DecorationType.plant);
    expect(decoration.positionX, 0.25);
    expect(decoration.positionY, 0.75);
  });

  test('TankDecoration keeps an edited size from a realtime row', () {
    final decoration = TankDecoration.fromMap({
      'id': 'decor-scale',
      'tank_id': 'tank-1',
      'decoration_code': 'driftwood',
      'decoration_type': 'driftwood',
      'position_x': 0.5,
      'position_y': 0.94,
      'scale_factor': 1.3,
      'placed_at': '2026-09-06T00:00:00Z',
    });

    expect(decoration.scaleFactor, 1.3);
  });

  testWidgets(
    'the drawer filters categories and places the tapped decoration',
    (tester) async {
      final repository = _FakeDecorationRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            decorationRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DecorationSheet(tankId: 'tank-1')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('水草预设'), findsOneWidget);
      expect(find.text('长叶水草'), findsOneWidget);
      await tester.tap(find.byKey(const Key('decoration-long_plant')));
      await tester.pump();
      expect(repository.placedCodes, ['long_plant']);

      await tester.tap(find.text('背景'));
      await tester.pumpAndSettle();
      expect(find.text('静谧深海'), findsOneWidget);
      expect(find.text('月光浅湾'), findsOneWidget);
      expect(find.text('青绿极光'), findsOneWidget);
    },
  );

  testWidgets(
    'a placed object can be dragged, selected, and removed from the tank',
    (tester) async {
      final decoration = TankDecoration(
        id: 'decor-1',
        tankId: 'tank-1',
        code: 'long_plant',
        type: DecorationType.plant,
        positionX: 0.3,
        positionY: 0.7,
        placedAt: DateTime.utc(2026, 9, 6),
      );
      final moved = <(TankDecoration, Offset)>[];
      final removed = <TankDecoration>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 360,
              child: TankDecorationsLayer(
                decorations: [decoration],
                onMove: moved.add,
                onRemove: removed.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final object = find.byKey(const Key('placed-decoration-decor-1'));
      await tester.drag(object, const Offset(54, -24));
      await tester.pump();
      expect(moved, hasLength(1));
      expect(moved.single.$1, same(decoration));
      expect(moved.single.$2.dx, greaterThan(decoration.positionX));

      expect(
        find.byKey(const Key('decoration-scale-up-decor-1')),
        findsOneWidget,
      );
      expect(removed, isEmpty);

      await tester.tap(find.byKey(const Key('decoration-remove-decor-1')));
      await tester.pump();
      expect(removed, [decoration]);
    },
  );

  testWidgets('a placed object can be moved all the way to the tank floor', (
    tester,
  ) async {
    final decoration = TankDecoration(
      id: 'decor-floor',
      tankId: 'tank-1',
      code: 'driftwood',
      type: DecorationType.driftwood,
      positionX: 0.5,
      positionY: 0.72,
      placedAt: DateTime.utc(2026, 9, 6),
    );
    final moved = <(TankDecoration, Offset)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 360,
            child: TankDecorationsLayer(
              decorations: [decoration],
              onMove: moved.add,
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('placed-decoration-decor-floor')),
      const Offset(0, 500),
    );
    await tester.pump();

    expect(moved, hasLength(1));
    expect(moved.single.$2.dy, closeTo(1, 0.001));
  });

  testWidgets('a selected object reports a bounded size adjustment', (
    tester,
  ) async {
    final decoration = TankDecoration(
      id: 'decor-resize',
      tankId: 'tank-1',
      code: 'driftwood',
      type: DecorationType.driftwood,
      positionX: 0.5,
      positionY: 0.8,
      placedAt: DateTime.utc(2026, 9, 6),
    );
    final resized = <(TankDecoration, double)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 360,
            child: TankDecorationsLayer(
              decorations: [decoration],
              onMove: (_) {},
              onResize: resized.add,
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('placed-decoration-decor-resize')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('decoration-scale-up-decor-resize')));
    await tester.pump();

    expect(resized, [(decoration, 1.1)]);
  });

  testWidgets('tapping a selected object again confirms its placement', (
    tester,
  ) async {
    final decoration = TankDecoration(
      id: 'decor-confirm',
      tankId: 'tank-1',
      code: 'rootwood',
      type: DecorationType.driftwood,
      positionX: 0.5,
      positionY: 1,
      placedAt: DateTime.utc(2026, 9, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 360,
            child: TankDecorationsLayer(
              decorations: [decoration],
              onMove: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final object = find.byKey(const Key('placed-decoration-decor-confirm'));
    await tester.tap(object);
    await tester.pump();
    expect(
      find.byKey(const Key('decoration-confirm-decor-confirm')),
      findsOneWidget,
    );

    await tester.tap(object);
    await tester.pump();
    expect(
      find.byKey(const Key('decoration-confirm-decor-confirm')),
      findsNothing,
    );
  });

  testWidgets('tapping outside a selected object confirms its placement', (
    tester,
  ) async {
    final decoration = TankDecoration(
      id: 'decor-outside-confirm',
      tankId: 'tank-1',
      code: 'rootwood',
      type: DecorationType.driftwood,
      positionX: 0.5,
      positionY: 0.8,
      placedAt: DateTime.utc(2026, 9, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 360,
            child: TankDecorationsLayer(
              decorations: [decoration],
              onMove: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('placed-decoration-decor-outside-confirm')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('decoration-confirm-decor-outside-confirm')),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(12, 12));
    await tester.pump();
    expect(
      find.byKey(const Key('decoration-confirm-decor-outside-confirm')),
      findsNothing,
    );
  });

  test('a driftwood silhouette reaches the visible tank floor', () {
    final definition = decorationForCode('driftwood')!;
    const tankWidth = 320.0;
    const tankHeight = 360.0;
    final size = tankWidth * definition.widthFactor * 1.2;

    final visibleBottom = TankDecorationLayout.visibleBottomForPosition(
      positionY: 1,
      tankHeight: tankHeight,
      size: size,
      contentBottomInset: definition.contentBottomInset,
    );

    expect(visibleBottom, closeTo(tankHeight, 1));
  });
}

class _FakeDecorationRepository implements DecorationRepository {
  final placedCodes = <String>[];

  @override
  Stream<List<TankDecoration>> watchDecorations(String tankId) {
    return Stream.value(const <TankDecoration>[]);
  }

  @override
  Future<TankDecoration> placeDecoration({
    required String tankId,
    required DecorationDefinition decoration,
    Offset? position,
  }) async {
    placedCodes.add(decoration.code);
    final point = position ?? decoration.defaultPosition;
    return TankDecoration(
      id: 'decor-${decoration.code}',
      tankId: tankId,
      code: decoration.code,
      type: decoration.type,
      positionX: point.dx,
      positionY: point.dy,
      placedAt: DateTime.utc(2026, 9, 6),
    );
  }

  @override
  Future<void> moveDecoration({
    required TankDecoration decoration,
    required Offset position,
  }) async {}

  @override
  Future<void> resizeDecoration({
    required TankDecoration decoration,
    required double scaleFactor,
  }) async {}

  @override
  Future<void> removeDecoration(String decorationId) async {}
}
