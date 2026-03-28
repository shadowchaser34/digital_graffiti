import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/canvas_provider.dart';
import '../providers/poster_provider.dart';
import '../utils/poster_layout.dart';

/// Renders small circular indicators for each participant's pointer.
/// Uses normalized coordinates from `Presence` and paints a colored dot.
class ParticipantsIndicator extends ConsumerWidget {
  const ParticipantsIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = ref.watch(activePosterProvider);
    final state = ref.watch(canvasProvider(poster.id));

    return LayoutBuilder(
      builder: (context, constraints) {
        final posterRect = posterViewportRect(constraints.biggest);
        return Stack(
          children: state.presence.map((p) {
            final local = posterNormalizedToLocal(Offset(p.x, p.y), posterRect);
            final left = local.dx.clamp(posterRect.left, posterRect.right - 12.0);
            final top = local.dy.clamp(posterRect.top, posterRect.bottom - 12.0);
            return Positioned(
              left: left,
              top: top,
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
