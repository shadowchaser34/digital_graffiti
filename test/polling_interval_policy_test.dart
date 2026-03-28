import 'package:flutter_test/flutter_test.dart';

import 'package:digital_graffiti_wall/services/polling_interval_policy.dart';

void main() {
  group('PollingIntervalPolicy', () {
    const policy = PollingIntervalPolicy();

    test('returns 750ms when poster is unlocked', () {
      final interval = policy.intervalForState(
        isPosterLocked: false,
        stableLockedCycles: 999,
      );

      expect(interval, PollingIntervalPolicy.unlockedInterval);
      expect(interval, const Duration(milliseconds: 750));
    });

    test('returns 1200ms when locked but not yet stable', () {
      final interval = policy.intervalForState(
        isPosterLocked: true,
        stableLockedCycles: PollingIntervalPolicy.stableLockedCyclesRequired - 1,
      );

      expect(interval, PollingIntervalPolicy.lockedBaselineInterval);
      expect(interval, const Duration(milliseconds: 1200));
    });

    test('returns 1800ms after 5 stable locked cycles', () {
      final atThreshold = policy.intervalForState(
        isPosterLocked: true,
        stableLockedCycles: PollingIntervalPolicy.stableLockedCyclesRequired,
      );
      final aboveThreshold = policy.intervalForState(
        isPosterLocked: true,
        stableLockedCycles: PollingIntervalPolicy.stableLockedCyclesRequired + 2,
      );

      expect(atThreshold, PollingIntervalPolicy.stableLockedInterval);
      expect(aboveThreshold, PollingIntervalPolicy.stableLockedInterval);
      expect(atThreshold, const Duration(milliseconds: 1800));
    });
  });
}