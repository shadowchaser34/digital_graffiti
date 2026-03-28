import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poster_anchor.dart';
import '../providers/brush_provider.dart';
import '../providers/canvas_provider.dart';
import '../providers/poster_provider.dart';
import '../providers/sticker_provider.dart';

class ToolBar extends ConsumerWidget {
  const ToolBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = ref.watch(activePosterProvider);
    final canvasState = ref.watch(canvasProvider(poster.id));
    final brush = ref.watch(brushSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: 'Undo',
              onPressed: canvasState.canUndo
                  ? () async => await ref.read(canvasProvider(poster.id).notifier).undoLast()
                  : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Redo',
              onPressed: canvasState.canRedo
                  ? () async => await ref.read(canvasProvider(poster.id).notifier).redo()
                  : null,
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              tooltip: 'Brush color',
              onPressed: () async {
                final chosen = await showModalBottomSheet<Color>(
                  context: context,
                  builder: (sheetContext) {
                    final colors = <Color>[
                      Colors.black,
                      Colors.red,
                      Colors.blue,
                      Colors.green,
                      Colors.orange,
                      Colors.purple,
                      Colors.pink,
                      Colors.yellow.shade800,
                    ];
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: colors
                              .map(
                                (color) => InkWell(
                                  onTap: () => Navigator.pop(sheetContext, color),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    );
                  },
                );
                if (chosen != null) {
                  ref.read(brushSettingsProvider.notifier).state = brush.copyWith(color: chosen);
                }
              },
              icon: Icon(Icons.palette, color: brush.color),
            ),
            IconButton(
              tooltip: 'Brush thickness',
              onPressed: () async {
                final chosen = await showModalBottomSheet<double>(
                  context: context,
                  builder: (sheetContext) {
                    double value = brush.thickness;
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Brush thickness: ${value.toStringAsFixed(1)} px'),
                                Slider(
                                  min: 1,
                                  max: 24,
                                  divisions: 23,
                                  value: value,
                                  onChanged: (newValue) => setState(() => value = newValue),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: () => Navigator.pop(sheetContext, value),
                                    child: const Text('Apply'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
                if (chosen != null) {
                  ref.read(brushSettingsProvider.notifier).state = brush.copyWith(thickness: chosen);
                }
              },
              icon: const Icon(Icons.linear_scale),
            ),
            IconButton(
              tooltip: 'Select poster',
              onPressed: () async {
                final picked = await showModalBottomSheet<PosterAnchor>(
                  context: context,
                  builder: (sheetContext) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: posterCatalog
                          .map(
                            (item) => ListTile(
                              leading: const Icon(Icons.image),
                              title: Text(item.name),
                              subtitle: Text(item.referenceImagePath),
                              onTap: () => Navigator.pop(sheetContext, item),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
                if (picked != null) {
                  ref.read(activePosterProvider.notifier).state = picked;
                }
              },
              icon: const Icon(Icons.wallpaper),
            ),
            IconButton(
              tooltip: 'Add sticker',
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
              icon: const Icon(Icons.sticky_note_2_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
