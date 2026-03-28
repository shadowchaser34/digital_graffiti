import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/camera_background.dart';
import '../widgets/canvas_widget.dart';
import '../widgets/toolbar.dart';
import '../widgets/participants_indicator.dart';
import '../providers/poster_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = ref.watch(activePosterProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Digital Graffiti Wall · ${poster.name}'),
      ),
      body: CameraBackground(
        overlay: Stack(
          children: [
            const CanvasWidget(),
            const ParticipantsIndicator(),
            const Positioned(top: 8, left: 8, child: ToolBar()),
          ],
        ),
      ),
    );
  }
}
