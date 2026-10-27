import 'dart:math';

import 'package:flutter/material.dart';

/// The absence required before a fish acknowledges a returning player.
const presenceGreetingThreshold = Duration(minutes: 10);

/// Evaluate a loaded tank once, not each realtime update or build.
class StartupGreetingGate {
  bool _checked = false;
  bool check(Iterable<DateTime> lastSeenTimes, DateTime now) {
    if (_checked || lastSeenTimes.isEmpty) return false;
    _checked = true;
    final mostRecent = lastSeenTimes.reduce((a, b) => a.isAfter(b) ? a : b);
    return shouldGreetAfterAbsence(lastSeenAt: mostRecent, now: now);
  }
}

enum FishReaction { curious, shy, lazy, bold, greeting }

/// Resolves a fish's single, predictable response when it has multiple traits.
///
/// The adoption flow intentionally gives fish one to three traits. A calm
/// response takes precedence over a social one, so a lazy fish never appears
/// to contradict its defining trait when the player taps it.
FishReaction reactionForTraitCodes(Iterable<String> traitCodes) {
  final codes = traitCodes.toSet();
  if (codes.contains('lazy')) return FishReaction.lazy;
  if (codes.contains('shy')) return FishReaction.shy;
  if (codes.contains('bold')) return FishReaction.bold;
  return FishReaction.curious;
}

bool shouldGreetAfterAbsence({
  required DateTime lastSeenAt,
  required DateTime now,
  Duration threshold = presenceGreetingThreshold,
}) {
  return !now.isBefore(lastSeenAt) && now.difference(lastSeenAt) >= threshold;
}

/// Returns a safe destination inside the visible tank for an interaction.
Alignment reactionDestination({
  required FishReaction reaction,
  required Alignment currentPosition,
  required Alignment tapPosition,
}) {
  switch (reaction) {
    case FishReaction.curious:
      return _bounded(tapPosition);
    case FishReaction.shy:
      final awayX = currentPosition.x - tapPosition.x;
      final awayY = currentPosition.y - tapPosition.y;
      final distance = sqrt(awayX * awayX + awayY * awayY);
      if (distance < 0.08) {
        return _bounded(
          Alignment(
            currentPosition.x >= 0 ? -0.72 : 0.72,
            currentPosition.y >= 0 ? -0.52 : 0.52,
          ),
        );
      }
      return _bounded(
        Alignment(
          currentPosition.x + awayX / distance * 0.62,
          currentPosition.y + awayY / distance * 0.48,
        ),
      );
    case FishReaction.bold:
      return const Alignment(0, -0.16);
    case FishReaction.lazy:
      return currentPosition;
    case FishReaction.greeting:
      return _bounded(
        Alignment(currentPosition.x * 0.34, currentPosition.y * 0.32 - 0.12),
      );
  }
}

Alignment _bounded(Alignment value) =>
    Alignment(value.x.clamp(-0.78, 0.78), value.y.clamp(-0.72, 0.68));

class FishTapInteraction {
  const FishTapInteraction({
    required this.id,
    required this.fishId,
    required this.position,
    this.companionIds = const {},
    this.isCall = false,
    this.isFollow = false,
    this.isCompany = false,
  });

  final int id;
  final String fishId;
  final Alignment position;
  final Set<String> companionIds;
  final bool isCall;
  final bool isFollow;
  final bool isCompany;
}
