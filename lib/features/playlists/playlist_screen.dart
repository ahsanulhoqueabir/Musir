import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/track_list.dart';
import '../../core/widgets/track_tile.dart';
import '../player/mini_player.dart';
import '../player/player_providers.dart';
import 'playlist_artwork.dart';
import 'playlist_sheets.dart';
import 'playlists_screen.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(playlistProvider(playlistId));
    final repo = ref.read(playlistsRepositoryProvider);
    final playback = ref.read(playbackControllerProvider);
    final theme = Theme.of(context);

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        bottomNavigationBar: const MiniPlayer(),
        body: const EmptyState(
          icon: Icons.queue_music_rounded,
          title: 'Playlist not found',
        ),
      );
    }
    final tracks = playlist.tracks;

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Playlist options',
            onSelected: (v) async {
              if (v == 'rename') {
                final name = await promptPlaylistName(
                  context,
                  title: 'Rename playlist',
                  confirmLabel: 'Save',
                  initial: playlist.name,
                );
                if (name != null) await repo.rename(playlist.id, name);
              } else if (v == 'queue') {
                await playback.addToQueue(tracks);
                if (context.mounted) showMessage(context, 'Added to queue');
              } else {
                await deletePlaylistWithUndo(context, ref, playlist);
                if (context.mounted) context.pop();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              if (tracks.isNotEmpty)
                const PopupMenuItem(
                  value: 'queue',
                  child: Text('Add to queue'),
                ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            child: Column(
              children: [
                PlaylistArtwork(playlist: playlist, size: 160),
                const SizedBox(height: Space.lg),
                Text(
                  playlist.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  tracks.isEmpty
                      ? 'Empty'
                      : '${pluralize(playlist.trackCount, 'song')} · ${formatTotalDuration(playlist.totalDuration)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PlayShuffleBar(tracks: tracks),
          Expanded(
            child: tracks.isEmpty
                ? const EmptyState(
                    icon: Icons.library_add_rounded,
                    title: 'This playlist is empty',
                    message: 'Use "Add to playlist" in any song\'s menu.',
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: tracks.length,
                    onReorderItem: (from, to) =>
                        repo.reorder(playlist.id, from, to),
                    itemBuilder: (context, i) {
                      final t = tracks[i];
                      return TrackTile(
                        key: ValueKey(t.id),
                        track: t,
                        dragIndex: i,
                        removeLabel: 'Remove from playlist',
                        onRemove: () => repo.removeTrack(playlist.id, t.id),
                        onTap: () => playback.playTracks(tracks, startIndex: i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
