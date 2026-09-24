import 'package:flutter/animation.dart';

enum FishSwimRhythm { slowMeander, cruisingArc, curiousScout }

/// A deterministic-but-distinct rhythm for each fish. The stable seed keeps a
/// fish recognisable across rebuilds. The stable tank slot deliberately gives
/// a small school different phases, routes and speeds rather than allowing
/// close hash values to make them move in lockstep.
class FishSwimProfile {
  const FishSwimProfile._({
    required this.routeSeed,
    required this.initialDelay,
    required this.tempoMultiplier,
    required this.curve,
    required this.rhythm,
    required this.horizontalCenter,
    required this.horizontalSpan,
    required this.verticalBias,
  });

  final int routeSeed;
  final Duration initialDelay;
  final double tempoMultiplier;
  final Curve curve;
  final FishSwimRhythm rhythm;
  final double horizontalCenter;
  final double horizontalSpan;
  final double verticalBias;

  factory FishSwimProfile.forFish(String fishId, {required int swimSlot}) {
    final slot = swimSlot % FishSwimRhythm.values.length;
    final seed = _stableSeed('$fishId:$slot');
    final rhythm = FishSwimRhythm.values[slot];
    final initialDelay = switch (rhythm) {
      FishSwimRhythm.slowMeander => 450,
      FishSwimRhythm.cruisingArc => 3000,
      FishSwimRhythm.curiousScout => 5550,
    };
    return FishSwimProfile._(
      routeSeed: seed,
      initialDelay: Duration(milliseconds: initialDelay + seed % 450),
      tempoMultiplier: switch (rhythm) {
        FishSwimRhythm.slowMeander => 0.78,
        FishSwimRhythm.cruisingArc => 0.98,
        FishSwimRhythm.curiousScout => 1.16,
      },
      curve: switch (rhythm) {
        FishSwimRhythm.slowMeander => Curves.easeInOutSine,
        FishSwimRhythm.cruisingArc => Curves.easeInOutCubic,
        FishSwimRhythm.curiousScout => Curves.fastOutSlowIn,
      },
      rhythm: rhythm,
      horizontalCenter: switch (rhythm) {
        FishSwimRhythm.slowMeander => -0.24,
        FishSwimRhythm.cruisingArc => 0.2,
        FishSwimRhythm.curiousScout => 0,
      },
      horizontalSpan: switch (rhythm) {
        FishSwimRhythm.slowMeander => 0.96,
        FishSwimRhythm.cruisingArc => 1.14,
        FishSwimRhythm.curiousScout => 1.48,
      },
      verticalBias: switch (rhythm) {
        FishSwimRhythm.slowMeander => 0.16,
        FishSwimRhythm.cruisingArc => -0.12,
        FishSwimRhythm.curiousScout => 0,
      },
    );
  }

  static int _stableSeed(String value) {
    var result = 17;
    for (final unit in value.codeUnits) {
      result = 37 * result + unit;
    }
    return result & 0x7fffffff;
  }
}
