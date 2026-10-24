import 'package:drift/drift.dart';

import '../db/database.dart';

class PlaylistsRepository {
  PlaylistsRepository(this._db);

  final AppDatabase _db;

  Stream<List<PlaylistRow>> watchPlaylists() => (_db.select(
    _db.playlists,
  )..orderBy([(p) => OrderingTerm.asc(p.createdMs)])).watch();

  /// `playlistId -> ordered track ids`.
  Stream<Map<int, List<int>>> watchEntries() {
    final q = _db.select(_db.playlistEntries)
      ..orderBy([(e) => OrderingTerm.asc(e.position)]);
    return q.watch().map((rows) {
      final map = <int, List<int>>{};
      for (final r in rows) {
        (map[r.playlistId] ??= []).add(r.trackId);
      }
      return map;
    });
  }

  Future<int> create(String name, {int? nowMs}) => _db
      .into(_db.playlists)
      .insert(
        PlaylistsCompanion.insert(
          name: name.trim(),
          createdMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );

  Future<void> rename(int id, String name) =>
      (_db.update(_db.playlists)..where((p) => p.id.equals(id))).write(
        PlaylistsCompanion(name: Value(name.trim())),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.playlists)..where((p) => p.id.equals(id))).go();

  /// Appends [trackIds] in order, skipping tracks already present.
  /// Returns how many were actually added.
  Future<int> addTracks(int playlistId, List<int> trackIds) {
    return _db.transaction(() async {
      final rows = await (_db.select(
        _db.playlistEntries,
      )..where((e) => e.playlistId.equals(playlistId))).get();
      final present = {for (final r in rows) r.trackId};
      var next = rows.isEmpty
          ? 0
          : rows.map((r) => r.position).reduce((a, b) => a > b ? a : b) + 1;
      var added = 0;
      for (final id in trackIds) {
        if (!present.add(id)) continue;
        await _db
            .into(_db.playlistEntries)
            .insert(
              PlaylistEntriesCompanion.insert(
                playlistId: playlistId,
                trackId: id,
                position: next++,
              ),
            );
        added++;
      }
      return added;
    });
  }

  Future<void> removeTrack(int playlistId, int trackId) async {
    await (_db.delete(_db.playlistEntries)..where(
          (e) => e.playlistId.equals(playlistId) & e.trackId.equals(trackId),
        ))
        .go();
  }

  /// Moves the entry at [oldIndex] so it ends up at [newIndex] (the index in
  /// the final list, as passed by `ReorderableListView.onReorderItem`) and
  /// rewrites positions.
  Future<void> reorder(int playlistId, int oldIndex, int newIndex) {
    return _db.transaction(() async {
      final rows =
          await (_db.select(_db.playlistEntries)
                ..where((e) => e.playlistId.equals(playlistId))
                ..orderBy([(e) => OrderingTerm.asc(e.position)]))
              .get();
      final ids = [for (final r in rows) r.trackId];
      if (oldIndex < 0 || oldIndex >= ids.length) return;
      newIndex = newIndex.clamp(0, ids.length - 1);
      ids.insert(newIndex, ids.removeAt(oldIndex));
      for (var i = 0; i < ids.length; i++) {
        await (_db.update(_db.playlistEntries)..where(
              (e) => e.playlistId.equals(playlistId) & e.trackId.equals(ids[i]),
            ))
            .write(PlaylistEntriesCompanion(position: Value(i)));
      }
    });
  }
}
