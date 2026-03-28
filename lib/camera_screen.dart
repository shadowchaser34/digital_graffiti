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
            const Positioned(top: 12, left: 12, child: Toolbar()),
          ],
        ),
      ),
    );
  }
}
      _detectionTimer?.cancel();
      _posterDetectionService?.dispose();
      super.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(controller!),
          if (_posterPresent)
            const CanvasWidget()
          else
            Center(
              child: Container(
                color: Colors.black54,
                child: const Text(
                  'Așează posterul în cadru pentru a desena!',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
=======
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
>>>>>>> 751584e08c0bc3fbce2cc3119d3ee38487e16849
      ),
    );
  }
}