import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brush_type.dart';
import '../models/poster_catalog.dart';
import '../models/poster_pose.dart';
import '../models/stroke.dart';
import '../providers/auth_provider.dart';
import '../providers/brush_provider.dart';
import '../providers/canvas_provider.dart';
import '../providers/poster_provider.dart';
import '../utils/poster_geometry.dart';

class CanvasWidget extends ConsumerStatefulWidget {
  final PosterPose? posterPose;

  const CanvasWidget({super.key, this.posterPose});

  @override
  ConsumerState<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends ConsumerState<CanvasWidget> {
  final List<Offset> _activePoints = [];
  BrushSettings? _activeBrush;
  bool _wasInsidePoster = false;

  void _beginSegment(Offset localPoint, BrushSettings settings) {
    _activePoints
      ..clear()
      ..add(localPoint);
    _activeBrush = settings;
  }

  void _appendPoint(Offset localPoint) {
    _activePoints.add(localPoint);
  }

  void _clearActiveSegment() {
    _activePoints.clear();
    _activeBrush = null;
  }

  void _commitSegment() {
    if (_activePoints.length < 2) {
      setState(_clearActiveSegment);
      return;
    }

    final BrushSettings brush = _activeBrush ?? ref.read(brushSettingsProvider);
    final authInfo = ref.read(authInfoProvider);
    final posterId = ref.read(activePosterIdProvider) ?? defaultPosterId;

    final stroke = Stroke(
      id: ref.read(firebaseServiceProvider).generateId(),
      userId: authInfo?.uid ?? 'anonymous',
      posterId: posterId,
      points: List<Offset>.from(_activePoints),
      color: brush.color,
      thickness: brush.thickness,
      brushType: brush.brushType,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    setState(_clearActiveSegment);
    unawaited(ref.read(canvasProvider.notifier).addStrokeLocalAndRemote(stroke));
  }

  @override
  Widget build(BuildContext context) {
    final strokes = ref.watch(canvasProvider).strokes;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;

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
            final settings = ref.read(brushSettingsProvider);
            setState(() {
              _beginSegment(local, settings);
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
                _commitSegment();
              }
              return;
            }

            if (!_wasInsidePoster) {
              _wasInsidePoster = true;
              final settings = ref.read(brushSettingsProvider);
              setState(() {
                _beginSegment(local, settings);
              });
              return;
            }

            _wasInsidePoster = true;

            setState(() {
              _appendPoint(local);
            });
          },
          onPanEnd: (_) {
            if (_wasInsidePoster) {
              _commitSegment();
            }
            _wasInsidePoster = false;
          },
          child: CustomPaint(
            painter: _GraffitiPainter(
              strokes: strokes,
              activePoints: _activePoints,
              activeBrush: _activeBrush,
              pose: widget.posterPose,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class _GraffitiPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset> activePoints;
  final BrushSettings? activeBrush;
  final PosterPose? pose;

  _GraffitiPainter({
    required this.strokes,
    required this.activePoints,
    required this.activeBrush,
    required this.pose,
  });

  void _drawStyledLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    _StrokeStyle style,
  ) {
    switch (style.brushType) {
      case BrushType.pen:
        final paint = Paint()
          ..color = style.color
          ..strokeWidth = style.thickness
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
        canvas.drawLine(p1, p2, paint);
        break;
      case BrushType.marker:
        final paint = Paint()
          ..color = style.color.withOpacity(0.68)
          ..strokeWidth = style.thickness * 1.35
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
        canvas.drawLine(p1, p2, paint);
        break;
      case BrushType.calligraphy:
        final paint = Paint()
          ..color = style.color
          ..strokeWidth = style.thickness * 1.2
          ..strokeCap = StrokeCap.square
          ..isAntiAlias = true;
        canvas.drawLine(p1, p2, paint);
        break;
      case BrushType.neon:
        final glow = Paint()
          ..color = style.color.withOpacity(0.35)
          ..strokeWidth = style.thickness * 2.7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..isAntiAlias = true;
        final mid = Paint()
          ..color = style.color.withOpacity(0.78)
          ..strokeWidth = style.thickness * 1.6
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
        final core = Paint()
          ..color = Colors.white
          ..strokeWidth = (style.thickness * 0.55).clamp(1.0, 24.0)
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
        canvas.drawLine(p1, p2, glow);
        canvas.drawLine(p1, p2, mid);
        canvas.drawLine(p1, p2, core);
        break;
    }
  }

  void _drawStroke(
    Canvas canvas,
    Size size,
    List<Offset> points,
    _StrokeStyle style,
  ) {
    if (points.length < 2) return;
    final activePose = pose;
    if (activePose == null || !activePose.isValid) return;

    for (int i = 0; i < points.length - 1; i++) {
      final s1 = PosterGeometry.localToScreen(points[i], activePose, size);
      final s2 = PosterGeometry.localToScreen(points[i + 1], activePose, size);
      _drawStyledLine(canvas, s1, s2, style);
    }
  }

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

    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke.points, _StrokeStyle.fromStroke(stroke));
    }

    if (activeBrush != null) {
      _drawStroke(
        canvas,
        size,
        activePoints,
        _StrokeStyle(
          color: activeBrush!.color,
          thickness: activeBrush!.thickness,
          brushType: activeBrush!.brushType,
        ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StrokeStyle {
  final Color color;
  final double thickness;
  final BrushType brushType;

  const _StrokeStyle({
    required this.color,
    required this.thickness,
    required this.brushType,
  });

  factory _StrokeStyle.fromStroke(Stroke stroke) {
    return _StrokeStyle(
      color: stroke.color,
      thickness: stroke.thickness,
      brushType: stroke.brushType,
    );
  }
}