import 'package:drift/drift.dart';

import '../db/database.dart';

class HistoryRepository {
  HistoryRepository(this._db);

  final AppDatabase _db;

  Future<void> record(int trackId, {int? nowMs}) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await _db.customInsert(
      'INSERT INTO play_history (track_id, last_played_ms, play_count) '
      'VALUES (?, ?, 1) ON CONFLICT(track_id) DO UPDATE SET '
      'last_played_ms = excluded.last_played_ms, '
      'play_count = play_count + 1',
      variables: [Variable.withInt(trackId), Variable.withInt(now)],
      updates: {_db.playHistory},
    );
  }

  /// Track ids, most recently played first.
  Stream<List<int>> watchRecent({int limit = 50}) {
    final q = _db.select(_db.playHistory)
      ..orderBy([(h) => OrderingTerm.desc(h.lastPlayedMs)])
      ..limit(limit);
    return q.watch().map((rows) => [for (final r in rows) r.trackId]);
  }

  Future<void> clear() => _db.delete(_db.playHistory).go();
}
