import 'package:drift/drift.dart';

import '../db/database.dart';

class FavoritesRepository {
  FavoritesRepository(this._db);

  final AppDatabase _db;

  /// `trackId -> addedMs`.
  Stream<Map<int, int>> watch() => _db
      .select(_db.favorites)
      .watch()
      .map((rows) => {for (final r in rows) r.trackId: r.addedMs});

  Future<bool> toggle(int trackId, {int? nowMs}) async {
    final existing = await (_db.select(
      _db.favorites,
    )..where((f) => f.trackId.equals(trackId))).getSingleOrNull();
    if (existing != null) {
      await (_db.delete(
        _db.favorites,
      )..where((f) => f.trackId.equals(trackId))).go();
      return false;
    }
    await _db
        .into(_db.favorites)
        .insert(
          FavoritesCompanion.insert(
            trackId: Value(trackId),
            addedMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
    return true;
  }
}
