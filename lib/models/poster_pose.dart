import 'package:flutter/material.dart';
import 'poster_catalog.dart';

class PosterPose {
  final String posterId;
  final List<Offset> corners;
  final double confidence;

  const PosterPose({
    required this.posterId,
    required this.corners,
    required this.confidence,
  });

  bool get isValid => corners.length == 4 && corners.every((corner) => corner.dx.isFinite && corner.dy.isFinite);

  Map<String, dynamic> toMap() => {
        'posterId': posterId,
        'corners': corners.map((corner) => {'x': corner.dx, 'y': corner.dy}).toList(),
        'confidence': confidence,
      };

  factory PosterPose.fromMap(Map<String, dynamic> map) {
    final corners = <Offset>[];
    final rawCorners = map['corners'];
    if (rawCorners is Iterable) {
      for (final rawCorner in rawCorners) {
        if (rawCorner is Map) {
          corners.add(Offset((rawCorner['x'] as num).toDouble(), (rawCorner['y'] as num).toDouble()));
        } else if (rawCorner is List && rawCorner.length >= 2) {
          corners.add(Offset((rawCorner[0] as num).toDouble(), (rawCorner[1] as num).toDouble()));
        }
      }
    }

    return PosterPose(
      posterId: (map['posterId'] as String?) ?? defaultPosterId,
      corners: corners,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}