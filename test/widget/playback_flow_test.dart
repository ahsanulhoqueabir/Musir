import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musir/app/providers.dart';
import 'package:musir/features/player/mini_player.dart';
import 'package:musir/features/player/player_providers.dart';
import 'package:musir/services/audio/audio_engine.dart';

import '../support/test_app.dart';

Finder inMini(Finder f) =>
    find.descendant(of: find.byType(MiniPlayer), matching: f);

Future<void> openLibrary(WidgetTester tester) async {
  await tester.tap(find.text('Library'));
  await settle(tester);
}

Future<void> playSong(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).last);
  await settle(tester);
}

void main() {
  testApp('tapping a song starts playback and shows the mini-player', (
    tester,
  ) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);

    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(inMini(find.text('Song 3')), findsNothing);

    await openLibrary(tester);
    await playSong(tester, 'Song 3');

    expect(env.engine.queue, hasLength(4));
    expect(env.engine.index, 2);
    expect(env.engine.isPlaying, isTrue);
    expect(inMini(find.text('Song 3')), findsOneWidget);
    expect(inMini(find.byTooltip('Pause')), findsOneWidget);
  });

  testApp('mini-player pauses, resumes and skips', (tester) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    await openLibrary(tester);
    await playSong(tester, 'Song 1');

    await tester.tap(inMini(find.byTooltip('Pause')));
    await settle(tester);
    expect(env.engine.isPlaying, isFalse);
    expect(inMini(find.byTooltip('Play')), findsOneWidget);

    await tester.tap(inMini(find.byTooltip('Play')));
    await settle(tester);
    expect(env.engine.isPlaying, isTrue);

    await tester.tap(inMini(find.byTooltip('Next')));
    await settle(tester);
    expect(env.engine.index, 1);
    expect(inMini(find.text('Song 2')), findsOneWidget);
  });

  testApp('next is disabled on the last track', (tester) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    await openLibrary(tester);
    await playSong(tester, 'Song 4');
    final next = tester.widget<IconButton>(
      find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
      ),
    );
    expect(next.onPressed, isNull);
  });

  testApp('full player: controls, shuffle, repeat and favorite', (
    tester,
  ) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    await openLibrary(tester);
    await playSong(tester, 'Song 2');

    await tester.tap(inMini(find.text('Song 2')));
    await settle(tester);
    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('Song 2'), findsWidgets);
    expect(find.text('Bravo Band'), findsWidgets);

    // Transport.
    await tester.tap(find.byTooltip('Next').last);
    await settle(tester);
    expect(env.engine.index, 2);
    await tester.tap(find.byTooltip('Previous'));
    await settle(tester);
    expect(env.engine.index, 1);

    // Shuffle toggles and the engine mirrors the new order.
    await tester.tap(find.byTooltip('Shuffle off'));
    await settle(tester);
    expect(env.container.read(playerStateProvider).shuffle, isTrue);
    expect(find.byTooltip('Shuffle on'), findsOneWidget);
    expect(env.engine.index, 0);
    expect(env.engine.queue.first.track.title, 'Song 2');
    await tester.tap(find.byTooltip('Shuffle on'));
    await settle(tester);
    expect(env.engine.trackIds, [1, 2, 3, 4]);

    // Repeat cycles off -> all -> one -> off.
    await tester.tap(find.byTooltip('Repeat off'));
    await settle(tester);
    expect(env.engine.repeat, RepeatSetting.all);
    await tester.tap(find.byTooltip('Repeat all'));
    await settle(tester);
    expect(env.engine.repeat, RepeatSetting.one);
    await tester.tap(find.byTooltip('Repeat one'));
    await settle(tester);
    expect(env.engine.repeat, RepeatSetting.off);

    // Favorite persists to the database and shows up in the Favorites tab.
    await tester.tap(find.byTooltip('Add to favorites'));
    await settle(tester);
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);
    expect(env.container.read(favoriteTracksProvider).map((t) => t.title), [
      'Song 2',
    ]);

    await tester.tap(find.byTooltip('Close player'));
    await settle(tester);
    expect(find.text('Now playing'), findsNothing);
    await tester.tap(find.text('Favorites'));
    await settle(tester);
    expect(find.text('Song 2'), findsWidgets);
    expect(find.text('No favorites yet'), findsNothing);
  });

  testApp('queue sheet lists tracks, jumps and clears', (tester) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    await openLibrary(tester);
    await playSong(tester, 'Song 1');
    await tester.tap(inMini(find.text('Song 1')));
    await settle(tester);

    await tester.tap(find.text('Queue'));
    await settle(tester);
    expect(find.text('4 songs'), findsOneWidget);

    await tester.tap(find.text('Song 4').last);
    await settle(tester);
    expect(env.engine.index, 3);

    await tester.tap(find.text('Clear'));
    await settle(tester);
    expect(env.container.read(playerStateProvider).hasQueue, isFalse);
    expect(env.engine.isPlaying, isFalse);
  });

  testApp('track menu: play next and add to queue update the queue', (
    tester,
  ) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    await openLibrary(tester);
    await playSong(tester, 'Song 1');

    await tester.tap(find.byTooltip('More options for Song 4'));
    await settle(tester);
    await tester.tap(find.text('Play next'));
    await settle(tester);
    expect(find.text('Playing next'), findsOneWidget);
    expect(env.engine.trackIds.take(2), [1, 4]);

    await tester.tap(find.byTooltip('More options for Song 3'));
    await settle(tester);
    await tester.tap(find.text('Add to queue'));
    await settle(tester);
    expect(env.engine.trackIds.last, 3);
  });

  testApp('files deleted from disk are skipped and the user is told', (
    tester,
  ) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    await openLibrary(tester);
    env.missingPaths.add('/music/song2.mp3');

    await playSong(tester, 'Song 1');

    expect(env.engine.trackIds, [1, 3, 4]);
    expect(find.text('1 file is missing and was skipped.'), findsOneWidget);
    expect(env.engine.isPlaying, isTrue);
  });

  testApp('a track that fails to decode is skipped with a message', (
    tester,
  ) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    await openLibrary(tester);
    await playSong(tester, 'Song 1');

    env.engine.emitError('decoder');
    await settle(tester);

    expect(env.engine.index, 1);
    expect(find.textContaining('Can\'t play "Song 1"'), findsOneWidget);
  });

  testApp('mini-player stays compact on pages where it is the only bottom bar', (
    tester,
  ) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    await openLibrary(tester);
    await tester.tap(find.text('Albums'));
    await settle(tester);
    await tester.tap(find.text('Second Album'));
    await settle(tester);
    await tester.tap(find.text('Play'));
    await settle(tester);

    // Regression: the mini-player once expanded to fill the whole screen here,
    // leaving the album's song list with zero height.
    final mini = tester.getRect(find.byType(MiniPlayer));
    expect(mini.height, lessThan(100));
    expect(
      mini.bottom,
      tester.view.physicalSize.height / tester.view.devicePixelRatio,
    );
    expect(find.text('Song 4'), findsWidgets);
  });
}
