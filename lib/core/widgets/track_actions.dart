import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/models/track.dart';
import '../../features/player/player_providers.dart';
import '../../features/playlists/playlist_sheets.dart';
import 'track_artwork.dart';

/// Bottom sheet with every action available for a track.
Future<void> showTrackActions(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  VoidCallback? onRemove,
  String removeLabel = 'Remove',
}) {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void say(String m) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (_, ref, _) {
        final isFav = ref.watch(isFavoriteProvider(track.id));
        final playback = ref.read(playbackControllerProvider);

        Widget item(IconData icon, String label, VoidCallback onTap) =>
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onTap();
              },
            );

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: TrackArtwork(
                    size: 48,
                    artworkPath: track.artworkPath,
                    seed: track.album,
                    radius: 8,
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${track.artist} · ${track.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(),
                item(Icons.playlist_play_rounded, 'Play next', () async {
                  await playback.playNext([track]);
                  say('Playing next');
                }),
                item(Icons.queue_music_rounded, 'Add to queue', () async {
                  await playback.addToQueue([track]);
                  say('Added to queue');
                }),
                item(Icons.playlist_add_rounded, 'Add to playlist', () {
                  showAddToPlaylistSheet(context, ref, [track]);
                }),
                item(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  isFav ? 'Remove from favorites' : 'Add to favorites',
                  () async {
                    final added = await ref
                        .read(favoritesRepositoryProvider)
                        .toggle(track.id);
                    say(
                      added ? 'Added to favorites' : 'Removed from favorites',
                    );
                  },
                ),
                item(Icons.album_rounded, 'Go to album', () {
                  router.push('/album/${track.id}');
                }),
                item(Icons.person_rounded, 'Go to artist', () {
                  router.push('/artist/${track.id}');
                }),
                if (onRemove != null)
                  item(
                    Icons.remove_circle_outline_rounded,
                    removeLabel,
                    onRemove,
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
