import '../models/poster_pose.dart';

class PosterLockDecision {
  final PosterPose? nextPose;
  final bool clearPose;

  const PosterLockDecision._({required this.nextPose, required this.clearPose});

  const PosterLockDecision.noChange() : this._(nextPose: null, clearPose: false);

  const PosterLockDecision.apply(PosterPose pose) : this._(nextPose: pose, clearPose: false);

  const PosterLockDecision.clear() : this._(nextPose: null, clearPose: true);

  bool get shouldChange => clearPose || nextPose != null;
}

class PosterLockStabilizer {
  final int requiredConsecutiveLocks;
  final int requiredConsecutiveSwitches;
  final int requiredMissesToUnlock;
  final double lockAcquireConfidenceThreshold;
  final double lockKeepConfidenceThreshold;

  int _missedDetections = 0;
  int _consecutivePosterDetections = 0;
  String? _pendingPosterId;
  int _consecutiveSwitchDetections = 0;
  String? _pendingSwitchPosterId;

  PosterLockStabilizer({
    this.requiredConsecutiveLocks = 3,
    this.requiredConsecutiveSwitches = 3,
    this.requiredMissesToUnlock = 3,
    this.lockAcquireConfidenceThreshold = 0.70,
    this.lockKeepConfidenceThreshold = 0.58,
  });

  void _resetAcquireCandidate() {
    _consecutivePosterDetections = 0;
    _pendingPosterId = null;
  }

  void _resetSwitchCandidate() {
    _consecutiveSwitchDetections = 0;
    _pendingSwitchPosterId = null;
  }

  void reset() {
    _missedDetections = 0;
    _resetAcquireCandidate();
    _resetSwitchCandidate();
  }

  PosterLockDecision processDetection({
    required PosterPose? detectedPose,
    required PosterPose? activePose,
  }) {
    if (detectedPose == null) {
      _missedDetections += 1;
      _resetAcquireCandidate();
      _resetSwitchCandidate();
      if (_missedDetections >= requiredMissesToUnlock) {
        return const PosterLockDecision.clear();
      }
      return const PosterLockDecision.noChange();
    }

    _missedDetections = 0;
    final isLocked = activePose != null && activePose.isValid;
    final lockedPosterId = isLocked ? activePose.posterId : null;

    if (!isLocked) {
      _resetSwitchCandidate();
      if (detectedPose.confidence < lockAcquireConfidenceThreshold) {
        _resetAcquireCandidate();
        return const PosterLockDecision.noChange();
      }

      if (_pendingPosterId == detectedPose.posterId) {
        _consecutivePosterDetections += 1;
      } else {
        _pendingPosterId = detectedPose.posterId;
        _consecutivePosterDetections = 1;
      }

      if (_consecutivePosterDetections < requiredConsecutiveLocks) {
        return const PosterLockDecision.noChange();
      }

      _resetAcquireCandidate();
      return PosterLockDecision.apply(detectedPose);
    }

    if (detectedPose.posterId == lockedPosterId) {
      _resetAcquireCandidate();
      _resetSwitchCandidate();
      if (detectedPose.confidence >= lockKeepConfidenceThreshold) {
        return PosterLockDecision.apply(detectedPose);
      }
      return const PosterLockDecision.noChange();
    }

    _resetAcquireCandidate();
    if (detectedPose.confidence < lockAcquireConfidenceThreshold) {
      _resetSwitchCandidate();
      return const PosterLockDecision.noChange();
    }

    if (_pendingSwitchPosterId == detectedPose.posterId) {
      _consecutiveSwitchDetections += 1;
    } else {
      _pendingSwitchPosterId = detectedPose.posterId;
      _consecutiveSwitchDetections = 1;
    }

    if (_consecutiveSwitchDetections < requiredConsecutiveSwitches) {
      return const PosterLockDecision.noChange();
    }

    _resetSwitchCandidate();
    return PosterLockDecision.apply(detectedPose);
  }
}