import 'package:drift/drift.dart';

import '../db/database.dart';
import '../models/scanned_track.dart';
import '../models/track.dart';

class LibraryRepository {
  LibraryRepository(this._db);

  final AppDatabase _db;

  Stream<List<Track>> watchTracks() =>
      _db.select(_db.tracks).watch().map((rows) => rows.map(_toTrack).toList());

  Future<List<Track>> getTracks() async =>
      (await _db.select(_db.tracks).get()).map(_toTrack).toList();

  /// `path -> (modifiedMs, sizeBytes)` so the scanner can skip unchanged files.
  Future<Map<String, (int, int)>> knownFiles() async {
    final rows = await _db.select(_db.tracks).get();
    return {for (final r in rows) r.path: (r.modifiedMs, r.sizeBytes)};
  }

  /// Merges a scan into the database.
  ///
  /// Existing rows are updated in place so their ids (and therefore favorites,
  /// playlist entries and history) survive. Rows for files that no longer
  /// exist are deleted, but only if the scan could actually read storage.
  Future<void> applyScan(ScanResult result, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final s in result.changed) {
        final existing = await (_db.select(
          _db.tracks,
        )..where((t) => t.path.equals(s.path))).getSingleOrNull();
        if (existing == null) {
          await _db
              .into(_db.tracks)
              .insert(
                TracksCompanion.insert(
                  path: s.path,
                  title: s.title,
                  artist: s.artist,
                  album: s.album,
                  durationMs: s.durationMs,
                  trackNumber: Value(s.trackNumber),
                  sizeBytes: s.sizeBytes,
                  modifiedMs: s.modifiedMs,
                  addedMs: now,
                  artworkPath: Value(s.artworkPath),
                ),
              );
        } else {
          await (_db.update(
            _db.tracks,
          )..where((t) => t.id.equals(existing.id))).write(
            TracksCompanion(
              title: Value(s.title),
              artist: Value(s.artist),
              album: Value(s.album),
              durationMs: Value(s.durationMs),
              trackNumber: Value(s.trackNumber),
              sizeBytes: Value(s.sizeBytes),
              modifiedMs: Value(s.modifiedMs),
              artworkPath: Value(s.artworkPath),
            ),
          );
        }
      }
      if (result.rootsReadable) {
        await (_db.delete(
          _db.tracks,
        )..where((t) => t.path.isNotIn(result.seenPaths))).go();
      }
    });
  }

  Track _toTrack(TrackRow r) => Track(
    id: r.id,
    path: r.path,
    title: r.title,
    artist: r.artist,
    album: r.album,
    durationMs: r.durationMs,
    sizeBytes: r.sizeBytes,
    modifiedMs: r.modifiedMs,
    addedMs: r.addedMs,
    trackNumber: r.trackNumber,
    artworkPath: r.artworkPath,
  );
}
