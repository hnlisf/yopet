import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/data/decorations.dart';
import 'package:yopet/features/decorations/decoration_providers.dart';
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

  testWidgets('a placed object can be dragged and removed from the tank', (
    tester,
  ) async {
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

    final object = find.byType(GestureDetector);
    await tester.drag(object, const Offset(54, -24));
    await tester.pump();
    expect(moved, hasLength(1));
    expect(moved.single.$1, same(decoration));
    expect(moved.single.$2.dx, greaterThan(decoration.positionX));

    await tester.tap(object);
    await tester.pump();
    expect(removed, [decoration]);
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
  Future<void> removeDecoration(String decorationId) async {}
}
