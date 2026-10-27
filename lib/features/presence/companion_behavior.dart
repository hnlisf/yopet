import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'personality_profile.dart';

/// Current-session personality expression; no affection score or history.
class CompanionBehavior {
  CompanionBehavior(Iterable<String> traits) : codes = traits.toSet();
  final Set<String> codes;
  PersonalityProfile? get profile => PersonalityProfile.fromLegacy(codes);
  bool get enthusiastic => profile == PersonalityProfile.presets[0];
  bool get gentle => profile == PersonalityProfile.presets[1];
  bool get cautious => profile == PersonalityProfile.presets[2];
  bool get quiet => profile == PersonalityProfile.presets[3];
  double get finTempo => quiet
      ? .65
      : gentle
      ? .78
      : cautious
      ? 1.0
      : enthusiastic
      ? 1.25
      : 1.0;
  double get finPower => quiet
      ? .48
      : gentle
      ? .65
      : cautious
      ? .82
      : 1.0;
  double get steering => gentle
      ? .55
      : quiet
      ? .65
      : cautious
      ? .85
      : .95;
  double get bodySway => quiet
      ? .002
      : gentle
      ? .003
      : cautious
      ? .004
      : .006;
  int get routeSeconds => quiet
      ? 12
      : gentle
      ? 14
      : cautious
      ? 9
      : 10;
  double get routineRestSeconds => quiet
      ? 7
      : gentle
      ? 2.5
      : cautious
      ? 3.2
      : enthusiastic
      ? .5
      : rest.inMilliseconds / 1000;
  bool get shy => codes.contains('shy');
  bool get lazy => codes.contains('lazy');
  bool get curious => codes.contains('curious');
  bool get followsPointer =>
      profile?.social != SocialStyle.independent &&
      (curious || codes.contains('bold'));
  double speedFor({required bool lowSatiety, bool responding = false}) =>
      speed * (lowSatiety ? (responding ? .75 : .55) : 1);
  double get speed => profile != null
      ? (enthusiastic
            ? 1.30
            : cautious
            ? 1.08
            : gentle
            ? .70
            : .48)
      : lazy
      ? .58
      : shy
      ? .80
      : codes.contains('bold')
      ? 1.18
      : 1;
  Duration get attentionDelay => Duration(
    milliseconds: profile?.social == SocialStyle.slowWarm
        ? 1200
        : lazy
        ? 1100
        : shy
        ? 700
        : 250,
  );

  Duration feedingDelay(int slot) =>
      attentionDelay + Duration(milliseconds: slot * 240);

  Duration greetingDelay(int slot) =>
      attentionDelay + Duration(milliseconds: slot * 420);

  Alignment greetingDestination(Alignment current, int slot) {
    // A small individual acknowledgement, not a rush to the tank centre.
    final travel = lazy
        ? .035
        : shy
        ? .065
        : .16;
    return Alignment(
      (current.x + (slot.isEven ? travel : -travel)).clamp(-.78, .78),
      (current.y - travel * .4).clamp(-.72, .68),
    );
  }

  Alignment feedingDestination(int slot) {
    // Separate portions across the middle water column, not one shared point.
    return Alignment(-.56 + (slot % 5) * .28, shy ? .12 : -.12);
  }

  Duration get dwell => Duration(
    milliseconds: lazy
        ? 3200
        : curious
        ? 2400
        : 1800,
  );
  Duration get rest => Duration(
    milliseconds: lazy
        ? 4000
        : curious
        ? 1400
        : shy
        ? 2200
        : 500,
  );

  Alignment routeDestination(Alignment candidate, Alignment home) {
    if (quiet) {
      return Alignment(
        (home.x + (candidate.x - home.x) * .16).clamp(-.78, .78),
        (home.y + (candidate.y - home.y) * .16).clamp(-.72, .68),
      );
    }
    if (cautious) {
      return Alignment(
        (home.x + (candidate.x - home.x) * .65).clamp(-.78, .78),
        candidate.y,
      );
    }
    if (profile?.exploration != ExplorationStyle.familiar) return candidate;
    return Alignment(
      (home.x + (candidate.x - home.x) * .35).clamp(-.78, .78),
      (home.y + (candidate.y - home.y) * .35).clamp(-.72, .68),
    );
  }

  Alignment approach(Alignment current, Alignment call, int slot) {
    if (profile?.social == SocialStyle.independent) {
      // A restrained acknowledgement near its own spot, not silence.
      return greetingDestination(current, slot);
    }
    // Stand off rather than converge on a single point; shy/curious mixes
    // investigate while preserving distance, lazy fish only come part way.
    final dx = current.x - call.x;
    final dy = current.y - call.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final gap = shy ? .30 : .12;
    final x = distance < .01 ? (slot.isEven ? -1.0 : 1.0) : dx / distance;
    final y = distance < .01 ? 0.0 : dy / distance;
    var destination = Alignment(
      call.x + x * gap,
      call.y + y * gap + (slot.isEven ? -.07 : .07),
    );
    if (lazy) {
      destination = Alignment(
        current.x + (destination.x - current.x) * .35,
        current.y + (destination.y - current.y) * .35,
      );
    }
    return Alignment(
      destination.x.clamp(-.78, .78),
      destination.y.clamp(-.72, .68),
    );
  }

  Alignment? approachWaypoint(
    Alignment current,
    Alignment destination,
    int slot,
  ) {
    if (profile?.social != SocialStyle.slowWarm) return null;
    final dx = destination.x - current.x;
    final dy = destination.y - current.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < .18) return null;
    final side = slot.isEven ? 1.0 : -1.0;
    final bend = math.min(.22, distance * .3);
    return Alignment(
      ((current.x + destination.x) / 2 - dy / distance * bend * side).clamp(
        -.78,
        .78,
      ),
      ((current.y + destination.y) / 2 + dx / distance * bend * side).clamp(
        -.72,
        .68,
      ),
    );
  }
}

/// Keeps a short turn stable, then gives the least recently chosen nearby fish
/// a turn. Distance breaks ties only, so approaching does not monopolise input.
class CompanionFollowSelector {
  final Map<String, DateTime> _chosen = {};
  String? _current;
  DateTime? _started;

  String? select(List<String> nearestFirst, DateTime now) {
    if (nearestFirst.isEmpty) {
      _current = null;
      return null;
    }
    if (nearestFirst.contains(_current) &&
        _started != null &&
        now.difference(_started!) < const Duration(seconds: 4)) {
      return _current;
    }
    var selected = nearestFirst.first;
    for (final id in nearestFirst.skip(1)) {
      final candidateTime = _chosen[id];
      final selectedTime = _chosen[selected];
      if (selectedTime != null &&
          (candidateTime == null || candidateTime.isBefore(selectedTime))) {
        selected = id;
      }
    }
    _current = selected;
    _started = now;
    _chosen[selected] = now;
    return selected;
  }
}
