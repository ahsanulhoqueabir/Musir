import 'package:flutter_test/flutter_test.dart';
import 'package:musir/data/models/track_utils.dart';

import '../support/fixtures.dart';

void main() {
  final a = track(
    1,
    title: 'beta',
    artist: 'Zed',
    album: 'Y',
    durationMs: 300,
    added: 10,
    trackNumber: 2,
  );
  final b = track(
    2,
    title: 'Alpha',
    artist: 'Amy',
    album: 'Y',
    durationMs: 100,
    added: 30,
    trackNumber: 1,
  );
  final c = track(
    3,
    title: 'Gamma',
    artist: 'Amy',
    album: 'X',
    durationMs: 200,
    added: 20,
  );

  List<int> ids(Iterable<dynamic> l) => [for (final t in l) t.id as int];

  group('sortTracks', () {
    test('by title is case-insensitive', () {
      expect(ids(sortTracks([a, b, c], TrackSort.title)), [2, 1, 3]);
    });
    test('by artist then title', () {
      expect(ids(sortTracks([a, b, c], TrackSort.artist)), [2, 3, 1]);
    });
    test('by album then track number', () {
      expect(ids(sortTracks([a, b, c], TrackSort.album)), [3, 2, 1]);
    });
    test('recently added is newest first', () {
      expect(ids(sortTracks([a, b, c], TrackSort.recentlyAdded)), [2, 3, 1]);
    });
    test('by duration ascending', () {
      expect(ids(sortTracks([a, b, c], TrackSort.duration)), [2, 3, 1]);
    });
    test('does not mutate input', () {
      final input = [a, b, c];
      sortTracks(input, TrackSort.title);
      expect(ids(input), [1, 2, 3]);
    });
  });

  group('searchTracks', () {
    test('matches title, artist and album', () {
      expect(ids(searchTracks([a, b, c], 'alpha')), [2]);
      expect(ids(searchTracks([a, b, c], 'zed')), [1]);
      expect(ids(searchTracks([a, b, c], 'x')), [3]);
    });
    test('multiple terms must all match', () {
      expect(ids(searchTracks([a, b, c], 'amy gamma')), [3]);
      expect(searchTracks([a, b, c], 'amy zed'), isEmpty);
    });
    test('blank query returns nothing', () {
      expect(searchTracks([a, b, c], '   '), isEmpty);
    });
  });

  test('dedupeTracks hides identical copies, keeps lowest id', () {
    final dup = track(
      9,
      title: 'beta',
      artist: 'Zed',
      album: 'Y',
      durationMs: 300,
      size: 1000,
    );
    final differentSize = track(
      8,
      title: 'beta',
      artist: 'Zed',
      album: 'Y',
      durationMs: 300,
      size: 2000,
    );
    expect(ids(dedupeTracks([dup, a, differentSize])), [1, 8]);
  });

  group('groupAlbums', () {
    test(
      'a guest artist does not split an album (same folder, no album artist)',
      () {
        final a1 = track(1, album: 'Record', artist: 'Main', dir: '/m/record');
        final a2 = track(
          2,
          album: 'Record',
          artist: 'Main feat. Guest',
          dir: '/m/record',
        );
        final a3 = track(3, album: 'Record', artist: 'Main', dir: '/m/record');
        final groups = groupAlbums([a1, a2, a3]);
        expect(groups, hasLength(1));
        expect(groups.single.artist, 'Main'); // dominant artist (2 of 3)
      },
    );

    test('same album name in different folders stays separate', () {
      final x = track(1, album: 'Greatest Hits', artist: 'P', dir: '/m/p');
      final y = track(2, album: 'Greatest Hits', artist: 'Q', dir: '/m/q');
      expect(groupAlbums([x, y]), hasLength(2));
    });

    test('album artist tag wins over folder and track artist', () {
      final x = track(
        1,
        album: 'Mix',
        artist: 'A',
        albumArtist: 'Various',
        dir: '/m/a',
      );
      final y = track(
        2,
        album: 'Mix',
        artist: 'B',
        albumArtist: 'Various',
        dir: '/m/b',
      );
      final groups = groupAlbums([x, y]);
      expect(groups, hasLength(1));
      expect(groups.single.artist, 'Various');
    });

    test('mixed artists without a tag are shown as Various artists', () {
      final groups = groupAlbums([
        track(1, album: 'Comp', artist: 'A', dir: '/m/c'),
        track(2, album: 'Comp', artist: 'B', dir: '/m/c'),
        track(3, album: 'Comp', artist: 'C', dir: '/m/c'),
      ]);
      expect(groups.single.artist, 'Various artists');
    });

    test('tracks are ordered by track number, then title', () {
      final x = track(4, album: 'Hits', trackNumber: 2);
      final y = track(5, album: 'Hits', trackNumber: 1);
      final z = track(6, album: 'Hits', title: 'A untitled');
      expect(ids(groupAlbums([x, y, z]).single.tracks), [5, 4, 6]);
    });

    test('albumKeyFor is stable for tracks of one album', () {
      final x = track(1, album: 'Hits', dir: '/m/h');
      final y = track(2, album: 'HITS ', dir: '/m/h');
      expect(albumKeyFor(x), albumKeyFor(y));
    });
  });

  test('groupArtists merges case-insensitively', () {
    final groups = groupArtists([
      track(1, artist: 'Amy'),
      track(2, artist: 'amy'),
      track(3, artist: 'Bob'),
    ]);
    expect(groups.map((g) => g.tracks.length), [2, 1]);
  });
}
