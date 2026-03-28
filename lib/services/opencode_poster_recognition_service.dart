import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../models/poster_catalog.dart';
import '../models/poster_pose.dart';

class _PosterTemplate {
  final String posterId;
  final List<int> grayscale;

  const _PosterTemplate({required this.posterId, required this.grayscale});
}

class _DecodedFrame {
  final Uint8List bytes;
  final int width;
  final int height;

  const _DecodedFrame({
    required this.bytes,
    required this.width,
    required this.height,
  });
}

class _TemplateMatch {
  final String posterId;
  final double score;
  final double margin;

  const _TemplateMatch({
    required this.posterId,
    required this.score,
    required this.margin,
  });
}

class OpenCodePosterRecognitionService {
  final Uri? endpoint;
  final String apiKey;
  final Duration timeout;

  final List<_PosterTemplate> _templates = <_PosterTemplate>[];
  bool _templatesLoaded = false;

  static const int _sampleWidth = 56;
  static const int _sampleHeight = 80;
  static const double _maxTemplateScore = 0.20;
  static const double _minTemplateMargin = 0.03;

  OpenCodePosterRecognitionService({
    required this.endpoint,
    required this.apiKey,
    required this.timeout,
  });

  factory OpenCodePosterRecognitionService.fromEnvironment() {
    final endpointValue = Platform.environment['OPENCODE_POSTER_ENDPOINT'] ??
        const String.fromEnvironment('OPENCODE_POSTER_ENDPOINT', defaultValue: '');
    final apiKey = Platform.environment['OPENCODE_POSTER_API_KEY'] ??
        const String.fromEnvironment('OPENCODE_POSTER_API_KEY', defaultValue: '');
    final timeoutValue = Platform.environment['OPENCODE_POSTER_TIMEOUT_MS'] ??
        const String.fromEnvironment('OPENCODE_POSTER_TIMEOUT_MS', defaultValue: '6000');
    final parsedEndpoint = endpointValue.isEmpty ? null : Uri.tryParse(endpointValue);
    final timeoutMs = int.tryParse(timeoutValue) ?? 6000;

    return OpenCodePosterRecognitionService(
      endpoint: parsedEndpoint,
      apiKey: apiKey,
      timeout: Duration(milliseconds: timeoutMs),
    );
  }

  bool get isConfigured => endpoint != null;

  Future<PosterPose?> recognizePoster({
    required Uint8List frameBytes,
    required List<PosterCatalogEntry> candidates,
    required Size viewportSize,
  }) async {
    if (isConfigured) {
      final remote = await _recognizeWithRemote(frameBytes: frameBytes, candidates: candidates);
      if (remote != null && remote.isValid) {
        return remote;
      }
    }

    return _recognizeLocally(
      frameBytes: frameBytes,
      candidates: candidates,
      viewportSize: viewportSize,
    );
  }

  Future<PosterPose?> recognizePosterFromLumaFrame({
    required Uint8List lumaBytes,
    required int frameWidth,
    required int frameHeight,
    required List<PosterCatalogEntry> candidates,
    required Size viewportSize,
  }) async {
    if (lumaBytes.isEmpty || frameWidth <= 0 || frameHeight <= 0) {
      return null;
    }

    final rgba = _lumaToRgba(lumaBytes);
    return _recognizeLocallyFromRgba(
      rgbaBytes: rgba,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      candidates: candidates,
      viewportSize: viewportSize,
    );
  }

