import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/format.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import 'playlist_artwork.dart';

/// Asks for a playlist name. Returns null if cancelled or blank.
Future<String?> promptPlaylistName(
  BuildContext context, {
  String title = 'New playlist',
  String confirmLabel = 'Create',
  String initial = '',
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      void submit() {
        final name = controller.text.trim();
        Navigator.of(dialogContext).pop(name.isEmpty ? null : name);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Playlist name'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: submit, child: Text(confirmLabel)),
        ],
      );
    },
  );
}

/// Lets the user pick (or create) a playlist for [tracks].
Future<void> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<Track> tracks,
) {
  final repo = ref.read(playlistsRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  void say(String m) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> addTo(Playlist p) async {
    final added = await repo.addTracks(p.id, [for (final t in tracks) t.id]);
    if (added == 0) {
      say('Already in ${p.name}');
    } else {
      say('Added ${pluralize(added, 'song')} to ${p.name}');
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (_, ref, _) {
        final playlists = ref.watch(playlistsProvider);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('New playlist'),
                  onTap: () async {
                    final name = await promptPlaylistName(sheetContext);
                    if (name == null) return;
                    final id = await repo.create(name);
                    final added = await repo.addTracks(id, [
                      for (final t in tracks) t.id,
                    ]);
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    say('Added ${pluralize(added, 'song')} to $name');
                  },
                ),
                const Divider(),
                Flexible(
                  child: playlists.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No playlists yet.'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: playlists.length,
                          itemBuilder: (_, i) {
                            final p = playlists[i];
                            return ListTile(
                              leading: PlaylistArtwork(playlist: p, size: 48),
                              title: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(pluralize(p.trackCount, 'song')),
                              onTap: () async {
                                Navigator.of(sheetContext).pop();
                                await addTo(p);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
