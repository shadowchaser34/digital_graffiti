import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/brush_type.dart';
import '../providers/brush_provider.dart';
import '../providers/canvas_provider.dart';
import '../providers/sticker_provider.dart';

class ToolBar extends ConsumerWidget {
  const ToolBar({super.key});

  IconData _iconForBrush(BrushType brushType) {
    switch (brushType) {
      case BrushType.pen:
        return Icons.edit;
      case BrushType.marker:
        return Icons.brush;
      case BrushType.calligraphy:
        return Icons.draw;
      case BrushType.neon:
        return Icons.bolt;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canUndo = ref.watch(canUndoProvider);
    final canRedo = ref.watch(canRedoProvider);
    final brushSettings = ref.watch(brushSettingsProvider);
    final brushNotifier = ref.read(brushSettingsProvider.notifier);

    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: canUndo
                        ? () async => await ref.read(canvasProvider.notifier).undoLast()
                        : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    onPressed: canRedo
                        ? () async => await ref.read(canvasProvider.notifier).redo()
                        : null,
                    icon: const Icon(Icons.redo),
                  ),
                  IconButton(
                    onPressed: () async {
                      final picked = await showModalBottomSheet<String>(
                        context: context,
                        builder: (_) => ListView(
                          shrinkWrap: true,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.emoji_emotions),
                              title: const Text('Heart sticker'),
                              onTap: () => Navigator.pop(
                                context,
                                'https://upload.wikimedia.org/wikipedia/commons/1/15/Red_heart.svg',
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.emoji_emotions),
                              title: const Text('Star sticker'),
                              onTap: () => Navigator.pop(
                                context,
                                'https://upload.wikimedia.org/wikipedia/commons/4/44/Plain_Yellow_Star.svg',
                              ),
                            ),
                          ],
                        ),
                      );
                      if (picked != null) {
                        ref.read(selectedStickerProvider.notifier).state = picked;
                        ref.read(isPlacingStickerProvider.notifier).state = true;
                      }
                    },
                    icon: const Icon(Icons.emoji_food_beverage),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('Colors'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final color in brushPalette)
                    InkWell(
                      onTap: () => brushNotifier.setColor(color),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: brushSettings.color.value == color.value
                                ? Colors.white
                                : Colors.black54,
                            width: brushSettings.color.value == color.value ? 2.4 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Thickness: ${brushSettings.thickness.toStringAsFixed(1)}'),
              Slider(
                value: brushSettings.thickness,
                min: 1,
                max: 24,
                divisions: 23,
                onChanged: brushNotifier.setThickness,
              ),
              const SizedBox(height: 4),
              const Text('Brush'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final brushType in BrushType.values)
                    ChoiceChip(
                      label: Text(brushType.label),
                      avatar: Icon(_iconForBrush(brushType), size: 16),
                      selected: brushSettings.brushType == brushType,
                      onSelected: (_) => brushNotifier.setBrushType(brushType),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
