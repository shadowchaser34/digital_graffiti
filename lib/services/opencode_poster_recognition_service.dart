import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/poster_catalog.dart';
import '../models/poster_pose.dart';

class OpenCodePosterRecognitionService {
  final Uri? endpoint;
  final String apiKey;
  final Duration timeout;

  const OpenCodePosterRecognitionService({
    required this.endpoint,
    required this.apiKey,
    required this.timeout,
  });

  factory OpenCodePosterRecognitionService.fromEnvironment() {
    final endpointValue = Platform.environment['OPENCODE_POSTER_ENDPOINT'] ?? const String.fromEnvironment('OPENCODE_POSTER_ENDPOINT', defaultValue: '');
    final apiKey = Platform.environment['OPENCODE_POSTER_API_KEY'] ?? const String.fromEnvironment('OPENCODE_POSTER_API_KEY', defaultValue: '');
    final timeoutValue = Platform.environment['OPENCODE_POSTER_TIMEOUT_MS'] ?? const String.fromEnvironment('OPENCODE_POSTER_TIMEOUT_MS', defaultValue: '6000');
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
        final pose = _parsePose(decoded);
        if (pose != null) {
          return pose;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
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