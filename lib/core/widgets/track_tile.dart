import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../data/models/track.dart';
import '../../features/player/player_providers.dart';
import '../utils/format.dart';
import 'track_actions.dart';
import 'track_artwork.dart';

/// One row in any song list. Highlights the track that is playing.
class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.showAlbum = true,
    this.onRemove,
    this.removeLabel = 'Remove',
    this.trailing,
    this.dragIndex,
  });

  final Track track;
  final VoidCallback onTap;
  final bool showAlbum;

  /// When set, the actions menu gets a remove entry (playlist/queue contexts).
  final VoidCallback? onRemove;
  final String removeLabel;

  /// Replaces the default duration + menu (e.g. a drag handle).
  final Widget? trailing;

  /// When set, shows a drag handle for a surrounding [ReorderableListView].
  final int? dragIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCurrent = ref.watch(
      currentTrackProvider.select((t) => t?.id == track.id),
    );
    final playing = isCurrent && ref.watch(isPlayingProvider);
    final color = isCurrent ? theme.colorScheme.primary : null;

    return ListTile(
      onTap: onTap,
      leading: Stack(
        alignment: Alignment.center,
        children: [
          TrackArtwork(
            size: Sizes.trackArtwork,
            artworkPath: track.artworkPath,
            seed: track.album,
            radius: Corners.sm,
          ),
          if (isCurrent)
            Container(
              width: Sizes.trackArtwork,
              height: Sizes.trackArtwork,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: Corners.smAll,
              ),
              child: Icon(
                playing ? Icons.equalizer_rounded : Icons.pause_rounded,
                color: Colors.white,
                semanticLabel: playing ? 'Playing' : 'Paused',
              ),
            ),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: isCurrent ? FontWeight.w700 : null,
        ),
      ),
      subtitle: Text(
        showAlbum ? '${track.artist} · ${track.album}' : track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (track.durationMs > 0)
                Text(
                  formatDuration(track.duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              IconButton(
                tooltip: 'More options for ${track.title}',
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => showTrackActions(
                  context,
                  ref,
                  track,
                  onRemove: onRemove,
                  removeLabel: removeLabel,
                ),
              ),
              if (dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex!,
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
    );
  }
}
