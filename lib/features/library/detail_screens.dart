import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/track_artwork.dart';
import '../../core/widgets/track_list.dart';
import '../../data/models/track.dart';
import '../../data/models/track_utils.dart';
import '../player/mini_player.dart';

/// Album page, addressed by the id of any track on the album.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.trackId});

  final int trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(tracksByIdProvider)[trackId];
    final album = seed == null
        ? null
        : ref
              .watch(albumsProvider)
              .where((a) => a.key == albumKey(seed.album, seed.artist))
              .firstOrNull;

    return Scaffold(
      appBar: AppBar(),
      bottomNavigationBar: const MiniPlayer(),
      body: album == null
          ? const EmptyState(
              icon: Icons.album_rounded,
              title: 'Album not found',
              message: 'It may have been removed from your device.',
            )
          : TrackListView(
              tracks: album.tracks,
              showAlbum: false,
              header: _DetailHeader(
                title: album.name,
                subtitle: album.artist,
                meta:
                    '${pluralize(album.tracks.length, 'song')} · ${formatTotalDuration(album.totalDuration)}',
                artworkPath: album.artworkPath,
                tracks: album.tracks,
                onSubtitleTap: () =>
                    context.push('/artist/${album.tracks.first.id}'),
              ),
            ),
    );
  }
}

/// Artist page, addressed by the id of any track by the artist.
class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.trackId});

  final int trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(tracksByIdProvider)[trackId];
    final artist = seed == null
        ? null
        : ref
              .watch(artistsProvider)
              .where(
                (a) =>
                    a.name.toLowerCase().trim() ==
                    seed.artist.toLowerCase().trim(),
              )
              .firstOrNull;

    if (artist == null) {
      return Scaffold(
        appBar: AppBar(),
        bottomNavigationBar: const MiniPlayer(),
        body: const EmptyState(
          icon: Icons.person_rounded,
          title: 'Artist not found',
        ),
      );
    }

    final tracks = sortTracks(artist.tracks, TrackSort.album);
    final albums = ref
        .watch(albumsProvider)
        .where(
          (a) => a.tracks.any(
            (t) =>
                t.artist.toLowerCase().trim() ==
                artist.name.toLowerCase().trim(),
          ),
        )
        .toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      bottomNavigationBar: const MiniPlayer(),
      body: TrackListView(
        tracks: tracks,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailHeader(
              title: artist.name,
              meta:
                  '${pluralize(artist.albumCount, 'album')} · ${pluralize(tracks.length, 'song')}',
              artworkPath: artist.artworkPath,
              tracks: tracks,
              round: true,
            ),
            if (albums.length > 1) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.lg,
                  Space.gutter,
                  Space.sm,
                ),
                child: Text('Albums', style: theme.textTheme.titleMedium),
              ),
              SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  itemCount: albums.length,
                  separatorBuilder: (_, _) => const SizedBox(width: Space.md),
                  itemBuilder: (_, i) {
                    final a = albums[i];
                    return InkWell(
                      borderRadius: Corners.mdAll,
                      onTap: () => context.push('/album/${a.tracks.first.id}'),
                      child: SizedBox(
                        width: 112,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TrackArtwork(
                              size: 112,
                              artworkPath: a.artworkPath,
                              seed: a.name,
                            ),
                            const SizedBox(height: Space.xs),
                            Text(
                              a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.lg,
                  Space.gutter,
                  Space.xs,
                ),
                child: Text('Songs', style: theme.textTheme.titleMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.title,
    required this.meta,
    required this.tracks,
    this.subtitle,
    this.artworkPath,
    this.round = false,
    this.onSubtitleTap,
  });

  final String title;
  final String? subtitle;
  final String meta;
  final String? artworkPath;
  final List<Track> tracks;
  final bool round;
  final VoidCallback? onSubtitleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final art = TrackArtwork(
      size: 160,
      artworkPath: artworkPath,
      seed: title,
      radius: round ? 80 : Corners.lg,
    );
    return Column(
      children: [
        const SizedBox(height: Space.sm),
        Center(child: art),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, 0),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
              if (subtitle != null)
                InkWell(
                  onTap: onSubtitleTap,
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              const SizedBox(height: Space.xs),
              Text(
                meta,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        PlayShuffleBar(tracks: tracks),
      ],
    );
  }
}
