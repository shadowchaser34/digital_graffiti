import 'package:flutter/material.dart';
import '../models/poster_catalog.dart';
import '../models/poster_pose.dart';

class PosterGeometry {
  static Rect fallbackRect(Size size) {
    final width = size.width * 0.82;
    final height = size.height * 0.82;
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: width,
      height: height,
    );
  }

  static PosterPose fallbackPose(String posterId, Size size, {double confidence = 0.0}) {
    final rect = fallbackRect(size);
    return PosterPose(
      posterId: posterId,
      corners: [
        rect.topLeft,
        rect.topRight,
        rect.bottomRight,
        rect.bottomLeft,
      ],
      confidence: confidence,
    );
  }

  static Rect posterBounds(PosterPose pose, Size size) {
    if (!pose.isValid) {
      return fallbackRect(size);
    }

    double minX = pose.corners.first.dx;
    double maxX = pose.corners.first.dx;
    double minY = pose.corners.first.dy;
    double maxY = pose.corners.first.dy;
    for (final corner in pose.corners.skip(1)) {
      minX = corner.dx < minX ? corner.dx : minX;
      maxX = corner.dx > maxX ? corner.dx : maxX;
      minY = corner.dy < minY ? corner.dy : minY;
      maxY = corner.dy > maxY ? corner.dy : maxY;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static Path posterPath(PosterPose pose, Size size) {
    final corners = pose.isValid ? pose.corners : fallbackPose(defaultPosterId, size).corners;
    final path = Path()..moveTo(corners.first.dx, corners.first.dy);
    for (final corner in corners.skip(1)) {
      path.lineTo(corner.dx, corner.dy);
    }
    path.close();
    return path;
  }

  static Offset localToScreen(Offset local, PosterPose pose, Size size) {
    final corners = pose.isValid ? pose.corners : fallbackPose(defaultPosterId, size).corners;
    return _bilinear(local.dx, local.dy, corners);
  }

  static Offset? screenToLocal(Offset screenPoint, PosterPose pose, Size size) {
    final corners = pose.isValid ? pose.corners : fallbackPose(defaultPosterId, size).corners;
    if (!pose.isValid) {
      final rect = fallbackRect(size);
      if (!rect.contains(screenPoint)) {
        return null;
      }
      return Offset(
        (screenPoint.dx - rect.left) / rect.width,
        (screenPoint.dy - rect.top) / rect.height,
      );
    }

    var u = 0.5;
    var v = 0.5;
    for (var i = 0; i < 8; i++) {
      final position = _bilinear(u, v, corners);
      final diffX = position.dx - screenPoint.dx;
      final diffY = position.dy - screenPoint.dy;
      if (diffX.abs() + diffY.abs() < 0.5) {
        break;
      }

      final dU = _derivativeU(u, v, corners);
      final dV = _derivativeV(u, v, corners);
      final determinant = dU.dx * dV.dy - dU.dy * dV.dx;
      if (determinant.abs() < 1e-6) {
        break;
      }

      final deltaU = (diffX * dV.dy - diffY * dV.dx) / determinant;
      final deltaV = (dU.dx * diffY - dU.dy * diffX) / determinant;
      u -= deltaU;
      v -= deltaV;
    }

    if (u.isNaN || v.isNaN) {
      return null;
    }

    if (u < -0.05 || u > 1.05 || v < -0.05 || v > 1.05) {
      return null;
    }

    return Offset(u.clamp(0.0, 1.0), v.clamp(0.0, 1.0));
  }

  static bool isInsidePoster(Offset screenPoint, PosterPose pose, Size size) {
    return screenToLocal(screenPoint, pose, size) != null;
  }

  static Offset _bilinear(double u, double v, List<Offset> corners) {
    final topLeft = corners[0];
    final topRight = corners[1];
    final bottomRight = corners[2];
    final bottomLeft = corners[3];

    final x = (1 - u) * (1 - v) * topLeft.dx + u * (1 - v) * topRight.dx + u * v * bottomRight.dx + (1 - u) * v * bottomLeft.dx;
    final y = (1 - u) * (1 - v) * topLeft.dy + u * (1 - v) * topRight.dy + u * v * bottomRight.dy + (1 - u) * v * bottomLeft.dy;
    return Offset(x, y);
  }

  static Offset _derivativeU(double u, double v, List<Offset> corners) {
    final topLeft = corners[0];
    final topRight = corners[1];
    final bottomRight = corners[2];
    final bottomLeft = corners[3];

    final dx = (1 - v) * (topRight.dx - topLeft.dx) + v * (bottomRight.dx - bottomLeft.dx);
    final dy = (1 - v) * (topRight.dy - topLeft.dy) + v * (bottomRight.dy - bottomLeft.dy);
    return Offset(dx, dy);
  }

  static Offset _derivativeV(double u, double v, List<Offset> corners) {
    final topLeft = corners[0];
    final topRight = corners[1];
    final bottomRight = corners[2];
    final bottomLeft = corners[3];

    final dx = (1 - u) * (bottomLeft.dx - topLeft.dx) + u * (bottomRight.dx - topRight.dx);
    final dy = (1 - u) * (bottomLeft.dy - topLeft.dy) + u * (bottomRight.dy - topRight.dy);
    return Offset(dx, dy);
  }
}