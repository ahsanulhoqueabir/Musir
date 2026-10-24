import 'package:path/path.dart' as p;

import 'track.dart';

enum TrackSort {
  title('Title'),
  artist('Artist'),
  album('Album'),
  recentlyAdded('Recently added'),
  duration('Duration');

  const TrackSort(this.label);
  final String label;
}

String _norm(String s) => s.toLowerCase().trim();

/// Sorts a copy of [tracks]. Ties fall back to title so order is stable.
List<Track> sortTracks(Iterable<Track> tracks, TrackSort sort) {
  int byTitle(Track a, Track b) => _norm(a.title).compareTo(_norm(b.title));
  final list = tracks.toList();
  switch (sort) {
    case TrackSort.title:
      list.sort(byTitle);
    case TrackSort.artist:
      list.sort((a, b) {
        final c = _norm(a.artist).compareTo(_norm(b.artist));
        return c != 0 ? c : byTitle(a, b);
      });
    case TrackSort.album:
      list.sort((a, b) {
        final c = _norm(a.album).compareTo(_norm(b.album));
        if (c != 0) return c;
        final n = (a.trackNumber ?? 1 << 30).compareTo(
          b.trackNumber ?? 1 << 30,
        );
        return n != 0 ? n : byTitle(a, b);
      });
    case TrackSort.recentlyAdded:
      list.sort((a, b) {
        final c = b.addedMs.compareTo(a.addedMs);
        return c != 0 ? c : byTitle(a, b);
      });
    case TrackSort.duration:
      list.sort((a, b) {
        final c = a.durationMs.compareTo(b.durationMs);
        return c != 0 ? c : byTitle(a, b);
      });
  }
  return list;
}

/// Case-insensitive match on title, artist or album. Every whitespace
/// separated term must match somewhere.
List<Track> searchTracks(Iterable<Track> tracks, String query) {
  final terms = _norm(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (terms.isEmpty) return const [];
  return tracks.where((t) {
    final hay = '${_norm(t.title)}\n${_norm(t.artist)}\n${_norm(t.album)}';
    return terms.every(hay.contains);
  }).toList();
}

/// Hides the same recording stored twice (same tags, duration and size).
/// The copy with the lowest id wins so favorites on it keep working.
List<Track> dedupeTracks(List<Track> tracks) {
  final seen = <String>{};
  final sorted = [...tracks]..sort((a, b) => a.id.compareTo(b.id));
  final keep = <int>{};
  for (final t in sorted) {
    final key =
        '${_norm(t.title)}|${_norm(t.artist)}|${_norm(t.album)}|'
        '${(t.durationMs / 1000).round()}|${t.sizeBytes}';
    if (seen.add(key)) keep.add(t.id);
  }
  return [
    for (final t in tracks)
      if (keep.contains(t.id)) t,
  ];
}

class AlbumGroup {
  AlbumGroup({required this.name, required this.tracks});

  final String name;
  final List<Track> tracks;

  String get key => albumKeyFor(tracks.first);

  /// The album artist tag if any track has one; otherwise the artist who
  /// dominates the album, or "Various artists" for a mixed bag.
  String get artist {
    for (final t in tracks) {
      if (t.albumArtist != null) return t.albumArtist!;
    }
    final counts = <String, int>{};
    for (final t in tracks) {
      counts[t.artist] = (counts[t.artist] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return top.value * 10 >= tracks.length * 6 ? top.key : 'Various artists';
  }

  String? get artworkPath {
    for (final t in tracks) {
      if (t.artworkPath != null) return t.artworkPath;
    }
    return null;
  }

  Duration get totalDuration =>
      Duration(milliseconds: tracks.fold(0, (s, t) => s + t.durationMs));
}

class ArtistGroup {
  ArtistGroup({required this.name, required this.tracks});

  final String name;
  final List<Track> tracks;

  int get albumCount => tracks.map((t) => t.album).toSet().length;

  String? get artworkPath {
    for (final t in tracks) {
      if (t.artworkPath != null) return t.artworkPath;
    }
    return null;
  }
}

/// Identity of the album a track belongs to.
///
/// Uses the album artist tag when present. Without it, falls back to the
/// containing folder rather than the track artist, so a track with a guest
/// artist stays on its album, while two different "Greatest Hits" folders
/// stay apart.
String albumKeyFor(Track t) =>
    '${_norm(t.album)}\u0000${_norm(t.albumArtist ?? p.dirname(t.path))}';

List<AlbumGroup> groupAlbums(Iterable<Track> tracks) {
  final map = <String, AlbumGroup>{};
  for (final t in tracks) {
    map
        .putIfAbsent(
          albumKeyFor(t),
          () => AlbumGroup(name: t.album, tracks: []),
        )
        .tracks
        .add(t);
  }
  final groups = map.values.toList();
  for (final g in groups) {
    g.tracks.sort((a, b) {
      final n = (a.trackNumber ?? 1 << 30).compareTo(b.trackNumber ?? 1 << 30);
      return n != 0 ? n : _norm(a.title).compareTo(_norm(b.title));
    });
  }
  groups.sort((a, b) => _norm(a.name).compareTo(_norm(b.name)));
  return groups;
}

List<ArtistGroup> groupArtists(Iterable<Track> tracks) {
  final map = <String, ArtistGroup>{};
  for (final t in tracks) {
    map
        .putIfAbsent(
          _norm(t.artist),
          () => ArtistGroup(name: t.artist, tracks: []),
        )
        .tracks
        .add(t);
  }
  final groups = map.values.toList()
    ..sort((a, b) => _norm(a.name).compareTo(_norm(b.name)));
  return groups;
}
