import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brush_type.dart';

class BrushSettings {
  final Color color;
  final double thickness;
  final BrushType brushType;

  const BrushSettings({
    required this.color,
    required this.thickness,
    required this.brushType,
  });

  BrushSettings copyWith({
    Color? color,
    double? thickness,
    BrushType? brushType,
  }) {
    return BrushSettings(
      color: color ?? this.color,
      thickness: thickness ?? this.thickness,
      brushType: brushType ?? this.brushType,
    );
  }
}

const List<Color> brushPalette = [
  Color(0xFFE53935),
  Color(0xFFFF6F00),
  Color(0xFFFFEB3B),
  Color(0xFF43A047),
  Color(0xFF00ACC1),
  Color(0xFF1E88E5),
  Color(0xFF3949AB),
  Color(0xFF8E24AA),
  Color(0xFFD81B60),
  Color(0xFF6D4C41),
  Color(0xFFFFFFFF),
  Color(0xFF111111),
];

final brushSettingsProvider =
    StateNotifierProvider<BrushSettingsNotifier, BrushSettings>((ref) {
  return BrushSettingsNotifier();
});

class BrushSettingsNotifier extends StateNotifier<BrushSettings> {
  BrushSettingsNotifier()
    : super(
        const BrushSettings(
          color: Color(0xFFE53935),
          thickness: 4,
          brushType: BrushType.pen,
        ),
      );

  void setColor(Color color) {
    state = state.copyWith(color: color);
  }

  void setThickness(double thickness) {
    state = state.copyWith(thickness: thickness.clamp(1.0, 24.0));
  }

  void setBrushType(BrushType brushType) {
    state = state.copyWith(brushType: brushType);
  }
}