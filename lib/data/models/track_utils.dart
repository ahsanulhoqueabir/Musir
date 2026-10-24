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
  AlbumGroup({required this.name, required this.artist, required this.tracks});

  final String name;
  final String artist;
  final List<Track> tracks;

  String get key => albumKey(name, artist);
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

String albumKey(String album, String artist) =>
    '${_norm(album)}\u0000${_norm(artist)}';

/// Groups by album + primary artist so two different "Greatest Hits" stay apart.
List<AlbumGroup> groupAlbums(Iterable<Track> tracks) {
  final map = <String, AlbumGroup>{};
  for (final t in tracks) {
    final g = map.putIfAbsent(
      albumKey(t.album, t.artist),
      () => AlbumGroup(name: t.album, artist: t.artist, tracks: []),
    );
    g.tracks.add(t);
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
