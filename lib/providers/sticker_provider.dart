import 'package:flutter_riverpod/flutter_riverpod.dart';

// Holds the currently selected sticker URL (or asset path). Null means no selection.
final selectedStickerProvider = StateProvider<String?>((ref) => null);

// Whether the app is currently in 'placing' mode
final isPlacingStickerProvider = StateProvider<bool>((ref) => false);
