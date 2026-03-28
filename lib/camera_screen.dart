import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/poster_catalog.dart';
import 'providers/poster_provider.dart';
import 'services/opencode_poster_recognition_service.dart';
import 'utils/poster_geometry.dart';
import 'widgets/canvas_widget.dart';
import 'widgets/participants_indicator.dart';
import 'widgets/toolbar.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? controller;
  Timer? _detectionTimer;
  bool _isDetecting = false;
  final _recognitionService = OpenCodePosterRecognitionService.fromEnvironment();

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
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
      }
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
      _startPosterPolling();
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare inițializare cameră: $error')),
      );
    }
  }

  void _startPosterPolling() {
    _detectionTimer?.cancel();
    if (!_recognitionService.isConfigured) {
      return;
    }

    _detectionTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _detectPoster();
    });
  }

  Future<void> _detectPoster() async {
    final currentController = controller;
    if (_isDetecting || currentController == null || !currentController.value.isInitialized || !mounted) {
      return;
    }
    if (currentController.value.isTakingPicture) {
      return;
    }

    _isDetecting = true;
    try {
      final shot = await currentController.takePicture();
      final bytes = await File(shot.path).readAsBytes();
      final pose = await _recognitionService.recognizePoster(
        frameBytes: bytes,
        candidates: posterCatalog,
      );
      if (!mounted || pose == null) {
        return;
      }

      ref.read(activePosterIdProvider.notifier).state = pose.posterId;
      ref.read(activePosterPoseProvider.notifier).state = pose;
    } catch (_) {
      // The manual poster picker remains available if detection fails.
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _pickPosterManually() async {
    final size = MediaQuery.of(context).size;
    final chosen = await showModalBottomSheet<PosterCatalogEntry>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: posterCatalog
              .map(
                (poster) => ListTile(
                  title: Text(poster.name),
                  subtitle: Text(poster.id),
                  onTap: () => Navigator.of(ctx).pop(poster),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (!mounted || chosen == null) {
      return;
    }

    ref.read(activePosterIdProvider.notifier).state = chosen.id;
    ref.read(activePosterPoseProvider.notifier).state = PosterGeometry.fallbackPose(chosen.id, size);
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final initialized = controller != null && controller!.value.isInitialized;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: initialized
                ? CameraPreview(controller!)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF101418), Color(0xFF1E2530)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Camera unavailable\nUsing manual poster selection',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  ),
          ),
          const Positioned.fill(child: CanvasWidget()),
          const Positioned.fill(child: ParticipantsIndicator()),
          Positioned(
            top: topInset + 8,
            left: 8,
            child: const ToolBar(),
          ),
          Positioned(
            top: topInset + 8,
            right: 8,
            child: ElevatedButton.icon(
              onPressed: _pickPosterManually,
              icon: const Icon(Icons.photo_size_select_actual_outlined),
              label: const Text('Poster'),
            ),
          ),
        ],
      ),
    );
  }
}
