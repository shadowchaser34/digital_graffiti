import 'poster_catalog.dart';

/// Presence describes a user's pointer position and drawing state on the canvas.
///
/// `x`/`y` are normalized coordinates (0..1) relative to the poster view.
/// `isDrawing` indicates whether the user currently has an active stroke.
class Presence {
  final String userId;
  final String posterId;
  final double x;
  final double y;
  final bool isDrawing;
  final int colorValue;
  final int lastActive;

  Presence({
    required this.userId,
    this.posterId = defaultPosterId,
    required this.x,
    required this.y,
    required this.isDrawing,
    required this.colorValue,
    required this.lastActive,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
      'posterId': posterId,
        'x': x,
        'y': y,
        'isDrawing': isDrawing,
        'colorValue': colorValue,
        'lastActive': lastActive,
      };

  factory Presence.fromMap(Map<String, dynamic> m) => Presence(
        userId: m['userId'] as String,
      posterId: (m['posterId'] as String?) ?? defaultPosterId,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        isDrawing: m['isDrawing'] as bool,
        colorValue: (m['colorValue'] as int),
        lastActive: (m['lastActive'] as int),
      );
}
