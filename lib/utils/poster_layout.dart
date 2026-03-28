import 'dart:ui';

import 'package:flutter/material.dart';

/// Default portrait ratio used for poster-mapped drawing areas.
const double kPosterAspectRatio = 0.707;

/// Returns the centered poster viewport inside the available size.
///
/// The poster area keeps a fixed aspect ratio so drawing coordinates can be
/// normalized relative to the same visual anchor on every device.
Rect posterViewportRect(Size size, {double aspectRatio = kPosterAspectRatio}) {
  if (size.width <= 0 || size.height <= 0) {
    return Rect.zero;
  }

  final paddedWidth = (size.width - 32).clamp(0.0, size.width);
  final paddedHeight = (size.height - 32).clamp(0.0, size.height);
  var width = paddedWidth;
  var height = width / aspectRatio;

  if (height > paddedHeight) {
    height = paddedHeight;
    width = height * aspectRatio;
  }

  return Rect.fromLTWH(
    (size.width - width) / 2,
    (size.height - height) / 2,
    width,
    height,
  );
}

/// Converts a local pointer position into poster-normalized coordinates.
Offset posterLocalToNormalized(Offset local, Rect posterRect) {
  if (posterRect.width <= 0 || posterRect.height <= 0) {
    return Offset.zero;
  }

  return Offset(
    ((local.dx - posterRect.left) / posterRect.width).clamp(0.0, 1.0),
    ((local.dy - posterRect.top) / posterRect.height).clamp(0.0, 1.0),
  );
}

/// Converts a poster-normalized coordinate into a local canvas position.
Offset posterNormalizedToLocal(Offset normalized, Rect posterRect) {
  return Offset(
    posterRect.left + normalized.dx * posterRect.width,
    posterRect.top + normalized.dy * posterRect.height,
  );
}

/// Returns whether the pointer is inside the current poster viewport.
bool posterContainsLocal(Offset local, Rect posterRect) => posterRect.contains(local);