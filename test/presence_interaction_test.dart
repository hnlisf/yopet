import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/presence/presence_interaction.dart';

void main() {
  group('reactionForTraitCodes', () {
    test('covers every personality reaction branch', () {
      expect(reactionForTraitCodes(['curious']), FishReaction.curious);
      expect(reactionForTraitCodes(['shy']), FishReaction.shy);
      expect(reactionForTraitCodes(['lazy']), FishReaction.lazy);
      expect(reactionForTraitCodes(['bold']), FishReaction.bold);
    });

    test('uses calmness as the predictable multi-trait priority', () {
      expect(reactionForTraitCodes(['curious', 'lazy']), FishReaction.lazy);
      expect(reactionForTraitCodes(['curious', 'shy']), FishReaction.shy);
    });
  });

  test('reaction destinations match the selected personality', () {
    const current = Alignment(0.3, 0.2);
    const tap = Alignment(-0.4, -0.2);

    expect(
      reactionDestination(
        reaction: FishReaction.curious,
        currentPosition: current,
        tapPosition: tap,
      ),
      tap,
    );
    expect(
      reactionDestination(
        reaction: FishReaction.lazy,
        currentPosition: current,
        tapPosition: tap,
      ),
      current,
    );
    expect(
      reactionDestination(
        reaction: FishReaction.bold,
        currentPosition: current,
        tapPosition: tap,
      ),
      const Alignment(0, -0.16),
    );

    final shy = reactionDestination(
      reaction: FishReaction.shy,
      currentPosition: current,
      tapPosition: tap,
    );
    expect(shy.x, greaterThan(current.x));
    expect(shy.y, greaterThan(current.y));
  });

  test('a return greeting requires at least ten minutes away', () {
    final lastSeenAt = DateTime.utc(2026, 9, 6, 9);
    expect(
      shouldGreetAfterAbsence(
        lastSeenAt: lastSeenAt,
        now: lastSeenAt.add(const Duration(minutes: 9, seconds: 59)),
      ),
      isFalse,
    );
    expect(
      shouldGreetAfterAbsence(
        lastSeenAt: lastSeenAt,
        now: lastSeenAt.add(const Duration(minutes: 10)),
      ),
      isTrue,
    );
  });
}
