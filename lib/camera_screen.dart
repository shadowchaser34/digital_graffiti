import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/poster_catalog.dart';
import 'providers/poster_provider.dart';
import 'services/opencode_poster_recognition_service.dart';
import 'services/polling_interval_policy.dart';
import 'services/poster_lock_stabilizer.dart';
import 'widgets/canvas_widget.dart';
import 'widgets/participants_indicator.dart';
import 'widgets/toolbar.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  CameraController? controller;
  Timer? _lostFlashTimer;
  bool _isDetecting = false;
  bool _streamDetectionEnabled = false;
  int _nextDetectionAtMs = 0;
  bool _lostFlashVisible = false;
  bool _lostFlashStrong = false;
  bool? _previousLocked;
  int _stableLockedCycles = 0;
  static const PollingIntervalPolicy _pollingIntervalPolicy = PollingIntervalPolicy();
  final _recognitionService = OpenCodePosterRecognitionService.fromEnvironment();
  final _lockStabilizer = PosterLockStabilizer();

  void _resetStableLockedCycles() {
    _stableLockedCycles = 0;
  }

  void _triggerLostTransitionFeedback() {
    HapticFeedback.heavyImpact();
    if (!mounted) return;

    _lostFlashTimer?.cancel();

    // 2-step aggressive pulse: strong flash + heavy/medium haptic combo.
    setState(() {
      _lostFlashVisible = true;
      _lostFlashStrong = true;
    });
    _lostFlashTimer = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _lostFlashVisible = false;
        _lostFlashStrong = false;
      });

      HapticFeedback.mediumImpact();
      _lostFlashTimer = Timer(const Duration(milliseconds: 90), () {
        if (!mounted) return;
        setState(() {
          _lostFlashVisible = true;
          _lostFlashStrong = false;
        });

        _lostFlashTimer = Timer(const Duration(milliseconds: 140), () {
          if (!mounted) return;
          setState(() {
            _lostFlashVisible = false;
            _lostFlashStrong = false;
          });
        });
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final currentController = controller;
    if (currentController == null || !currentController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _streamDetectionEnabled = false;
      if (currentController.value.isStreamingImages) {
        unawaited(currentController.stopImageStream().catchError((_) {}));
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_startPosterStreamOrFallback());
    }
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
      try {
        await controller!.setFlashMode(FlashMode.off);
      } catch (_) {
        // Some devices may not support changing flash mode here.
      }
      await _startPosterStreamOrFallback();
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

  Future<void> _startPosterStreamOrFallback() async {
    final currentController = controller;
    if (currentController == null || !currentController.value.isInitialized) {
      return;
    }

    if (currentController.value.isStreamingImages) {
      _streamDetectionEnabled = true;
      return;
    }

    try {
      await currentController.startImageStream(_onCameraImage);
      _streamDetectionEnabled = true;
      _nextDetectionAtMs = 0;
    } catch (_) {
      _streamDetectionEnabled = false;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image stream indisponibil. Folosește selecția manuală de poster.'),
        ),
      );
    }
  }

  Duration _currentPollingInterval() {
    final activePose = ref.read(activePosterPoseProvider);
    final isPosterLocked = activePose != null && activePose.isValid;
    return _pollingIntervalPolicy.intervalForState(
      isPosterLocked: isPosterLocked,
      stableLockedCycles: _stableLockedCycles,
    );
  }

  void _onCameraImage(CameraImage image) {
    if (!_streamDetectionEnabled || _isDetecting || !mounted) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs < _nextDetectionAtMs) {
      return;
    }

    _nextDetectionAtMs = nowMs + _currentPollingInterval().inMilliseconds;
    _isDetecting = true;
    unawaited(_detectPosterFromStream(image));
  }

  Future<void> _detectPosterFromStream(CameraImage image) async {
    final currentController = controller;
    if (currentController == null || !currentController.value.isInitialized || !mounted) {
      return;
    }
    if (image.planes.isEmpty) {
      return;
    }

    try {
      try {
        await currentController.setFlashMode(FlashMode.off);
      } catch (_) {
        // Ignore flash-mode failures and continue detection.
      }

      final viewport = MediaQuery.of(context).size;
      final pose = await _recognitionService.recognizePosterFromLumaFrame(
        lumaBytes: image.planes.first.bytes,
        frameWidth: image.width,
        frameHeight: image.height,
        candidates: posterCatalog,
        viewportSize: viewport,
      );
      if (!mounted) {
        return;
      }
      final decision = _lockStabilizer.processDetection(
        detectedPose: pose,
        activePose: ref.read(activePosterPoseProvider),
      );

      final activePose = ref.read(activePosterPoseProvider);
      final wasLocked = activePose != null && activePose.isValid;
      final lockedPosterId = wasLocked ? activePose.posterId : null;

      if (!wasLocked) {
        _resetStableLockedCycles();
      } else {
        final keepsSamePoster =
            pose != null &&
            pose.posterId == lockedPosterId &&
            !decision.clearPose &&
            decision.nextPose != null &&
            decision.nextPose!.posterId == lockedPosterId;

        if (keepsSamePoster) {
          _stableLockedCycles += 1;
        } else {
          // Any miss, low-confidence hold, or switch candidate drops back to baseline lock speed.
          _resetStableLockedCycles();
        }
      }

      if (!decision.shouldChange) {
        return;
      }

      if (decision.clearPose) {
        ref.read(activePosterPoseProvider.notifier).state = null;
        return;
      }

      final nextPose = decision.nextPose;
      if (nextPose == null) {
        return;
      }

      ref.read(activePosterIdProvider.notifier).state = nextPose.posterId;
      ref.read(activePosterPoseProvider.notifier).state = nextPose;
    } catch (_) {
      _resetStableLockedCycles();
      final decision = _lockStabilizer.processDetection(
        detectedPose: null,
        activePose: ref.read(activePosterPoseProvider),
      );
      if (decision.clearPose && mounted) {
        ref.read(activePosterPoseProvider.notifier).state = null;
      }
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _pickPosterManually() async {
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
    ref.read(activePosterPoseProvider.notifier).state = null;
    _lockStabilizer.reset();
    _resetStableLockedCycles();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Poster selectat: ${chosen.name}. Arată afișul în cameră pentru lock precis.'),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lostFlashTimer?.cancel();
    _streamDetectionEnabled = false;

    final currentController = controller;
    controller = null;
    if (currentController != null) {
      if (currentController.value.isStreamingImages) {
        unawaited(
          currentController
              .stopImageStream()
              .catchError((_) {})
              .whenComplete(currentController.dispose),
        );
      } else {
        unawaited(currentController.dispose());
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final initialized = controller != null && controller!.value.isInitialized;
    final activePosterId = ref.watch(activePosterIdProvider) ?? defaultPosterId;
    final activePose = ref.watch(activePosterPoseProvider);
    final isPosterLocked = activePose != null && activePose.isValid;

    if (_previousLocked == null) {
      _previousLocked = isPosterLocked;
    } else if (_previousLocked == true && !isPosterLocked) {
      _previousLocked = isPosterLocked;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerLostTransitionFeedback();
      });
    } else {
      _previousLocked = isPosterLocked;
    }

    final activePosterName = posterCatalog
        .where((poster) => poster.id == activePosterId)
        .map((poster) => poster.name)
        .cast<String?>()
        .firstWhere((name) => name != null, orElse: () => null) ??
        activePosterId;

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
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 90),
                opacity: _lostFlashVisible ? 1.0 : 0.0,
                child: Container(
                  color: _lostFlashStrong
                      ? const Color(0x99FF1744)
                      : const Color(0x66FF5252),
                ),
              ),
            ),
          ),
          Positioned.fill(
  child: Consumer(
    builder: (context, ref, _) {
      final pose = ref.watch(activePosterPoseProvider);
      return CanvasWidget(posterPose: pose);
    },
  ),
),
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
          Positioned(
            top: topInset + 58,
            left: 12,
            right: 12,
            child: IgnorePointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isPosterLocked
                      ? const Color(0xCC1B5E20)
                      : const Color(0xCCB71C1C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isPosterLocked
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFFEF5350),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPosterLocked ? Icons.lock : Icons.lock_open,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPosterLocked
                          ? 'Poster locked • desen permis pe $activePosterName'
                          : 'Poster lost • desen blocat până la re-detectare',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
