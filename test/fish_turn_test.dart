import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/home/fish_turn.dart';

void main() {
  for (final left in [true, false]) {
    testWidgets('left-facing artwork points ${left ? 'left' : 'right'}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FishTurn(
            facingLeft: left,
            child: const SizedBox(width: 108, height: 60),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final sides = tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(FishTurn),
              matching: find.byType(Opacity),
            ),
          )
          .where((o) => o.opacity == 1);
      expect(sides, hasLength(1));
      final transform = sides.single.child as Transform;
      // Artwork has its head on the left: unmirrored = left-facing.
      expect(transform.transform.entry(0, 0).sign, left ? 1 : -1);
    });
  }
  testWidgets('turn retains body volume throughout a reversal', (tester) async {
    Future<void> show(bool left) => tester.pumpWidget(
      MaterialApp(
        home: FishTurn(
          facingLeft: left,
          child: const SizedBox(width: 108, height: 60),
        ),
      ),
    );
    await show(false);
    await show(true);
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      for (final transform in tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(FishTurn),
          matching: find.byType(Transform),
        ),
      )) {
        expect(
          transform.transform.entry(0, 0).abs(),
          greaterThanOrEqualTo(.70),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });
}
