const defaultFeedAmount = 25;
const satietyDecayInterval = Duration(minutes: 30);
const lowSatietyThreshold = 30;

int satietyAfterFeeding(int current, {int amount = defaultFeedAmount}) {
  return (current + amount).clamp(0, 100);
}

int decayIntervalsFor(Duration elapsed) {
  if (elapsed.isNegative) return 0;
  return elapsed.inMinutes ~/ satietyDecayInterval.inMinutes;
}

int satietyAfterElapsed(int current, Duration elapsed) {
  return (current - decayIntervalsFor(elapsed)).clamp(0, 100);
}

bool isLowSatiety(int value) => value < lowSatietyThreshold;
