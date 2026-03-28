import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/canvas_provider.dart';

/// Renders small circular indicators for each participant's pointer.
/// Uses normalized coordinates from `Presence` and paints a colored dot.
class ParticipantsIndicator extends ConsumerWidget {
  const ParticipantsIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(canvasProvider);
    final size = MediaQuery.of(context).size;
    return Stack(
      children: state.presence.map((p) {
        final left = (p.x * size.width).clamp(0.0, size.width - 12.0);
        final top = (p.y * size.height).clamp(0.0, size.height - 12.0);
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
  }
}
