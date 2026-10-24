import 'package:flutter_test/flutter_test.dart';
import 'package:musir/data/db/database.dart';
import 'package:musir/data/repositories/favorites_repository.dart';
import 'package:musir/data/repositories/history_repository.dart';
import 'package:musir/data/repositories/library_repository.dart';
import 'package:musir/data/repositories/playlists_repository.dart';

import '../support/fixtures.dart';

void main() {
  late AppDatabase db;
  late LibraryRepository library;
  late FavoritesRepository favorites;
  late PlaylistsRepository playlists;
  late HistoryRepository history;

  setUp(() {
    db = memoryDb();
    library = LibraryRepository(db);
    favorites = FavoritesRepository(db);
    playlists = PlaylistsRepository(db);
    history = HistoryRepository(db);
  });
  tearDown(() => db.close());

  Future<List<int>> seed(int n) async {
    await library.applyScan(
      scanOf([for (var i = 0; i < n; i++) scanned('/m/$i.mp3', title: 'T$i')]),
      nowMs: 1000,
    );
    final tracks = await library.getTracks();
    tracks.sort((a, b) => a.path.compareTo(b.path));
    return [for (final t in tracks) t.id];
  }

  group('library', () {
    test('inserts tracks and stamps addedMs', () async {
      await seed(2);
      final tracks = await library.getTracks();
      expect(tracks, hasLength(2));
      expect(tracks.every((t) => t.addedMs == 1000), isTrue);
    });

    test('rescan keeps ids and addedMs, updates metadata', () async {
      final ids = await seed(1);
      await library.applyScan(
        scanOf([scanned('/m/0.mp3', title: 'Renamed', modified: 9)]),
        nowMs: 5000,
      );
      final t = (await library.getTracks()).single;
      expect(t.id, ids.single);
      expect(t.title, 'Renamed');
      expect(t.addedMs, 1000);
    });

    test(
      'removes tracks whose files are gone and cascades references',
      () async {
        final ids = await seed(2);
        await favorites.toggle(ids[1]);
        final pl = await playlists.create('P');
        await playlists.addTracks(pl, ids);
        await history.record(ids[1]);

        // Second file vanished: only the first remains in seenPaths.
        await library.applyScan(scanOf([], seen: {'/m/0.mp3'}));

        expect((await library.getTracks()).map((t) => t.id), [ids[0]]);
        expect(await favorites.watch().first, isEmpty);
        expect((await playlists.watchEntries().first)[pl], [ids[0]]);
        expect(await history.watchRecent().first, isEmpty);
      },
    );

    test('never deletes when storage was unreadable', () async {
      await seed(2);
      await library.applyScan(scanOf([], readable: false, seen: {}));
      expect(await library.getTracks(), hasLength(2));
    });

    test('knownFiles exposes modified time and size', () async {
      await library.applyScan(
        scanOf([scanned('/a.mp3', modified: 7, size: 42)]),
      );
      expect((await library.knownFiles())['/a.mp3'], (7, 42));
    });
  });

  group('favorites', () {
    test('toggle adds then removes and persists in the stream', () async {
      final ids = await seed(1);
      expect(await favorites.toggle(ids[0], nowMs: 5), isTrue);
      expect(await favorites.watch().first, {ids[0]: 5});
      expect(await favorites.toggle(ids[0]), isFalse);
      expect(await favorites.watch().first, isEmpty);
    });
  });

  group('playlists', () {
    test('create, rename, delete', () async {
      final id = await playlists.create('  Road trip ');
      expect((await playlists.watchPlaylists().first).single.name, 'Road trip');
      await playlists.rename(id, 'Gym');
      expect((await playlists.watchPlaylists().first).single.name, 'Gym');
      await playlists.delete(id);
      expect(await playlists.watchPlaylists().first, isEmpty);
    });

    test('addTracks preserves order and skips duplicates', () async {
      final ids = await seed(3);
      final pl = await playlists.create('P');
      expect(await playlists.addTracks(pl, [ids[2], ids[0]]), 2);
      expect(await playlists.addTracks(pl, [ids[0], ids[1]]), 1);
      expect((await playlists.watchEntries().first)[pl], [
        ids[2],
        ids[0],
        ids[1],
      ]);
    });

    test('removeTrack and reorder', () async {
      final ids = await seed(4);
      final pl = await playlists.create('P');
      await playlists.addTracks(pl, ids);
      await playlists.reorder(pl, 0, 3); // first item to index 2 (post-removal)
      expect((await playlists.watchEntries().first)[pl], [
        ids[1],
        ids[2],
        ids[0],
        ids[3],
      ]);
      await playlists.reorder(pl, 3, 0);
      expect((await playlists.watchEntries().first)[pl], [
        ids[3],
        ids[1],
        ids[2],
        ids[0],
      ]);
      await playlists.removeTrack(pl, ids[2]);
      expect((await playlists.watchEntries().first)[pl], [
        ids[3],
        ids[1],
        ids[0],
      ]);
    });

    test(
      'deleting a playlist removes its entries but not the tracks',
      () async {
        final ids = await seed(2);
        final pl = await playlists.create('P');
        await playlists.addTracks(pl, ids);
        await playlists.delete(pl);
        expect(await playlists.watchEntries().first, isEmpty);
        expect(await library.getTracks(), hasLength(2));
      },
    );
  });

  group('history', () {
    test('orders by most recent and counts replays', () async {
      final ids = await seed(3);
      await history.record(ids[0], nowMs: 1);
      await history.record(ids[1], nowMs: 2);
      await history.record(ids[0], nowMs: 3);
      expect(await history.watchRecent().first, [ids[0], ids[1]]);
      final row = await (db.select(
        db.playHistory,
      )..where((h) => h.trackId.equals(ids[0]))).getSingle();
      expect(row.playCount, 2);
      await history.clear();
      expect(await history.watchRecent().first, isEmpty);
    });
  });
}
