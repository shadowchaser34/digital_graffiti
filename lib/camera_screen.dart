import 'package:flutter/material.dart';

import 'widgets/camera_background.dart';
import 'widgets/canvas_widget.dart';
import 'widgets/toolbar.dart';

/// Dedicated camera-first screen that shows the live preview behind the canvas.
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: CameraBackground(
        overlay: Stack(
          children: [
            const CanvasWidget(),
            const Positioned(top: 12, left: 12, child: ToolBar()),
          ],
        ),
      ),
    );
  }
}
