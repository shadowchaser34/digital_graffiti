import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_graffiti_wall/models/poster_pose.dart';
import 'package:digital_graffiti_wall/utils/poster_geometry.dart';

void main() {
  test('poster viewport rect stays centered and portrait', () {
    const size = Size(1000, 1600);
    final rect = PosterGeometry.fallbackRect(size);

    expect(rect.center.dx, closeTo(size.width / 2, 0.001));
    expect(rect.center.dy, closeTo(size.height / 2, 0.001));
    expect(rect.width, closeTo(size.width * 0.82, 0.001));
    expect(rect.height, closeTo(size.height * 0.82, 0.001));
  });

  test('poster normalization roundtrip is stable', () {
    const size = Size(1200, 1800);
    final pose = PosterPose(
      posterId: 'poster-1',
      confidence: 0.95,
      corners: const [
        Offset(250, 320),
        Offset(950, 280),
        Offset(970, 1460),
        Offset(220, 1500),
      ],
    );

    const localPoint = Offset(0.35, 0.72);
    final screenPoint = PosterGeometry.localToScreen(localPoint, pose, size);
    final roundTrip = PosterGeometry.screenToLocal(screenPoint, pose, size);

    expect(roundTrip, isNotNull);
    expect(roundTrip!.dx, closeTo(localPoint.dx, 0.01));
    expect(roundTrip.dy, closeTo(localPoint.dy, 0.01));
  });
}