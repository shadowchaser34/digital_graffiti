import 'poster_catalog.dart';

/// Represents a placed sticker on the shared canvas.
///
/// `x` and `y` are normalized (0..1) coordinates relative to the poster view.
class StickerModel {
  final String id;
  final String userId;
  final String posterId;
  final String imageUrl; // PNG URL or asset path
  final double x;
  final double y;
  final double scale;
  final double rotation;
  final int timestamp;

  StickerModel({
    required this.id,
    required this.userId,
    this.posterId = defaultPosterId,
    required this.imageUrl,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'posterId': posterId,
        'imageUrl': imageUrl,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'timestamp': timestamp,
      };

  factory StickerModel.fromMap(Map<String, dynamic> m) => StickerModel(
        id: m['id'] as String,
        userId: m['userId'] as String,
      posterId: (m['posterId'] as String?) ?? defaultPosterId,
        imageUrl: m['imageUrl'] as String,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        scale: (m['scale'] as num).toDouble(),
        rotation: (m['rotation'] as num).toDouble(),
        timestamp: (m['timestamp'] as int),
      );
}
