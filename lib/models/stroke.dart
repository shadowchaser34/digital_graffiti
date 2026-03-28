import 'package:flutter/material.dart';
import 'brush_type.dart';
import 'poster_catalog.dart';

/// Stroke represents a single freehand path drawn by a user.
///
/// Stored as vector data: a list of `Offset` points plus color and thickness.
/// Points are normalized relative to the active poster viewport so the stroke
/// can be replayed at the same location on every device.
class Stroke {
  final String id;
  final String userId;
  final String posterId;
  final List<Offset> points;
  final Color color;
  final double thickness;
  final BrushType brushType;
  final int timestamp;

  Stroke({
    required this.id,
    required this.userId,
    this.posterId = defaultPosterId,
    required this.points,
    required this.color,
    required this.thickness,
    required this.brushType,
    required this.timestamp,
  });

  /// Serializes the stroke for Firestore storage.
  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'posterId': posterId,
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': color.value,
        'thickness': thickness,
        'brushType': brushType.id,
        'timestamp': timestamp,
      };

  /// Deserializes a Firestore document into a [Stroke].
  factory Stroke.fromMap(Map<String, dynamic> m) {
    final pts = <Offset>[];
    if (m['points'] is Iterable) {
      for (final p in m['points']) {
        final dx = (p['x'] as num).toDouble();
        final dy = (p['y'] as num).toDouble();
        pts.add(Offset(dx, dy));
      }
    }
    return Stroke(
      id: m['id'] as String,
      userId: m['userId'] as String,
      posterId: (m['posterId'] as String?) ?? defaultPosterId,
      points: pts,
      color: Color((m['color'] as int)),
      thickness: (m['thickness'] as num).toDouble(),
      brushType: brushTypeFromId(m['brushType'] as String?),
      timestamp: (m['timestamp'] as int),
    );
  }
}
