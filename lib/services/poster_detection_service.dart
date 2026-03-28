import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../models/poster_anchor.dart';

/// Result of comparing a camera frame against the poster reference catalog.
class PosterDetectionResult {
  final PosterAnchor poster;
  final double score;

  const PosterDetectionResult({required this.poster, required this.score});
}

class _PosterTemplate {
  final PosterAnchor poster;
  final List<int> pixels;

  const _PosterTemplate({required this.poster, required this.pixels});
}

/// Lightweight poster detector that matches live camera frames against the
/// poster reference images bundled in the app.
class PosterDetectionService {
  final List<PosterAnchor> catalog;
  final int sampleWidth;
  final int sampleHeight;

  PosterDetectionService({
    required this.catalog,
    this.sampleWidth = 48,
    this.sampleHeight = 68,
  });

  final List<_PosterTemplate> _templates = [];
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    for (final poster in catalog) {
      final bytes = await rootBundle.load(poster.referenceImagePath);
      final pixels = await _grayscaleFromPngBytes(bytes.buffer.asUint8List());
      _templates.add(_PosterTemplate(poster: poster, pixels: pixels));
    }

    _initialized = true;
  }

  Future<PosterDetectionResult?> detect(CameraImage image) async {
    if (!_initialized) {
      await initialize();
    }

    final framePixels = _grayscaleFromCameraImage(image);
    if (framePixels.isEmpty) {
      return null;
    }

    PosterDetectionResult? best;
    var bestScore = double.infinity;
    var secondBestScore = double.infinity;

    for (final template in _templates) {
      final score = _meanAbsoluteDifference(framePixels, template.pixels);
      if (score < bestScore) {
        secondBestScore = bestScore;
        bestScore = score;
        best = PosterDetectionResult(poster: template.poster, score: score);
      } else if (score < secondBestScore) {
        secondBestScore = score;
      }
    }

    if (best == null) {
      return null;
    }

    final hasMargin = (secondBestScore - bestScore) >= 0.02;
    if (bestScore <= 0.28 && hasMargin) {
      return best;
    }

    return null;
  }

  Future<List<int>> _grayscaleFromPngBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return List<int>.filled(sampleWidth * sampleHeight, 0);
    }

    return _downsampleRgba(
      byteData.buffer.asUint8List(),
      image.width,
      image.height,
      sampleWidth,
      sampleHeight,
    );
  }

  List<int> _grayscaleFromCameraImage(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;

    final cropWidth = (image.height * 0.707).round().clamp(1, image.width);
    final cropHeight = image.height.clamp(1, image.height);
    final cropLeft = ((image.width - cropWidth) / 2).round().clamp(0, image.width - cropWidth);

    return _downsampleLuma(
      bytes,
      bytesPerRow,
      cropLeft,
      0,
      cropWidth,
      cropHeight,
      sampleWidth,
      sampleHeight,
    );
  }

  List<int> _downsampleRgba(
    Uint8List bytes,
    int sourceWidth,
    int sourceHeight,
    int targetWidth,
    int targetHeight,
  ) {
    final result = List<int>.filled(targetWidth * targetHeight, 0);
    for (var y = 0; y < targetHeight; y++) {
      final sourceY = ((y + 0.5) * sourceHeight / targetHeight).floor().clamp(0, sourceHeight - 1);
      for (var x = 0; x < targetWidth; x++) {
        final sourceX = ((x + 0.5) * sourceWidth / targetWidth).floor().clamp(0, sourceWidth - 1);
        final index = (sourceY * sourceWidth + sourceX) * 4;
        final red = bytes[index];
        final green = bytes[index + 1];
        final blue = bytes[index + 2];
        result[y * targetWidth + x] = ((red * 299 + green * 587 + blue * 114) / 1000).round();
      }
    }
    return result;
  }

  List<int> _downsampleLuma(
    Uint8List bytes,
    int bytesPerRow,
    int cropLeft,
    int cropTop,
    int cropWidth,
    int cropHeight,
    int targetWidth,
    int targetHeight,
  ) {
    final result = List<int>.filled(targetWidth * targetHeight, 0);
    for (var y = 0; y < targetHeight; y++) {
      final sourceY = cropTop + ((y + 0.5) * cropHeight / targetHeight).floor().clamp(0, cropHeight - 1);
      for (var x = 0; x < targetWidth; x++) {
        final sourceX = cropLeft + ((x + 0.5) * cropWidth / targetWidth).floor().clamp(0, cropWidth - 1);
        result[y * targetWidth + x] = bytes[sourceY * bytesPerRow + sourceX];
      }
    }
    return result;
  }

  double _meanAbsoluteDifference(List<int> left, List<int> right) {
    final length = left.length < right.length ? left.length : right.length;
    if (length == 0) {
      return double.infinity;
    }

    var total = 0.0;
    for (var i = 0; i < length; i++) {
      total += (left[i] - right[i]).abs() / 255.0;
    }
    return total / length;
  }
}