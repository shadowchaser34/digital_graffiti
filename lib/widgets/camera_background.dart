import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/poster_anchor.dart';
import '../providers/poster_provider.dart';
import '../services/poster_detection_service.dart';

/// Renders the live camera feed and places an overlay widget on top of it.
///
/// The widget is defensive: if camera permission is denied, no device camera
/// is available, or the platform channel is unavailable in tests, it falls back
/// to a non-white loading/error surface instead of crashing.
class CameraBackground extends ConsumerStatefulWidget {
  final Widget overlay;

  const CameraBackground({super.key, required this.overlay});

  @override
  ConsumerState<CameraBackground> createState() => _CameraBackgroundState();
}

class _CameraBackgroundState extends ConsumerState<CameraBackground> {
  CameraController? _controller;
  String? _errorMessage;
  bool _permissionDenied = false;
  PosterDetectionService? _detectionService;
  bool _detectorReady = false;
  bool _isProcessingFrame = false;
  DateTime _lastFrameTick = DateTime.fromMillisecondsSinceEpoch(0);
  String _detectorHint = 'Scan posterul pentru a-l ancora';
  String? _candidatePosterId;
  int _stableHits = 0;

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
        _detectorHint = 'Detector poster în pornire...';
      });

      _detectionService = PosterDetectionService(catalog: posterCatalog);
      await _detectionService!.initialize();
      _detectorReady = true;

      await controller.startImageStream(_handleFrame);

      if (!mounted) {
        return;
      }

      setState(() {
        _detectorHint = 'Arată un afiș din setul de referință';
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
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      controller.stopImageStream();
    }
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleFrame(CameraImage image) async {
    if (!_detectorReady || _isProcessingFrame) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameTick).inMilliseconds < 220) {
      return;
    }

    _isProcessingFrame = true;
    _lastFrameTick = now;

    try {
      final detection = await _detectionService?.detect(image);
      if (detection == null) {
        if (mounted) {
          setState(() {
            _detectorHint = 'Scanare poster...';
          });
        }
        _candidatePosterId = null;
        _stableHits = 0;
        return;
      }

      if (detection.poster.id == _candidatePosterId) {
        _stableHits += 1;
      } else {
        _candidatePosterId = detection.poster.id;
        _stableHits = 1;
      }

      if (mounted) {
        setState(() {
          _detectorHint = '${detection.poster.name} · scor ${detection.score.toStringAsFixed(3)}';
        });
      }

      if (_stableHits >= 2) {
        final activePoster = ref.read(activePosterProvider);
        if (activePoster.id != detection.poster.id) {
          ref.read(activePosterProvider.notifier).state = detection.poster;
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _detectorHint = 'Detector poster temporar indisponibil';
        });
      }
    } finally {
      _isProcessingFrame = false;
    }
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
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: Text(
                  _errorMessage ?? _detectorHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}