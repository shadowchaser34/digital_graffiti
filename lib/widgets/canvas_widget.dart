import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sticker_model.dart';
import '../models/stroke.dart';
import '../models/poster_catalog.dart';
import '../models/poster_pose.dart';
import '../providers/auth_provider.dart';
import '../providers/canvas_provider.dart';
import '../providers/poster_provider.dart';
import '../providers/sticker_provider.dart';
import '../utils/poster_geometry.dart';

class CanvasWidget extends ConsumerStatefulWidget {
  const CanvasWidget({super.key});

  @override
  ConsumerState<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends ConsumerState<CanvasWidget> {
  List<Offset> _currentPoints = [];
  Offset? _lastLocalPoint;
  bool _isDrawing = false;
  Color _color = Colors.black;
  double _thickness = 4.0;

  void _start(Offset screenPoint, Size size, PosterPose pose) {
    final local = PosterGeometry.screenToLocal(screenPoint, pose, size);
    if (local == null) {
      return;
    }

    setState(() {
      _currentPoints = [local];
      _lastLocalPoint = local;
      _isDrawing = true;
    });

    final auth = ref.read(authInfoProvider)!;
    ref.read(canvasProvider.notifier).setPresence(local.dx, local.dy, true, auth.colorValue);
  }

  void _update(Offset screenPoint, Size size, PosterPose pose) {
    if (!_isDrawing) {
      return;
    }

    final local = PosterGeometry.screenToLocal(screenPoint, pose, size);
    if (local == null) {
      return;
    }

    setState(() {
      _currentPoints.add(local);
      _lastLocalPoint = local;
    });

    final auth = ref.read(authInfoProvider)!;
    ref.read(canvasProvider.notifier).setPresence(local.dx, local.dy, true, auth.colorValue);
  }

  Future<void> _end() async {
    if (!_isDrawing || _currentPoints.isEmpty) {
      setState(() {
        _currentPoints = [];
        _lastLocalPoint = null;
        _isDrawing = false;
      });
      return;
    }

    final svc = ref.read(firebaseServiceProvider);
    final auth = ref.read(authInfoProvider)!;
    final posterId = ref.read(activePosterIdProvider) ?? defaultPosterId;
    final id = svc.generateId();
    final stroke = Stroke(
      id: id,
      userId: auth.uid,
      posterId: posterId,
      points: List<Offset>.from(_currentPoints),
      color: _color,
      thickness: _thickness,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(canvasProvider.notifier).addStrokeLocalAndRemote(stroke);

    final lastPoint = _lastLocalPoint ?? const Offset(0.5, 0.5);
    setState(() {
      _currentPoints = [];
      _lastLocalPoint = null;
      _isDrawing = false;
    });

    ref.read(canvasProvider.notifier).setPresence(lastPoint.dx, lastPoint.dy, false, auth.colorValue);
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final isPlacingSticker = ref.watch(isPlacingStickerProvider);
    final posterId = ref.watch(activePosterIdProvider) ?? defaultPosterId;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final pose = ref.watch(activePosterPoseProvider);
        final resolvedPose = pose != null && pose.posterId == posterId ? pose : PosterGeometry.fallbackPose(posterId, size);
        final posterBounds = PosterGeometry.posterBounds(resolvedPose, size);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: isPlacingSticker
              ? (e) async {
                  final selected = ref.read(selectedStickerProvider);
                  final local = PosterGeometry.screenToLocal(e.localPosition, resolvedPose, size);
                  if (selected == null || local == null) {
                    return;
                  }

                  final svc = ref.read(firebaseServiceProvider);
                  final auth = ref.read(authInfoProvider)!;
                  final id = svc.generateId();
                  final sticker = StickerModel(
                    id: id,
                    userId: auth.uid,
                    posterId: posterId,
                    imageUrl: selected,
                    x: local.dx,
                    y: local.dy,
                    scale: 1.0,
                    rotation: 0.0,
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                  );
                  await ref.read(canvasProvider.notifier).addSticker(sticker);
                  ref.read(isPlacingStickerProvider.notifier).state = false;
                  ref.read(selectedStickerProvider.notifier).state = null;
                }
              : null,
          onPanStart: isPlacingSticker ? null : (e) => _start(e.localPosition, size, resolvedPose),
          onPanUpdate: isPlacingSticker ? null : (e) => _update(e.localPosition, size, resolvedPose),
          onPanEnd: isPlacingSticker ? null : (e) => _end(),
          child: SizedBox.expand(
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _GraffitiPainter(canvasState.strokes, _currentPoints, resolvedPose),
                ),
                ...canvasState.stickers.map((sticker) {
                  final center = PosterGeometry.localToScreen(Offset(sticker.x, sticker.y), resolvedPose, size);
                  final stickerSize = (posterBounds.shortestSide * 0.14 * sticker.scale).clamp(32.0, posterBounds.shortestSide * 0.5);
                  return Positioned(
                    left: center.dx - (stickerSize / 2),
                    top: center.dy - (stickerSize / 2),
                    child: Transform.rotate(
                      angle: sticker.rotation,
                      child: Image.network(
                        sticker.imageUrl,
                        width: stickerSize,
                        height: stickerSize,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: stickerSize,
                          height: stickerSize,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  );
                }),
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
  final PosterPose pose;

  _GraffitiPainter(this.strokes, this.currentPoints, this.pose);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.clipPath(PosterGeometry.posterPath(pose, size));

    for (final stroke in strokes) {
      if (stroke.points.isEmpty) {
        continue;
      }

      paint.color = stroke.color;
      paint.strokeWidth = stroke.thickness;
      final path = Path();
      final firstPoint = PosterGeometry.localToScreen(stroke.points.first, pose, size);
      path.moveTo(firstPoint.dx, firstPoint.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        final nextPoint = PosterGeometry.localToScreen(stroke.points[i], pose, size);
        path.lineTo(nextPoint.dx, nextPoint.dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentPoints.isNotEmpty) {
      paint.color = Colors.black;
      paint.strokeWidth = 4.0;
      final path = Path();
      final firstPoint = PosterGeometry.localToScreen(currentPoints.first, pose, size);
      path.moveTo(firstPoint.dx, firstPoint.dy);
      for (var i = 1; i < currentPoints.length; i++) {
        final nextPoint = PosterGeometry.localToScreen(currentPoints[i], pose, size);
        path.lineTo(nextPoint.dx, nextPoint.dy);
      }
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
