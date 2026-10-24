import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('TrackRow')
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get album => text()();
  IntColumn get durationMs => integer()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get sizeBytes => integer()();
  IntColumn get modifiedMs => integer()();
  IntColumn get addedMs => integer()();
  TextColumn get artworkPath => text().nullable()();
}

@DataClassName('FavoriteRow')
class Favorites extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get addedMs => integer()();

  @override
  Set<Column> get primaryKey => {trackId};
}

@DataClassName('PlaylistRow')
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get createdMs => integer()();
}

@DataClassName('PlaylistEntryRow')
class PlaylistEntries extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}

@DataClassName('PlayHistoryRow')
class PlayHistory extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get lastPlayedMs => integer()();
  IntColumn get playCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {trackId};
}

@DriftDatabase(
  tables: [Tracks, Favorites, Playlists, PlaylistEntries, PlayHistory],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the on-device database.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'musir'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // Needed for ON DELETE CASCADE (rows vanish with their track/playlist).
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
