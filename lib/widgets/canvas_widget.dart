import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../models/sticker_model.dart';
import '../providers/canvas_provider.dart';
import '../providers/brush_provider.dart';
import '../providers/sticker_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/poster_provider.dart';
import '../utils/poster_layout.dart';

class CanvasWidget extends ConsumerStatefulWidget {
  const CanvasWidget({super.key});

  @override
  ConsumerState<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends ConsumerState<CanvasWidget> {
  List<Offset> _currentPoints = [];

  void _start(Offset pt, Rect posterRect) {
    if (!posterContainsLocal(pt, posterRect)) {
      return;
    }

    final poster = ref.read(activePosterProvider);
    setState(() {
      _currentPoints = [posterLocalToNormalized(pt, posterRect)];
    });
    final normalized = posterLocalToNormalized(pt, posterRect);
    final auth = ref.read(authInfoProvider)!;
    ref.read(canvasProvider(poster.id).notifier).setPresence(normalized.dx, normalized.dy, true, auth.colorValue);
  }

  void _update(Offset pt, Rect posterRect) {
    if (!posterContainsLocal(pt, posterRect) || _currentPoints.isEmpty) {
      return;
    }

    final poster = ref.read(activePosterProvider);
    setState(() {
      _currentPoints.add(posterLocalToNormalized(pt, posterRect));
    });
    final normalized = posterLocalToNormalized(pt, posterRect);
    final auth = ref.read(authInfoProvider)!;
    ref.read(canvasProvider(poster.id).notifier).setPresence(normalized.dx, normalized.dy, true, auth.colorValue);
  }

  void _end(Rect posterRect) async {
    final poster = ref.read(activePosterProvider);
    final svc = ref.read(firebaseServiceProvider);
    final auth = ref.read(authInfoProvider)!;
    final brush = ref.read(brushSettingsProvider);
    final id = svc.generateId();
    final stroke = Stroke(
      id: id,
      userId: auth.uid,
      posterId: poster.id,
      points: _currentPoints,
      color: brush.color,
      thickness: brush.thickness,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(canvasProvider(poster.id).notifier).addStrokeLocalAndRemote(stroke);
    setState(() {
      _currentPoints = [];
    });
    // notify presence stopped
    ref.read(canvasProvider(poster.id).notifier).setPresence(0.5, 0.5, false, auth.colorValue);
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
          onTapUp: (e) async {
            final isPlacing = ref.read(isPlacingStickerProvider);
            final selected = ref.read(selectedStickerProvider);
            if (isPlacing && selected != null && posterContainsLocal(e.localPosition, posterRect)) {
              final svc = ref.read(firebaseServiceProvider);
              final auth = ref.read(authInfoProvider)!;
              final id = svc.generateId();
              final normalized = posterLocalToNormalized(e.localPosition, posterRect);
              final st = StickerModel(
                id: id,
                userId: auth.uid,
                posterId: poster.id,
                imageUrl: selected,
                x: normalized.dx,
                y: normalized.dy,
                scale: 1.0,
                rotation: 0.0,
                timestamp: DateTime.now().millisecondsSinceEpoch,
              );
              await ref.read(canvasProvider(poster.id).notifier).addSticker(st);
              ref.read(isPlacingStickerProvider.notifier).state = false;
              ref.read(selectedStickerProvider.notifier).state = null;
            }
          },
          onPanStart: (e) => _start(e.localPosition, posterRect),
          onPanUpdate: (e) => _update(e.localPosition, posterRect),
          onPanEnd: (e) => _end(posterRect),
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
                ...canvasState.stickers.map((st) {
                  final stickerCenter = posterNormalizedToLocal(Offset(st.x, st.y), posterRect);
                  final left = stickerCenter.dx - (32 * st.scale);
                  final top = stickerCenter.dy - (32 * st.scale);
                  return Positioned(
                    left: left.clamp(posterRect.left, posterRect.right - 8.0),
                    top: top.clamp(posterRect.top, posterRect.bottom - 8.0),
                    child: Transform.rotate(
                      angle: st.rotation,
                      child: Image.network(
                        st.imageUrl,
                        width: 64 * st.scale,
                        height: 64 * st.scale,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => Container(
                          width: 64 * st.scale,
                          height: 64 * st.scale,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  );
                }).toList(),
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

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.4;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

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

    for (final s in strokes) {
      paint.color = s.color;
      paint.strokeWidth = s.thickness;
      final path = Path();
      if (s.points.isNotEmpty) {
        path.moveTo(
          posterRect.left + s.points.first.dx * posterRect.width,
          posterRect.top + s.points.first.dy * posterRect.height,
        );
        for (var i = 1; i < s.points.length; i++) {
          path.lineTo(
            posterRect.left + s.points[i].dx * posterRect.width,
            posterRect.top + s.points[i].dy * posterRect.height,
          );
        }
        canvas.drawPath(path, paint);
      }
    }

    if (currentPoints.isNotEmpty) {
      paint.color = brushColor;
      paint.strokeWidth = brushThickness;
      final path = Path();
      path.moveTo(
        posterRect.left + currentPoints.first.dx * posterRect.width,
        posterRect.top + currentPoints.first.dy * posterRect.height,
      );
      for (var i = 1; i < currentPoints.length; i++) {
        path.lineTo(
          posterRect.left + currentPoints[i].dx * posterRect.width,
          posterRect.top + currentPoints[i].dy * posterRect.height,
        );
      }
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
