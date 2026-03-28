import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/canvas_provider.dart';
import '../providers/poster_provider.dart';
import '../models/poster_catalog.dart';
import '../utils/poster_geometry.dart';

/// Renders small circular indicators for each participant's pointer.
/// Uses normalized coordinates from `Presence` and paints a colored dot.
class ParticipantsIndicator extends ConsumerWidget {
  const ParticipantsIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(canvasProvider);
    final posterId = ref.watch(activePosterIdProvider) ?? defaultPosterId;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final pose = ref.watch(activePosterPoseProvider);
        final resolvedPose = pose != null && pose.posterId == posterId ? pose : PosterGeometry.fallbackPose(posterId, size);

        return Stack(
          children: state.presence.map((p) {
            final point = PosterGeometry.localToScreen(Offset(p.x, p.y), resolvedPose, size);
            return Positioned(
              left: point.dx.clamp(0.0, size.width - 12.0),
              top: point.dy.clamp(0.0, size.height - 12.0),
              child: Opacity(
                opacity: p.isDrawing ? 1.0 : 0.6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(p.colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
