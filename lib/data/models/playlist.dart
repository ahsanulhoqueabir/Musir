import 'package:flutter/foundation.dart';

import 'track.dart';

@immutable
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdMs,
    required this.tracks,
  });

  final int id;
  final String name;
  final int createdMs;

  /// Tracks in playlist order. Entries whose file left the library are gone.
  final List<Track> tracks;

  int get trackCount => tracks.length;

  Duration get totalDuration =>
      Duration(milliseconds: tracks.fold(0, (sum, t) => sum + t.durationMs));

  /// Up to four distinct artworks for a collage.
  List<String> get collagePaths {
    final seen = <String>{};
    for (final t in tracks) {
      final a = t.artworkPath;
      if (a != null) seen.add(a);
      if (seen.length == 4) break;
    }
    return seen.toList();
  }
}
