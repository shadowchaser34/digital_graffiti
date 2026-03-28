import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Brush settings used by the drawing canvas and toolbar.
class BrushSettings {
  final Color color;
  final double thickness;

  const BrushSettings({
    this.color = Colors.black,
    this.thickness = 4.0,
  });

  BrushSettings copyWith({Color? color, double? thickness}) => BrushSettings(
        color: color ?? this.color,
        thickness: thickness ?? this.thickness,
      );
}

final brushSettingsProvider = StateProvider<BrushSettings>((ref) => const BrushSettings());