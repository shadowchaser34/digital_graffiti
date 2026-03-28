import 'package:flutter_test/flutter_test.dart';

import 'package:digital_graffiti_wall/models/poster_pose.dart';
import 'package:digital_graffiti_wall/services/poster_lock_stabilizer.dart';

PosterPose _pose(String id, double confidence) {
  return PosterPose(
    posterId: id,
    confidence: confidence,
    corners: const [
      Offset(100, 100),
      Offset(900, 100),
      Offset(900, 1400),
      Offset(100, 1400),
    ],
  );
}

void main() {
  test('acquires lock only after 3 consecutive strong detections', () {
    final stabilizer = PosterLockStabilizer();

    var decision = stabilizer.processDetection(detectedPose: _pose('a', 0.85), activePose: null);
    expect(decision.shouldChange, isFalse);

    decision = stabilizer.processDetection(detectedPose: _pose('a', 0.84), activePose: null);
    expect(decision.shouldChange, isFalse);

    decision = stabilizer.processDetection(detectedPose: _pose('a', 0.83), activePose: null);
    expect(decision.shouldChange, isTrue);
    expect(decision.clearPose, isFalse);
    expect(decision.nextPose?.posterId, 'a');
  });

  test('does not acquire lock on low-confidence detections', () {
    final stabilizer = PosterLockStabilizer();

    final d1 = stabilizer.processDetection(detectedPose: _pose('a', 0.55), activePose: null);
    final d2 = stabilizer.processDetection(detectedPose: _pose('a', 0.56), activePose: null);
    final d3 = stabilizer.processDetection(detectedPose: _pose('a', 0.57), activePose: null);

    expect(d1.shouldChange, isFalse);
    expect(d2.shouldChange, isFalse);
    expect(d3.shouldChange, isFalse);
  });

  test('updates locked pose only if keep-threshold is met', () {
    final stabilizer = PosterLockStabilizer();
    final locked = _pose('a', 0.90);

    final low = stabilizer.processDetection(
      detectedPose: _pose('a', 0.50),
      activePose: locked,
    );
    expect(low.shouldChange, isFalse);

    final good = stabilizer.processDetection(
      detectedPose: _pose('a', 0.65),
      activePose: locked,
    );
    expect(good.shouldChange, isTrue);
    expect(good.nextPose?.posterId, 'a');
  });

  test('switches to new poster only after 3 strong consecutive detections', () {
    final stabilizer = PosterLockStabilizer();
    final locked = _pose('a', 0.90);

    var decision = stabilizer.processDetection(detectedPose: _pose('b', 0.82), activePose: locked);
    expect(decision.shouldChange, isFalse);

    decision = stabilizer.processDetection(detectedPose: _pose('b', 0.83), activePose: locked);
    expect(decision.shouldChange, isFalse);

    decision = stabilizer.processDetection(detectedPose: _pose('b', 0.84), activePose: locked);
    expect(decision.shouldChange, isTrue);
    expect(decision.nextPose?.posterId, 'b');
  });

  test('clears lock after 3 consecutive misses', () {
    final stabilizer = PosterLockStabilizer();
    final locked = _pose('a', 0.90);

    final d1 = stabilizer.processDetection(detectedPose: null, activePose: locked);
    final d2 = stabilizer.processDetection(detectedPose: null, activePose: locked);
    final d3 = stabilizer.processDetection(detectedPose: null, activePose: locked);

    expect(d1.clearPose, isFalse);
    expect(d2.clearPose, isFalse);
    expect(d3.clearPose, isTrue);
  });
}