  Future<PosterPose?> _recognizeWithRemote({
    required Uint8List frameBytes,
    required List<PosterCatalogEntry> candidates,
  }) async {
    final uri = endpoint;
    if (uri == null) {
      return null;
    }

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (apiKey.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
        request.headers.set('X-OpenCode-Api-Key', apiKey);
      }

      final payload = <String, dynamic>{
        'frameBase64': base64Encode(frameBytes),
        'candidates': candidates.map((candidate) => candidate.toMap()).toList(),
      };
      request.write(jsonEncode(payload));

      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300 || body.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return _parsePose(decoded);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _ensureTemplatesLoaded(List<PosterCatalogEntry> candidates) async {
    if (_templatesLoaded) {
      return;
    }

    _templatesLoaded = true;
    for (final candidate in candidates) {
      final path = candidate.referenceImagePath;
      if (path == null || path.isEmpty) {
        continue;
      }

      try {
        ByteData? bytes;
        try {
          bytes = await rootBundle.load(path);
        } catch (_) {
          final altPaths = <String>{
            path.replaceAll('.png', '.jpg'),
            path.replaceAll('.png', '.jpeg'),
            path.replaceAll('.jpg', '.png'),
            path.replaceAll('.jpeg', '.png'),
          };
          for (final alt in altPaths) {
            if (alt == path) continue;
            try {
              bytes = await rootBundle.load(alt);
              break;
            } catch (_) {
              // Try next extension variant.
            }
          }
        }

        if (bytes != null) {
          final pixels = await _grayscaleFromEncoded(bytes.buffer.asUint8List());
          _templates.add(_PosterTemplate(posterId: candidate.id, grayscale: pixels));
        }
      } catch (_) {
        // Some poster assets may still be unavailable in local builds.
      }
    }
  }

  Future<PosterPose?> _recognizeLocally({
    required Uint8List frameBytes,
    required List<PosterCatalogEntry> candidates,
    required Size viewportSize,
  }) async {
    try {
      await _ensureTemplatesLoaded(candidates);

      final decoded = await _decodeRgba(frameBytes);
      if (decoded == null) {
        return null;
      }

      return _recognizeLocallyFromRgba(
        rgbaBytes: decoded.bytes,
        frameWidth: decoded.width,
        frameHeight: decoded.height,
        candidates: candidates,
        viewportSize: viewportSize,
      );
    } catch (_) {
      return null;
    }
  }

  Future<PosterPose?> _recognizeLocallyFromRgba({
    required Uint8List rgbaBytes,
    required int frameWidth,
    required int frameHeight,
    required List<PosterCatalogEntry> candidates,
    required Size viewportSize,
  }) async {
    try {
      await _ensureTemplatesLoaded(candidates);

      final bounds = _detectPosterBounds(rgbaBytes, frameWidth, frameHeight);
      if (bounds == null) {
        return null;
      }

      final match = _matchTemplate(
        rgbaBytes,
        frameWidth,
        frameHeight,
        bounds,
        candidates,
      );

      if (match == null) {
        return null;
      }

      final corners = _mapImageRectToViewport(bounds, frameWidth, frameHeight, viewportSize);

      return PosterPose(
        posterId: match.posterId,
        corners: corners,
        confidence: (1.0 - match.score).clamp(0.0, 1.0),
      );
    } catch (_) {
      return null;
    }
  }

  Uint8List _lumaToRgba(Uint8List lumaBytes) {
    final rgba = Uint8List(lumaBytes.length * 4);
    var dst = 0;
    for (final y in lumaBytes) {
      rgba[dst] = y;
      rgba[dst + 1] = y;
      rgba[dst + 2] = y;
      rgba[dst + 3] = 255;
      dst += 4;
    }
    return rgba;
  }

  Future<_DecodedFrame?> _decodeRgba(Uint8List encodedBytes) async {
    final codec = await ui.instantiateImageCodec(encodedBytes, targetWidth: 320);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) {
      return null;
    }

    return _DecodedFrame(
      bytes: data.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
  }

  Rect? _detectPosterBounds(Uint8List rgba, int width, int height) {
    if (width < 20 || height < 20) {
      return null;
    }

    final luma = List<int>.filled(width * height, 0);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        final r = rgba[i];
        final g = rgba[i + 1];
        final b = rgba[i + 2];
        luma[y * width + x] = ((r * 299 + g * 587 + b * 114) / 1000).round();
      }
    }

    var totalGrad = 0.0;
    var samples = 0;
    for (var y = 1; y < height - 1; y += 2) {
      for (var x = 1; x < width - 1; x += 2) {
        final gx = (luma[y * width + (x + 1)] - luma[y * width + (x - 1)]).abs();
        final gy = (luma[(y + 1) * width + x] - luma[(y - 1) * width + x]).abs();
        totalGrad += gx + gy;
        samples++;
      }
    }

    if (samples == 0) {
      return null;
    }

