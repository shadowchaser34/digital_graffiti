import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/canvas_widget.dart';
import 'services/poster_detection_service.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  PosterDetectionService? _posterDetectionService;
  bool _posterPresent = false;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    initCamera();
    _posterDetectionService = PosterDetectionService(posterAssetPath: 'assets/poster.jpg'); // actualizează calea
  }

  Future<void> initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permisiune Camera'),
          content: const Text('Permite accesul la cameră în setările aplicației.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(ctx).pop();
              },
              child: const Text('Deschide Setări'),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return;
      }
      controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
      );
      await controller!.initialize();
      setState(() {});
      _startPosterDetection();
    } catch (e) {
      // initialization failed; you can log or show an error UI
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare inițializare cameră: $e')),
      );
    }
    void _startPosterDetection() {
      _detectionTimer?.cancel();
      _detectionTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (controller == null || !controller!.value.isInitialized) return;
        try {
          final file = await controller!.takePicture();
          final inputImage = InputImage.fromFilePath(file.path);
          final present = await _posterDetectionService?.isPosterPresent(inputImage) ?? false;
          if (mounted) {
            setState(() {
              _posterPresent = present;
            });
          }
        } catch (_) {}
      });
    }

    @override
    void dispose() {
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
      ),
    );
  }
}