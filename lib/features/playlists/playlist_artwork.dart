import 'package:flutter/material.dart';

import '../../core/widgets/track_artwork.dart';
import '../../data/models/playlist.dart';

/// Playlist cover: single artwork, 2x2 collage, or a placeholder.
class PlaylistArtwork extends StatelessWidget {
  const PlaylistArtwork({
    super.key,
    required this.playlist,
    required this.size,
  });

  final Playlist playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final paths = playlist.collagePaths;
    if (paths.length < 4) {
      return TrackArtwork(
        size: size,
        artworkPath: paths.isEmpty ? null : paths.first,
        seed: playlist.name,
        radius: size > 80 ? 16 : 8,
        iconSize: size * 0.4,
      );
    }
    final half = size / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size > 80 ? 16 : 8),
      child: SizedBox.square(
        dimension: size,
        child: Column(
          children: [
            for (var r = 0; r < 2; r++)
              Row(
                children: [
                  for (var c = 0; c < 2; c++)
                    TrackArtwork(
                      size: half,
                      artworkPath: paths[r * 2 + c],
                      radius: 0,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
