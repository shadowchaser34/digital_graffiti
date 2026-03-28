import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Renders the live camera feed and places an overlay widget on top of it.
///
/// The widget is defensive: if camera permission is denied, no device camera
/// is available, or the platform channel is unavailable in tests, it falls back
/// to a non-white loading/error surface instead of crashing.
class CameraBackground extends StatefulWidget {
  final Widget overlay;

  const CameraBackground({super.key, required this.overlay});

  @override
  State<CameraBackground> createState() => _CameraBackgroundState();
}

class _CameraBackgroundState extends State<CameraBackground> {
  CameraController? _controller;
  String? _errorMessage;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _permissionDenied = true;
          _errorMessage = 'Permisiune cameră refuzată';
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Nu există cameră disponibilă';
        });
        return;
      }

      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _errorMessage = null;
        _permissionDenied = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Eroare cameră: $error';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraPreview = _controller != null && _controller!.value.isInitialized
        ? CameraPreview(_controller!)
        : Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0E1A2B), Color(0xFF1D2B44), Color(0xFF2D3E5F)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _permissionDenied
                        ? 'Așteptăm permisiunea camerei'
                        : (_errorMessage ?? 'Inițializare cameră...'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        cameraPreview,
        Positioned.fill(child: widget.overlay),
      ],
    );
  }
}