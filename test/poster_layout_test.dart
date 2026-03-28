import 'package:digital_graffiti_wall/utils/poster_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  test('poster viewport rect stays centered and portrait', () {
    final rect = posterViewportRect(const Size(1000, 1600));

    expect(rect.width, lessThan(rect.height));
    expect(rect.left, greaterThan(0));
    expect(rect.top, greaterThan(0));
  });

  test('poster normalization roundtrip is stable', () {
    final rect = posterViewportRect(const Size(1000, 1600));
    const local = Offset(500, 800);
    final normalized = posterLocalToNormalized(local, rect);
    final roundtrip = posterNormalizedToLocal(normalized, rect);

    expect((roundtrip.dx - local.dx).abs(), lessThan(0.0001));
    expect((roundtrip.dy - local.dy).abs(), lessThan(0.0001));
  });
}