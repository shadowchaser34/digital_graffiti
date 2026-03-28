import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/brush_type.dart';
import '../models/stroke.dart';
import '../models/sticker_model.dart';
import '../providers/auth_provider.dart';
import '../providers/brush_provider.dart';
import '../providers/canvas_provider.dart';
import '../providers/poster_provider.dart';
import '../providers/sticker_provider.dart';
import '../utils/poster_layout.dart';

class CanvasWidget extends ConsumerStatefulWidget {
  const CanvasWidget({super.key});

  @override
  ConsumerState<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends ConsumerState<CanvasWidget> {
  List<Offset> _currentPoints = [];

  void _start(Offset point, Rect posterRect) {
    if (!posterContainsLocal(point, posterRect)) {
      return;
    }

    final poster = ref.read(activePosterProvider);
    final normalized = posterLocalToNormalized(point, posterRect);
    final auth = ref.read(authInfoProvider);

    setState(() {
      _currentPoints = [normalized];
    });

    if (auth != null) {
      ref.read(canvasProvider(poster.id).notifier).setPresence(
            normalized.dx,
            normalized.dy,
            true,
            auth.colorValue,
          );
    }
  }

  void _update(Offset point, Rect posterRect) {
    if (!posterContainsLocal(point, posterRect) || _currentPoints.isEmpty) {
      return;
    }

    final poster = ref.read(activePosterProvider);
    final normalized = posterLocalToNormalized(point, posterRect);
    final auth = ref.read(authInfoProvider);

    setState(() {
      _currentPoints.add(normalized);
    });

    if (auth != null) {
      ref.read(canvasProvider(poster.id).notifier).setPresence(
            normalized.dx,
            normalized.dy,
            true,
            auth.colorValue,
          );
    }
  }

  Future<void> _end() async {
    if (_currentPoints.isEmpty) {
      return;
    }

    final poster = ref.read(activePosterProvider);
    final svc = ref.read(firebaseServiceProvider);
    final auth = ref.read(authInfoProvider);
    if (auth == null) {
      setState(() {
        _currentPoints = [];
      });
      return;
    }

    final brush = ref.read(brushSettingsProvider);
    final stroke = Stroke(
      id: svc.generateId(),
      userId: auth.uid,
      posterId: poster.id,
      points: List<Offset>.from(_currentPoints),
      color: brush.color,
      thickness: brush.thickness,
      brushType: BrushType.pen,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await ref.read(canvasProvider(poster.id).notifier).addStrokeLocalAndRemote(stroke);
    ref.read(canvasProvider(poster.id).notifier).setPresence(0.5, 0.5, false, auth.colorValue);

    if (!mounted) {
      return;
    }
    setState(() {
      _currentPoints = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final poster = ref.watch(activePosterProvider);
    final canvasState = ref.watch(canvasProvider(poster.id));
    final brush = ref.watch(brushSettingsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final posterRect = posterViewportRect(size);
        final isPortrait = posterRect.height > posterRect.width;
        final posterLabel = '${poster.name} · ${isPortrait ? 'Portrait canvas' : 'Canvas'}';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) async {
            final isPlacing = ref.read(isPlacingStickerProvider);
            final selected = ref.read(selectedStickerProvider);
            if (isPlacing && selected != null && posterContainsLocal(details.localPosition, posterRect)) {
              final svc = ref.read(firebaseServiceProvider);
              final auth = ref.read(authInfoProvider);
              if (auth != null) {
                final normalized = posterLocalToNormalized(details.localPosition, posterRect);
                final sticker = StickerModel(
                  id: svc.generateId(),
                  userId: auth.uid,
                  posterId: poster.id,
                  imageUrl: selected,
                  x: normalized.dx,
                  y: normalized.dy,
                  scale: 1.0,
                  rotation: 0.0,
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                );
                await ref.read(canvasProvider(poster.id).notifier).addSticker(sticker);
                ref.read(isPlacingStickerProvider.notifier).state = false;
                ref.read(selectedStickerProvider.notifier).state = null;
              }
            }
          },
          onPanStart: (details) => _start(details.localPosition, posterRect),
          onPanUpdate: (details) => _update(details.localPosition, posterRect),
          onPanEnd: (_) => unawaited(_end()),
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GraffitiPainter(
                      strokes: canvasState.strokes,
                      currentPoints: _currentPoints,
                      posterRect: posterRect,
                      brushColor: brush.color,
                      brushThickness: brush.thickness,
                    ),
                  ),
                ),
                ...canvasState.stickers.map((sticker) {
                  final center = posterNormalizedToLocal(Offset(sticker.x, sticker.y), posterRect);
                  final left = center.dx - (32 * sticker.scale);
                  final top = center.dy - (32 * sticker.scale);
                  return Positioned(
                    left: left.clamp(posterRect.left, posterRect.right - 8.0),
                    top: top.clamp(posterRect.top, posterRect.bottom - 8.0),
                    child: Transform.rotate(
                      angle: sticker.rotation,
                      child: Image.network(
                        sticker.imageUrl,
                        width: 64 * sticker.scale,
                        height: 64 * sticker.scale,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 64 * sticker.scale,
                          height: 64 * sticker.scale,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  );
                }),
                Positioned(
                  left: posterRect.left,
                  top: posterRect.top - 28,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      posterLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: brush.color.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Text(
                      '${brush.thickness.toStringAsFixed(1)} px',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GraffitiPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset> currentPoints;
  final Rect posterRect;
  final Color brushColor;
  final double brushThickness;

  _GraffitiPainter({
    required this.strokes,
    required this.currentPoints,
    required this.posterRect,
    required this.brushColor,
    required this.brushThickness,
  });

  Paint _paintForStroke(Stroke stroke) {
    switch (stroke.brushType) {
      case BrushType.marker:
        return Paint()
          ..color = stroke.color.withOpacity(0.68)
          ..strokeWidth = stroke.thickness * 1.35
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
      case BrushType.calligraphy:
        return Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.thickness * 1.2
          ..strokeCap = StrokeCap.square
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
      case BrushType.neon:
        return Paint()
          ..color = stroke.color.withOpacity(0.82)
          ..strokeWidth = stroke.thickness * 1.6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..isAntiAlias = true;
      case BrushType.pen:
        return Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.thickness
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
    }
  }

  void _drawStroke(Canvas canvas, Size size, List<Offset> points, Paint paint) {
    if (points.length < 2) {
      return;
    }

    final path = Path();
    path.moveTo(
      posterRect.left + points.first.dx * posterRect.width,
      posterRect.top + points.first.dy * posterRect.height,
    );
    for (var i = 1; i < points.length; i++) {
      path.lineTo(
        posterRect.left + points[i].dx * posterRect.width,
        posterRect.top + points[i].dy * posterRect.height,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.4;

    canvas.drawRRect(
      RRect.fromRectAndRadius(posterRect, const Radius.circular(16)),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(posterRect, const Radius.circular(16)),
      framePaint,
    );

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(posterRect, const Radius.circular(16)));

    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke.points, _paintForStroke(stroke));
    }

    if (currentPoints.isNotEmpty) {
      final paint = Paint()
        ..color = brushColor
        ..strokeWidth = brushThickness
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      _drawStroke(canvas, size, currentPoints, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GraffitiPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentPoints != currentPoints ||
        oldDelegate.posterRect != posterRect ||
        oldDelegate.brushColor != brushColor ||
        oldDelegate.brushThickness != brushThickness;
  }
}
