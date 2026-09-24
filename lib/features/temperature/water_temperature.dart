const minWaterTemperature = 18;
const maxWaterTemperature = 30;
const defaultWaterTemperature = 24;

/// A calm, descriptive cue for a fish's preferred water range.
///
/// It is deliberately not a health or punishment system: it only helps the
/// aquarium choose a slightly different swimming pace and gentle UI copy.
enum WaterTemperatureComfort {
  comfortable,
  slightlyCool,
  slightlyWarm,
  cool,
  warm;

  String get labelZh => switch (this) {
    WaterTemperatureComfort.comfortable => '舒适',
    WaterTemperatureComfort.slightlyCool => '稍凉',
    WaterTemperatureComfort.slightlyWarm => '稍暖',
    WaterTemperatureComfort.cool => '偏凉',
    WaterTemperatureComfort.warm => '偏暖',
  };

  String get descriptionZh => switch (this) {
    WaterTemperatureComfort.comfortable => '游得自在',
    WaterTemperatureComfort.slightlyCool => '慢一点也很安静',
    WaterTemperatureComfort.slightlyWarm => '慢一点也很安静',
    WaterTemperatureComfort.cool => '喜欢慢慢游',
    WaterTemperatureComfort.warm => '喜欢慢慢游',
  };

  /// A small motion adjustment only. Feeding, growth, and fish wellbeing are
  /// never reduced by this value.
  double get activityMultiplier => switch (this) {
    WaterTemperatureComfort.comfortable => 1.05,
    WaterTemperatureComfort.slightlyCool ||
    WaterTemperatureComfort.slightlyWarm => 0.92,
    WaterTemperatureComfort.cool || WaterTemperatureComfort.warm => 0.80,
  };
}

bool isSupportedWaterTemperature(int temperature) =>
    temperature >= minWaterTemperature && temperature <= maxWaterTemperature;

WaterTemperatureComfort comfortForWaterTemperature({
  required int temperature,
  required int preferredMin,
  required int preferredMax,
}) {
  if (temperature < preferredMin) {
    return preferredMin - temperature <= 2
        ? WaterTemperatureComfort.slightlyCool
        : WaterTemperatureComfort.cool;
  }
  if (temperature > preferredMax) {
    return temperature - preferredMax <= 2
        ? WaterTemperatureComfort.slightlyWarm
        : WaterTemperatureComfort.warm;
  }
  return WaterTemperatureComfort.comfortable;
}
