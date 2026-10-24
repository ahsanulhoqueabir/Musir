import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musir/app/providers.dart';
import 'package:musir/data/models/track_utils.dart';
import 'package:musir/core/widgets/track_tile.dart';
import 'package:musir/features/library/library_screen.dart' show ArtistsTab;
import 'package:musir/features/player/mini_player.dart';
import 'package:musir/features/player/player_providers.dart';
import 'package:musir/features/search/search_screen.dart';

import '../support/fixtures.dart';
import '../support/test_app.dart';

Future<void> goTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(searchDebounce + const Duration(milliseconds: 50));
  await settle(tester, rounds: 2);
}

/// Fails with the step name and the full error (including the widget that
/// overflowed) if the framework recorded an exception.
void expectNoErrors(WidgetTester tester, String step) {
  final e = tester.takeException();
  if (e == null) return;
  final detail = e is FlutterError ? e.toStringDeep() : '$e';
  fail('Error after "$step":\n$detail');
}

void main() {
  group('search', () {
    testApp('finds songs by title, artist and album after the debounce', (
      tester,
    ) async {
      final env = await createEnv(tester);
      await pumpApp(tester, env);
      await tester.tap(find.text('Search songs, artists, albums'));
      await settle(tester);

      expect(find.text('Search your library'), findsOneWidget);

      // Results wait for the debounce.
      await tester.enterText(find.byType(TextField), 'bravo');
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('2 results'), findsNothing);
      await tester.pump(searchDebounce);
      await settle(tester, rounds: 2);
      expect(find.text('2 results'), findsOneWidget);
      expect(find.text('Song 2'), findsOneWidget);
      expect(find.text('Song 4'), findsOneWidget);
      expect(find.text('Song 1'), findsNothing);

      await search(tester, 'second album');
      expect(find.text('Song 3'), findsOneWidget);
      expect(find.text('Song 4'), findsOneWidget);

      await search(tester, 'SONG 1');
      expect(find.text('1 result'), findsOneWidget);
    });

    testApp('no-results state, clear button and tapping a result plays it', (
      tester,
    ) async {
      final env = await createEnv(tester);
      await pumpApp(tester, env);
      await tester.tap(find.text('Search songs, artists, albums'));
      await settle(tester);

      await search(tester, 'zzz');
      expect(find.text('No results for "zzz"'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await settle(tester);
      expect(find.text('Search your library'), findsOneWidget);
      expect(find.byTooltip('Clear search'), findsNothing);

      await search(tester, 'song 3');
      await tester.tap(find.text('Song 3'));
      await settle(tester);
      expect(env.engine.trackIds, [3]);
      expect(env.engine.isPlaying, isTrue);
      // Mini-player is visible on the search page too.
      expect(find.byType(MiniPlayer), findsOneWidget);
    });
  });

  group('library browsing', () {
    testApp('albums and artists tabs lead to detail pages that play', (
      tester,
    ) async {
      final env = await createEnv(tester);
      await pumpApp(tester, env);
      await goTab(tester, 'Library');

      await tester.tap(find.text('Albums'));
      await settle(tester);
      expect(find.text('First Album'), findsOneWidget);
      expect(find.text('Second Album'), findsOneWidget);

      await tester.tap(find.text('Second Album'));
      await settle(tester);
      expect(find.text('2 songs · 6 min'), findsOneWidget);
      await tester.tap(find.text('Play'));
      await settle(tester);
      expect(env.engine.trackIds, [3, 4]);

      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.text('Artists'));
      await settle(tester);
      final artistRow = find.descendant(
        of: find.byType(ArtistsTab),
        matching: find.text('Alpha Act'),
      );
      expect(artistRow, findsOneWidget);
      await tester.tap(artistRow);
      await settle(tester);
      expect(find.text('2 albums · 2 songs'), findsOneWidget);
      await tester.tap(find.widgetWithText(TrackTile, 'Song 3'));
      await settle(tester);
      expect(env.engine.trackIds, [1, 3]);
      expect(env.engine.index, 1);
    });

    testApp('songs can be re-sorted without changing the saved default', (
      tester,
    ) async {
      final scan = scanOf([
        scanned('/m/a.mp3', title: 'Alpha', durationMs: 300000, size: 1),
        scanned('/m/b.mp3', title: 'Bravo', durationMs: 200000, size: 2),
        scanned('/m/c.mp3', title: 'Charlie', durationMs: 100000, size: 3),
      ]);
      final env = await createEnv(tester, scan: scan);
      await pumpApp(tester, env);
      await goTab(tester, 'Library');

      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Alpha') < y('Charlie'), isTrue);

      await tester.tap(find.byTooltip('Sort songs'));
      await settle(tester);
      await tester.tap(find.text('Duration'));
      await settle(tester);
      expect(y('Charlie') < y('Alpha'), isTrue);
      expect(env.prefs.getString('settings.sort'), isNull);
    });

    testApp('the default sort setting is used and persisted', (tester) async {
      final scan = scanOf([
        scanned('/m/a.mp3', title: 'Alpha', durationMs: 300000, size: 1),
        scanned('/m/b.mp3', title: 'Bravo', durationMs: 100000, size: 2),
      ]);
      final env = await createEnv(tester, scan: scan);
      await pumpApp(tester, env);

      await goTab(tester, 'Settings');
      await tester.tap(find.text('Default sort order'));
      await settle(tester);
      await tester.tap(find.text('Duration'));
      await settle(tester);
      expect(env.prefs.getString('settings.sort'), TrackSort.duration.name);

      await goTab(tester, 'Library');
      expect(
        tester.getTopLeft(find.text('Bravo')).dy <
            tester.getTopLeft(find.text('Alpha')).dy,
        isTrue,
      );
    });
  });

  group('playlists', () {
    testApp('create, add a song, play, delete and undo', (tester) async {
      final env = await createEnv(tester);
      await pumpApp(tester, env);

      await goTab(tester, 'Playlists');
      expect(find.text('No playlists yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'New playlist'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), '  Road trip ');
      await tester.tap(find.text('Create'));
      await settle(tester);
      expect(find.text('Road trip'), findsOneWidget);
      expect(find.text('Empty'), findsOneWidget);

      // Add Song 1 from the library via the track menu.
      await goTab(tester, 'Library');
      await tester.tap(find.byTooltip('More options for Song 1'));
      await settle(tester);
      await tester.tap(find.text('Add to playlist'));
      await settle(tester);
      await tester.tap(find.text('Road trip'));
      await settle(tester);
      expect(find.text('Added 1 song to Road trip'), findsOneWidget);

      // Adding again is a no-op with a clear message.
      await tester.tap(find.byTooltip('More options for Song 1'));
      await settle(tester);
      await tester.tap(find.text('Add to playlist'));
      await settle(tester);
      await tester.tap(find.text('Road trip'));
      await settle(tester);
      expect(find.text('Already in Road trip'), findsOneWidget);

      await goTab(tester, 'Playlists');
      expect(find.textContaining('1 song'), findsOneWidget);
      await tester.tap(find.text('Road trip'));
      await settle(tester);
      expect(find.text('Song 1'), findsOneWidget);
      await tester.tap(find.text('Play'));
      await settle(tester);
      expect(env.engine.trackIds, [1]);

      // Delete from the detail page, then undo from the snackbar.
      await tester.tap(find.byTooltip('Playlist options'));
      await settle(tester);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(env.container.read(playlistsProvider), isEmpty);
      expect(find.text('Deleted "Road trip"'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      final restored = env.container.read(playlistsProvider);
      expect(restored.single.name, 'Road trip');
      expect(restored.single.tracks.map((t) => t.title), ['Song 1']);
    });

    testApp('rename a playlist', (tester) async {
      final env = await createEnv(tester);
      await pumpApp(tester, env);
      await tester.runAsync(
        () => env.container.read(playlistsRepositoryProvider).create('Old'),
      );
      await goTab(tester, 'Playlists');

      await tester.tap(find.byTooltip('Playlist options'));
      await settle(tester);
      await tester.tap(find.text('Rename'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'New name');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('New name'), findsOneWidget);
      expect(find.text('Old'), findsNothing);
    });
  });

  group('settings', () {
    testApp('theme choice applies immediately and persists', (tester) async {
      final env = await createEnv(tester);
      await pumpApp(tester, env);
      ThemeMode mode() =>
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
      expect(mode(), ThemeMode.system);

      await goTab(tester, 'Settings');
      await tester.tap(find.text('Theme'));
      await settle(tester);
      await tester.tap(find.text('Dark'));
      await settle(tester);

      expect(mode(), ThemeMode.dark);
      expect(env.prefs.getString('settings.theme'), 'dark');
      expect(find.text('Dark'), findsOneWidget);
    });

    testApp('rescan, skip silence and about/privacy', (tester) async {
      final env = await createEnv(tester);
      await pumpApp(tester, env);
      await goTab(tester, 'Settings');

      expect(find.text('4 songs in your library'), findsOneWidget);
      final scansBefore = env.scanner.scans;
      await tester.tap(find.text('Rescan library'));
      await settle(tester);
      expect(env.scanner.scans, scansBefore + 1);
      expect(find.text('Library updated'), findsOneWidget);

      await tester.tap(find.text('Skip silence'));
      await settle(tester);
      expect(env.engine.skipSilence, isTrue);
      expect(env.prefs.getBool('settings.skipSilence'), isTrue);

      await tester.tap(find.text('Privacy'));
      await settle(tester);
      expect(find.textContaining('does not '), findsOneWidget);
      await tester.tap(find.text('Close'));
      await settle(tester);
    });
  });

  group('restore', () {
    testApp('reopens the last queue paused at the saved position', (
      tester,
    ) async {
      final snapshot = jsonEncode({
        'queue': [1, 2, 3, 4],
        'original': [1, 2, 3, 4],
        'index': 2,
        'positionMs': 42000,
        'shuffle': false,
        'repeat': 'all',
      });
      final env = await createEnv(
        tester,
        prefsValues: {'playback.snapshot': snapshot},
      );
      await tester.runAsync(() => env.seedLibrary());
      await pumpApp(tester, env);

      expect(
        find.descendant(
          of: find.byType(MiniPlayer),
          matching: find.text('Song 3'),
        ),
        findsOneWidget,
      );
      expect(env.engine.isPlaying, isFalse);
      expect(env.engine.pos, const Duration(seconds: 42));
      expect(env.container.read(playerStateProvider).repeat.name, 'all');
    });

    testApp('does nothing when "Resume last queue" is off', (tester) async {
      final snapshot = jsonEncode({
        'queue': [1, 2],
        'original': [1, 2],
        'index': 0,
        'positionMs': 0,
        'shuffle': false,
        'repeat': 'off',
      });
      final env = await createEnv(
        tester,
        prefsValues: {
          'playback.snapshot': snapshot,
          'settings.restoreQueue': false,
        },
      );
      await tester.runAsync(() => env.seedLibrary());
      await pumpApp(tester, env);
      expect(env.engine.queue, isEmpty);
    });
  });

  group('layout stress', () {
    final longScan = scanOf([
      for (var i = 1; i <= 3; i++)
        scanned(
          '/m/long$i.mp3',
          title:
              'An extraordinarily long song title number $i that keeps going and going well past any sensible width',
          artist:
              'The Remarkably Verbose Orchestra & Choir featuring Many Guests $i',
          album:
              'A Truly Epic Album Name That Also Refuses To End Gracefully $i',
          size: i,
        ),
    ]);

    const sizes = {
      'small phone': (Size(320, 568), 1.0),
      'large text': (Size(360, 640), 1.8),
      'tablet': (Size(800, 1280), 1.0),
    };

    for (final entry in sizes.entries) {
      for (final dark in [false, true]) {
        testApp(
          '${entry.key}, ${dark ? 'dark' : 'light'}: long metadata never overflows',
          (tester) async {
            final env = await createEnv(
              tester,
              scan: longScan,
              prefsValues: {'settings.theme': dark ? 'dark' : 'light'},
            );
            await pumpApp(
              tester,
              env,
              size: entry.value.$1,
              textScale: entry.value.$2,
            );

            // Home, every Library tab, Playlists, Settings.
            for (final tab in ['Library', 'Playlists', 'Settings', 'Home']) {
              await goTab(tester, tab);
              expectNoErrors(tester, 'open $tab tab');
            }
            await goTab(tester, 'Library');
            for (final t in ['Albums', 'Artists', 'Favorites', 'Songs']) {
              await tester.tap(find.text(t));
              await settle(tester);
              expectNoErrors(tester, 'library $t tab');
            }

            // Play, then the mini-player, full player, queue and track menu.
            await tester.tap(find.textContaining('number 1').first);
            await settle(tester);
            expect(
              env.engine.isPlaying,
              isTrue,
              reason: 'tapping the song should start playback',
            );
            expectNoErrors(tester, 'play a song (mini-player shown)');
            await tester.tap(find.byType(MiniPlayer));
            await settle(tester);
            expect(find.text('Now playing'), findsOneWidget);
            expectNoErrors(tester, 'full player');
            await tester.tap(find.text('Queue'));
            await settle(tester);
            expectNoErrors(tester, 'queue sheet');
            await tester.tapAt(const Offset(5, 5)); // dismiss the sheet
            await settle(tester);
            await tester.tap(find.byTooltip('More options'));
            await settle(tester);
            expectNoErrors(tester, 'track actions sheet');
          },
        );
      }
    }
  });
}
