import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/canvas_provider.dart';
import '../providers/sticker_provider.dart';

class ToolBar extends ConsumerWidget {
  const ToolBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Simple toolbar with common actions. Buttons are enabled/disabled
    // based on providers (e.g. undo/redo availability).
    final canUndo = ref.watch(canUndoProvider);
    final canRedo = ref.watch(canRedoProvider);
    return Card(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            onPressed: canUndo ? () async => await ref.read(canvasProvider.notifier).undoLast() : null,
            icon: const Icon(Icons.undo)),
        IconButton(
            onPressed: canRedo ? () async => await ref.read(canvasProvider.notifier).redo() : null,
            icon: const Icon(Icons.redo)),
        IconButton(
            onPressed: () async {
              // open simple sticker picker
              final picked = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.emoji_emotions),
                      title: const Text('Heart sticker'),
                      onTap: () => Navigator.pop(context,
                          'https://upload.wikimedia.org/wikipedia/commons/1/15/Red_heart.svg'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.emoji_emotions),
                      title: const Text('Star sticker'),
                      onTap: () => Navigator.pop(context,
                          'https://upload.wikimedia.org/wikipedia/commons/4/44/Plain_Yellow_Star.svg'),
                    ),
                  ],
                ),
              );
              if (picked != null) {
                ref.read(selectedStickerProvider.notifier).state = picked;
                ref.read(isPlacingStickerProvider.notifier).state = true;
              }
            },
            icon: const Icon(Icons.emoji_food_beverage)),
      ]),
    );
  }
}
