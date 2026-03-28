import 'package:flutter/material.dart';
import '../models/poster_pose.dart';
import '../utils/poster_geometry.dart';

class CanvasWidget extends StatefulWidget {
  final PosterPose? posterPose;

  const CanvasWidget({super.key, this.posterPose});

  @override
  State<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {
  final List<Offset?> points = [];
  bool _wasInsidePoster = false;

  Rect? _posterRect(Size size) {
    final pose = widget.posterPose;
    if (pose == null) return null;

    return PosterGeometry.posterBounds(pose, size);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final rect = _posterRect(size);

        return GestureDetector(
          onPanStart: (details) {
            final pose = widget.posterPose;
            if (pose == null || !pose.isValid) {
              _wasInsidePoster = false;
              return;
            }

            final local = PosterGeometry.screenToLocal(details.localPosition, pose, size);
            if (local == null) {
              _wasInsidePoster = false;
              return;
            }

            _wasInsidePoster = true;
            setState(() {
              points.add(local);
            });
          },
          onPanUpdate: (details) {
            final pose = widget.posterPose;
            if (pose == null || !pose.isValid) return;

            final screenPoint = details.localPosition;
            final local = PosterGeometry.screenToLocal(screenPoint, pose, size);
            if (local == null) {
              if (_wasInsidePoster) {
                _wasInsidePoster = false;
                setState(() {
                  points.add(null);
                });
              }
              return;
            }

            _wasInsidePoster = true;

            setState(() {
              points.add(local);
            });
          },
          onPanEnd: (_) {
            _wasInsidePoster = false;
            setState(() {
              points.add(null);
            });
          },
          child: CustomPaint(
            painter: _GraffitiPainter(points, rect, widget.posterPose),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _GraffitiPainter extends CustomPainter {
  final List<Offset?> points;
  final Rect? rect;
  final PosterPose? pose;

  _GraffitiPainter(this.points, this.rect, this.pose);

  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null || !pose!.isValid) return;

    final path = PosterGeometry.posterPath(pose!, size);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.green.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    canvas.save();
    canvas.clipPath(path);

    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      if (p1 != null && p2 != null) {
        final s1 = PosterGeometry.localToScreen(p1, pose!, size);
        final s2 = PosterGeometry.localToScreen(p2, pose!, size);
        canvas.drawLine(s1, s2, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}