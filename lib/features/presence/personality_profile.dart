enum SocialStyle { close, slowWarm, independent }

enum ActivityStyle { lively, relaxed }

enum ExplorationStyle { explorer, familiar }

/// Phase-one presets. Legacy codes are a storage adapter, not extra traits.
class PersonalityProfile {
  const PersonalityProfile(
    this.name,
    this.summary,
    this.social,
    this.activity,
    this.exploration,
    this.legacyCodes,
  );
  final String name;
  final String summary;
  final SocialStyle social;
  final ActivityStyle activity;
  final ExplorationStyle exploration;
  final Set<String> legacyCodes;
  String get code => ['enthusiastic', 'gentle', 'cautious', 'quiet'][presets.indexOf(this)];

  static const presets = [
    PersonalityProfile(
      '热情小伙伴',
      '亲近 · 活泼 · 爱探索',
      SocialStyle.close,
      ActivityStyle.lively,
      ExplorationStyle.explorer,
      {'bold', 'curious'},
    ),
    PersonalityProfile(
      '温柔陪伴者',
      '亲近 · 悠闲 · 恋旧',
      SocialStyle.close,
      ActivityStyle.relaxed,
      ExplorationStyle.familiar,
      {'bold', 'lazy'},
    ),
    PersonalityProfile(
      '谨慎探险家',
      '慢热 · 活泼 · 爱探索',
      SocialStyle.slowWarm,
      ActivityStyle.lively,
      ExplorationStyle.explorer,
      {'shy', 'curious'},
    ),
    PersonalityProfile(
      '安静守望者',
      '独立 · 悠闲 · 恋旧',
      SocialStyle.independent,
      ActivityStyle.relaxed,
      ExplorationStyle.familiar,
      {'shy', 'lazy'},
    ),
  ];

  static PersonalityProfile? fromLegacy(Set<String> codes) {
    for (final preset in presets) {
      if (codes.length == preset.legacyCodes.length &&
          codes.containsAll(preset.legacyCodes)) {
        return preset;
      }
    }
    return null;
  }

  static PersonalityProfile? fromCode(String? code) {
    for (final profile in presets) {
      if (profile.code == code) return profile;
    }
    return null;
  }
}
