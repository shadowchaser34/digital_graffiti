class PollingIntervalPolicy {
  static const Duration unlockedInterval = Duration(milliseconds: 750);
  static const Duration lockedBaselineInterval = Duration(milliseconds: 1200);
  static const Duration stableLockedInterval = Duration(milliseconds: 1800);
  static const int stableLockedCyclesRequired = 5;

  const PollingIntervalPolicy();

  Duration intervalForState({
    required bool isPosterLocked,
    required int stableLockedCycles,
  }) {
    if (!isPosterLocked) {
      return unlockedInterval;
    }

    if (stableLockedCycles >= stableLockedCyclesRequired) {
      return stableLockedInterval;
    }

    return lockedBaselineInterval;
  }
}