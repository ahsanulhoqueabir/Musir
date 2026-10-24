import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/playlist.dart';
import 'playlist_artwork.dart';
import 'playlist_sheets.dart';

/// Deletes [playlist] and offers Undo, which recreates it with its tracks.
Future<void> deletePlaylistWithUndo(
  BuildContext context,
  WidgetRef ref,
  Playlist playlist,
) async {
  final repo = ref.read(playlistsRepositoryProvider);
  final ids = [for (final t in playlist.tracks) t.id];
  await repo.delete(playlist.id);
  if (!context.mounted) return;
  showMessage(
    context,
    'Deleted "${playlist.name}"',
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () async {
        final id = await repo.create(playlist.name, nowMs: playlist.createdMs);
        await repo.addTracks(id, ids);
      },
    ),
  );
}

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final repo = ref.read(playlistsRepositoryProvider);

    Future<void> create() async {
      final name = await promptPlaylistName(context);
      if (name != null) await repo.create(name);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            tooltip: 'New playlist',
            icon: const Icon(Icons.add_rounded),
            onPressed: create,
          ),
        ],
      ),
      body: playlists.isEmpty
          ? EmptyState(
              icon: Icons.queue_music_rounded,
              title: 'No playlists yet',
              message: 'Create a playlist to group songs your way.',
              actionLabel: 'New playlist',
              onAction: create,
            )
          : ListView.builder(
              key: const PageStorageKey('playlists'),
              itemCount: playlists.length,
              itemBuilder: (context, i) {
                final p = playlists[i];
                return ListTile(
                  onTap: () => context.push('/playlist/${p.id}'),
                  leading: PlaylistArtwork(playlist: p, size: 56),
                  title: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    p.trackCount == 0
                        ? 'Empty'
                        : '${pluralize(p.trackCount, 'song')} · ${formatTotalDuration(p.totalDuration)}',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Playlist options',
                    onSelected: (v) async {
                      if (v == 'rename') {
                        final name = await promptPlaylistName(
                          context,
                          title: 'Rename playlist',
                          confirmLabel: 'Save',
                          initial: p.name,
                        );
                        if (name != null) await repo.rename(p.id, name);
                      } else {
                        if (context.mounted) {
                          await deletePlaylistWithUndo(context, ref, p);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
