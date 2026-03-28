import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stroke.dart';
import '../models/sticker_model.dart';
import '../providers/canvas_provider.dart';
import '../providers/sticker_provider.dart';
import '../providers/auth_provider.dart';

class CanvasWidget extends ConsumerStatefulWidget {
  const CanvasWidget({super.key});

  @override
  ConsumerState<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends ConsumerState<CanvasWidget> {
  List<Offset> _currentPoints = [];
  Color _color = Colors.black;
  double _thickness = 4.0;

  void _start(Offset pt) {
    setState(() {
      _currentPoints = [pt];
    });
    // notify presence: user started drawing
    final size = MediaQuery.of(context).size;
    final nx = pt.dx / size.width;
    final ny = pt.dy / size.height;
    final auth = ref.read(authInfoProvider)!;
    ref.read(canvasProvider.notifier).setPresence(nx, ny, true, auth.colorValue);
  }

  void _update(Offset pt) {
    setState(() {
      _currentPoints.add(pt);
    });
    final size = MediaQuery.of(context).size;
    final nx = pt.dx / size.width;
    final ny = pt.dy / size.height;
    final auth = ref.read(authInfoProvider)!;
    ref.read(canvasProvider.notifier).setPresence(nx, ny, true, auth.colorValue);
  }

  void _end() async {
    final svc = ref.read(firebaseServiceProvider);
    final auth = ref.read(authInfoProvider)!;
    final id = svc.generateId();
    final stroke = Stroke(
      id: id,
      userId: auth.uid,
      points: _currentPoints,
      color: _color,
      thickness: _thickness,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(canvasProvider.notifier).addStrokeLocalAndRemote(stroke);
    setState(() {
      _currentPoints = [];
    });
    // notify presence stopped
    ref.read(canvasProvider.notifier).setPresence(0.5, 0.5, false, auth.colorValue);
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasProvider);
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTapUp: (e) async {
        final isPlacing = ref.read(isPlacingStickerProvider);
        final selected = ref.read(selectedStickerProvider);
        if (isPlacing && selected != null) {
          final svc = ref.read(firebaseServiceProvider);
          final auth = ref.read(authInfoProvider)!;
          final id = svc.generateId();
          final nx = e.localPosition.dx / size.width;
          final ny = e.localPosition.dy / size.height;
          final st = StickerModel(
            id: id,
            userId: auth.uid,
            imageUrl: selected,
            x: nx,
            y: ny,
            scale: 1.0,
            rotation: 0.0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );
          await ref.read(canvasProvider.notifier).addSticker(st);
          // exit placing
          ref.read(isPlacingStickerProvider.notifier).state = false;
          ref.read(selectedStickerProvider.notifier).state = null;
        }
      },
      onPanStart: (e) => _start(e.localPosition),
      onPanUpdate: (e) => _update(e.localPosition),
      onPanEnd: (e) => _end(),
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Painter draws strokes.
            CustomPaint(
              size: size,
              painter: _GraffitiPainter(canvasState.strokes, _currentPoints),
            ),
            // Render stickers as positioned widgets so they remain crisp.
            ...canvasState.stickers.map((st) {
              final left = (st.x * size.width) - (32 * st.scale);
              final top = (st.y * size.height) - (32 * st.scale);
              return Positioned(
                left: left.clamp(0.0, size.width - 8.0),
                top: top.clamp(0.0, size.height - 8.0),
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
            }).toList()
          ],
        ),
      ),
    );
  }
}

class _GraffitiPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset> currentPoints;
  _GraffitiPainter(this.strokes, this.currentPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (final s in strokes) {
      paint.color = s.color;
      paint.strokeWidth = s.thickness;
      final path = Path();
      if (s.points.isNotEmpty) {
        path.moveTo(s.points.first.dx, s.points.first.dy);
        for (var i = 1; i < s.points.length; i++) {
          path.lineTo(s.points[i].dx, s.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    if (currentPoints.isNotEmpty) {
      paint.color = Colors.black;
      paint.strokeWidth = 4.0;
      final path = Path();
      path.moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (var i = 1; i < currentPoints.length; i++) {
        path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
