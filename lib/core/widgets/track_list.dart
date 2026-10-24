import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../data/models/track.dart';
import '../../features/player/player_providers.dart';
import 'track_tile.dart';

final _random = Random();

/// Play / Shuffle buttons shown above a list of tracks.
class PlayShuffleBar extends ConsumerWidget {
  const PlayShuffleBar({super.key, required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.read(playbackControllerProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter,
        vertical: Space.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: tracks.isEmpty
                  ? null
                  : () => playback.playTracks(tracks, forceShuffle: false),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play'),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: tracks.isEmpty
                  ? null
                  : () => playback.playTracks(
                      tracks,
                      startIndex: _random.nextInt(tracks.length),
                      forceShuffle: true,
                    ),
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Shuffle'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lazy list of [TrackTile]s; tapping a row plays the list from that row.
class TrackListView extends ConsumerWidget {
  const TrackListView({
    super.key,
    required this.tracks,
    this.header,
    this.showAlbum = true,
    this.padding = EdgeInsets.zero,
    this.storageKey,
  });

  final List<Track> tracks;
  final Widget? header;
  final bool showAlbum;
  final EdgeInsets padding;
  final PageStorageKey<String>? storageKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.read(playbackControllerProvider);
    final offset = header == null ? 0 : 1;
    return ListView.builder(
      key: storageKey,
      padding: padding,
      itemCount: tracks.length + offset,
      itemBuilder: (context, i) {
        if (i < offset) return header!;
        final index = i - offset;
        final track = tracks[index];
        return TrackTile(
          key: ValueKey(track.id),
          track: track,
          showAlbum: showAlbum,
          onTap: () => playback.playTracks(tracks, startIndex: index),
        );
      },
    );
  }
}
