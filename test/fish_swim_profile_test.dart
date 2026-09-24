import 'package:flutter_test/flutter_test.dart';
import 'package:yopet/features/home/fish_swim_profile.dart';

void main() {
  test('tank slots deliberately give fish distinct visible swim rhythms', () {
    final first = FishSwimProfile.forFish('bubble-dragon', swimSlot: 0);
    final second = FishSwimProfile.forFish('wew', swimSlot: 1);

    expect(first.routeSeed, isNot(second.routeSeed));
    expect(
      (first.initialDelay - second.initialDelay).abs(),
      greaterThanOrEqualTo(const Duration(seconds: 2)),
    );
    expect(
      (first.tempoMultiplier - second.tempoMultiplier).abs(),
      closeTo(0.2, 0.001),
    );
    expect(first.rhythm, isNot(second.rhythm));
    expect(first.horizontalCenter, isNot(second.horizontalCenter));
  });
}
