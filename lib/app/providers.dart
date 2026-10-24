import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/models/playlist.dart';
import '../data/models/track.dart';
import '../data/models/track_utils.dart';
import '../data/repositories/favorites_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/playlists_repository.dart';
import '../features/settings/settings_state.dart';

// ---------------------------------------------------------------- data layer

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final libraryRepositoryProvider = Provider(
  (ref) => LibraryRepository(ref.watch(databaseProvider)),
);
final favoritesRepositoryProvider = Provider(
  (ref) => FavoritesRepository(ref.watch(databaseProvider)),
);
final playlistsRepositoryProvider = Provider(
  (ref) => PlaylistsRepository(ref.watch(databaseProvider)),
);
final historyRepositoryProvider = Provider(
  (ref) => HistoryRepository(ref.watch(databaseProvider)),
);

// ------------------------------------------------------------ library views

/// All tracks, duplicates hidden. The single source for every browse screen,
/// so the library is queried once, not per screen.
final allTracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchTracks().map(dedupeTracks),
);

final tracksProvider = Provider<List<Track>>(
  (ref) => ref.watch(allTracksProvider).value ?? const [],
);

final tracksByIdProvider = Provider<Map<int, Track>>(
  (ref) => {for (final t in ref.watch(tracksProvider)) t.id: t},
);

/// Songs in the user's default sort order.
final sortedSongsProvider = Provider<List<Track>>(
  (ref) => sortTracks(
    ref.watch(tracksProvider),
    ref.watch(settingsProvider.select((s) => s.defaultSort)),
  ),
);

final recentlyAddedProvider = Provider<List<Track>>(
  (ref) => sortTracks(
    ref.watch(tracksProvider),
    TrackSort.recentlyAdded,
  ).take(20).toList(),
);

final albumsProvider = Provider<List<AlbumGroup>>(
  (ref) => groupAlbums(ref.watch(tracksProvider)),
);

final artistsProvider = Provider<List<ArtistGroup>>(
  (ref) => groupArtists(ref.watch(tracksProvider)),
);

// ---------------------------------------------------------------- favorites

/// `trackId -> addedMs`.
final favoriteMapProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(favoritesRepositoryProvider).watch(),
);

final favoriteIdsProvider = Provider<Set<int>>(
  (ref) => (ref.watch(favoriteMapProvider).value ?? const {}).keys.toSet(),
);

/// Rebuilds only widgets showing this track when its favorite flag flips.
final isFavoriteProvider = Provider.family<bool, int>(
  (ref, id) => ref.watch(favoriteIdsProvider.select((s) => s.contains(id))),
);

final favoriteTracksProvider = Provider<List<Track>>((ref) {
  final added = ref.watch(favoriteMapProvider).value ?? const {};
  final byId = ref.watch(tracksByIdProvider);
  final tracks = [for (final id in added.keys) ?byId[id]]
    ..sort((a, b) => added[b.id]!.compareTo(added[a.id]!));
  return tracks;
});

// ---------------------------------------------------------------- playlists

final playlistRowsProvider = StreamProvider<List<PlaylistRow>>(
  (ref) => ref.watch(playlistsRepositoryProvider).watchPlaylists(),
);

final playlistEntriesProvider = StreamProvider<Map<int, List<int>>>(
  (ref) => ref.watch(playlistsRepositoryProvider).watchEntries(),
);

final playlistsProvider = Provider<List<Playlist>>((ref) {
  final rows = ref.watch(playlistRowsProvider).value ?? const [];
  final entries = ref.watch(playlistEntriesProvider).value ?? const {};
  final byId = ref.watch(tracksByIdProvider);
  return [
    for (final r in rows)
      Playlist(
        id: r.id,
        name: r.name,
        createdMs: r.createdMs,
        tracks: [for (final id in entries[r.id] ?? const <int>[]) ?byId[id]],
      ),
  ];
});

final playlistProvider = Provider.family<Playlist?, int>((ref, id) {
  for (final p in ref.watch(playlistsProvider)) {
    if (p.id == id) return p;
  }
  return null;
});

// ------------------------------------------------------------------ history

final recentIdsProvider = StreamProvider<List<int>>(
  (ref) => ref.watch(historyRepositoryProvider).watchRecent(),
);

final recentlyPlayedProvider = Provider<List<Track>>((ref) {
  final ids = ref.watch(recentIdsProvider).value ?? const [];
  final byId = ref.watch(tracksByIdProvider);
  return [for (final id in ids) ?byId[id]];
});