    final threshold = (totalGrad / samples) * 1.8;
    var minX = width.toDouble();
    var minY = height.toDouble();
    var maxX = 0.0;
    var maxY = 0.0;
    var edgeCount = 0;

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final gx = (luma[y * width + (x + 1)] - luma[y * width + (x - 1)]).abs();
        final gy = (luma[(y + 1) * width + x] - luma[(y - 1) * width + x]).abs();
        final grad = gx + gy;
        if (grad >= threshold) {
          edgeCount++;
          if (x < minX) minX = x.toDouble();
          if (x > maxX) maxX = x.toDouble();
          if (y < minY) minY = y.toDouble();
          if (y > maxY) maxY = y.toDouble();
        }
      }
    }

    if (edgeCount < 200) {
      return null;
    }

    final rect = Rect.fromLTRB(minX, minY, maxX, maxY);
    final areaRatio = rect.width * rect.height / (width * height);
    if (areaRatio < 0.08) {
      return null;
    }

    final padX = rect.width * 0.07;
    final padY = rect.height * 0.07;
    return Rect.fromLTRB(
      math.max(0.0, rect.left - padX),
      math.max(0.0, rect.top - padY),
      math.min((width - 1).toDouble(), rect.right + padX),
      math.min((height - 1).toDouble(), rect.bottom + padY),
    );
  }

  _TemplateMatch? _matchTemplate(
    Uint8List rgba,
    int width,
    int height,
    Rect bounds,
    List<PosterCatalogEntry> candidates,
  ) {
    if (_templates.isEmpty) {
      return null;
    }

    final crop = _downsampleCropRgba(rgba, width, height, bounds, _sampleWidth, _sampleHeight);

    var bestId = _templates.first.posterId;
    var bestScore = double.infinity;
    var secondScore = double.infinity;

    for (final template in _templates) {
      final score = _meanAbsDiff(crop, template.grayscale);
      if (score < bestScore) {
        secondScore = bestScore;
        bestScore = score;
        bestId = template.posterId;
      } else if (score < secondScore) {
        secondScore = score;
      }
    }

    final margin = secondScore - bestScore;
    if (bestScore <= _maxTemplateScore && margin >= _minTemplateMargin) {
      return _TemplateMatch(
        posterId: bestId,
        score: bestScore,
        margin: margin,
      );
    }

    return null;
  }

  Future<List<int>> _grayscaleFromEncoded(Uint8List encoded) async {
    final codec = await ui.instantiateImageCodec(encoded);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) {
      return List<int>.filled(_sampleWidth * _sampleHeight, 0);
    }

    return _downsampleRgba(
      bytes.buffer.asUint8List(),
      image.width,
      image.height,
      _sampleWidth,
      _sampleHeight,
    );
  }

  List<int> _downsampleRgba(Uint8List rgba, int srcW, int srcH, int dstW, int dstH) {
    final out = List<int>.filled(dstW * dstH, 0);
    for (var y = 0; y < dstH; y++) {
      final sy = ((y + 0.5) * srcH / dstH).floor().clamp(0, srcH - 1);
      for (var x = 0; x < dstW; x++) {
        final sx = ((x + 0.5) * srcW / dstW).floor().clamp(0, srcW - 1);
        final i = (sy * srcW + sx) * 4;
        out[y * dstW + x] = ((rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) / 1000).round();
      }
    }
    return out;
  }

  List<int> _downsampleCropRgba(Uint8List rgba, int srcW, int srcH, Rect crop, int dstW, int dstH) {
    final out = List<int>.filled(dstW * dstH, 0);
    final left = crop.left.round().clamp(0, srcW - 1);
    final top = crop.top.round().clamp(0, srcH - 1);
    final widthC = crop.width.round().clamp(1, srcW - left);
    final heightC = crop.height.round().clamp(1, srcH - top);

    for (var y = 0; y < dstH; y++) {
      final sy = top + ((y + 0.5) * heightC / dstH).floor().clamp(0, heightC - 1);
      for (var x = 0; x < dstW; x++) {
        final sx = left + ((x + 0.5) * widthC / dstW).floor().clamp(0, widthC - 1);
        final i = (sy * srcW + sx) * 4;
        out[y * dstW + x] = ((rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) / 1000).round();
      }
    }

    return out;
  }

  double _meanAbsDiff(List<int> a, List<int> b) {
    final n = math.min(a.length, b.length);
    if (n == 0) {
      return double.infinity;
    }

    var total = 0.0;
    for (var i = 0; i < n; i++) {
      total += (a[i] - b[i]).abs() / 255.0;
    }
    return total / n;
  }

  List<Offset> _mapImageRectToViewport(Rect imageRect, int imageW, int imageH, Size viewport) {
    Offset mapPoint(double x, double y) {
      if (imageH >= imageW) {
        return Offset(x / imageW * viewport.width, y / imageH * viewport.height);
      }

      final nx = x / imageW;
      final ny = y / imageH;
      return Offset((1.0 - ny) * viewport.width, nx * viewport.height);
    }

    return <Offset>[
      mapPoint(imageRect.left, imageRect.top),
      mapPoint(imageRect.right, imageRect.top),
      mapPoint(imageRect.right, imageRect.bottom),
      mapPoint(imageRect.left, imageRect.bottom),
    ];
  }

  PosterPose? _parsePose(Map<String, dynamic> response) {
    final poseMap = response['pose'];
    if (poseMap is Map<String, dynamic>) {
      final pose = PosterPose.fromMap(poseMap);
      if (pose.isValid) {
        return pose;
      }
    }

    final corners = response['corners'];
    if (corners is List && corners.length >= 4) {
      final posterId = (response['posterId'] as String?) ?? defaultPosterId;
      final parsedCorners = <Offset>[];
      for (final corner in corners.take(4)) {
        if (corner is Map<String, dynamic>) {
          parsedCorners.add(Offset((corner['x'] as num).toDouble(), (corner['y'] as num).toDouble()));
        } else if (corner is List && corner.length >= 2) {
          parsedCorners.add(Offset((corner[0] as num).toDouble(), (corner[1] as num).toDouble()));
        }
      }

      if (parsedCorners.length == 4) {
        return PosterPose(
          posterId: posterId,
          corners: parsedCorners,
          confidence: (response['confidence'] as num?)?.toDouble() ?? 0.0,
        );
      }
    }

    return null;
  }
}