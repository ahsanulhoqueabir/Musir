import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/track_artwork.dart';
import 'player_providers.dart';

/// The live play queue: tap to jump, drag to reorder, swipe to remove.
Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const _QueueSheet(),
  );
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerStateProvider);
    final playback = ref.read(playbackControllerProvider);
    final theme = Theme.of(context);
    final queue = state.queue;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.sm,
                Space.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Queue', style: theme.textTheme.titleLarge),
                        Text(
                          '${pluralize(queue.length, 'song')}'
                          '${state.shuffle ? ' · shuffled' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: queue.isEmpty
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await playback.clearQueue();
                          },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: queue.isEmpty
                  ? const Center(child: Text('The queue is empty.'))
                  : ReorderableListView.builder(
                      scrollController: scrollController,
                      buildDefaultDragHandles: false,
                      itemCount: queue.length,
                      onReorderItem: playback.move,
                      itemBuilder: (context, i) {
                        final entry = queue[i];
                        final track = entry.track;
                        final isCurrent = i == state.currentIndex;
                        return Dismissible(
                          key: ValueKey(entry.uid),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: theme.colorScheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: Space.xl),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          onDismissed: (_) => playback.removeAt(i),
                          child: ListTile(
                            onTap: () => playback.skipToIndex(i),
                            leading: TrackArtwork(
                              size: Sizes.trackArtwork,
                              artworkPath: track.artworkPath,
                              seed: track.album,
                              radius: Corners.sm,
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : null,
                                fontWeight: isCurrent ? FontWeight.w700 : null,
                              ),
                            ),
                            subtitle: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCurrent)
                                  Icon(
                                    state.playing
                                        ? Icons.equalizer_rounded
                                        : Icons.pause_rounded,
                                    color: theme.colorScheme.primary,
                                    semanticLabel: 'Now playing',
                                  ),
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.all(Space.md),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      semanticLabel: 'Reorder',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
