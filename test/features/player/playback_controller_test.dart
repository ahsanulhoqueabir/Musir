import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:musir/features/player/playback_controller.dart';
import 'package:musir/services/audio/audio_engine.dart';
import 'package:musir/services/audio/playback_store.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/fixtures.dart';

void main() {
  late FakeAudioEngine engine;
  late MemoryPlaybackStore store;
  late PlaybackController c;
  late List<int> started;
  Set<String> missing = {};

  final lib = [for (var i = 1; i <= 6; i++) track(i)];

  PlaybackController make() => PlaybackController(
    engine: engine,
    store: store,
    fileExists: (path) => !missing.contains(path),
    onTrackStarted: started.add,
    random: Random(7),
  );

  setUp(() {
    engine = FakeAudioEngine();
    store = MemoryPlaybackStore();
    started = [];
    missing = {};
    c = make();
  });
  tearDown(() => c.dispose());

  List<int> ids() => [for (final e in c.state.queue) e.track.id];
  int? curId() => c.state.currentTrack?.id;

  group('starting playback', () {
    test('playTracks loads the queue at the tapped track and plays', () async {
      await c.playTracks(lib, startIndex: 2);
      expect(ids(), [1, 2, 3, 4, 5, 6]);
      expect(curId(), 3);
      expect(c.state.playing, isTrue);
      expect(engine.index, 2);
      expect(engine.isPlaying, isTrue);
    });

    test('empty list is a no-op', () async {
      await c.playTracks([]);
      expect(c.state.hasQueue, isFalse);
      expect(engine.setQueueCalls, 0);
    });

    test('missing files are dropped and reported', () async {
      missing = {lib[0].path, lib[2].path};
      await c.playTracks(lib, startIndex: 1);
      expect(ids(), [2, 4, 5, 6]);
      expect(curId(), 2);
      expect(c.state.notice?.message, contains('2 files are missing'));
    });

    test('tapping a missing track starts at the next available one', () async {
      missing = {lib[1].path};
      await c.playTracks(lib, startIndex: 1);
      expect(ids(), [1, 3, 4, 5, 6]);
      expect(curId(), 3);
    });

    test('all files missing: nothing plays', () async {
      missing = {for (final t in lib) t.path};
      await c.playTracks(lib);
      expect(c.state.hasQueue, isFalse);
      expect(c.state.notice, isNotNull);
    });

    test(
      'undecodable first track is removed and the next one is tried',
      () async {
        engine.failPaths = {lib[0].path};
        await c.playTracks(lib);
        expect(ids(), [2, 3, 4, 5, 6]);
        expect(curId(), 2);
        expect(engine.isPlaying, isTrue);
        expect(c.state.notice?.message, contains(lib[0].title));
      },
    );

    test('every track undecodable ends with an empty, idle player', () async {
      engine.failPaths = {for (final t in lib) t.path};
      await c.playTracks(lib);
      expect(c.state.hasQueue, isFalse);
      expect(c.state.playing, isFalse);
    });

    test('records play history once per started track', () async {
      await c.playTracks(lib);
      await c.next();
      await c.pause();
      await c.play();
      expect(started, [1, 2]);
    });
  });

  group('transport', () {
    test('toggle play/pause', () async {
      await c.playTracks(lib);
      await c.togglePlayPause();
      expect(c.state.playing, isFalse);
      await c.togglePlayPause();
      expect(c.state.playing, isTrue);
    });

    test(
      'next moves forward and stops at the end when repeat is off',
      () async {
        await c.playTracks(lib, startIndex: 4);
        await c.next();
        expect(curId(), 6);
        await c.next();
        expect(curId(), 6);
      },
    );

    test('next wraps with repeat all', () async {
      await c.playTracks(lib, startIndex: 5);
      await c.setRepeat(RepeatSetting.all);
      await c.next();
      expect(curId(), 1);
    });

    test(
      'previous restarts the track when played past the threshold',
      () async {
        await c.playTracks(lib, startIndex: 2);
        engine.pos = const Duration(seconds: 10);
        await c.previous();
        expect(curId(), 3);
        expect(engine.pos, Duration.zero);
      },
    );

    test('previous goes back when near the start', () async {
      await c.playTracks(lib, startIndex: 2);
      engine.pos = const Duration(seconds: 1);
      await c.previous();
      expect(curId(), 2);
    });

    test(
      'previous on first track restarts it; wraps with repeat all',
      () async {
        await c.playTracks(lib);
        await c.previous();
        expect(curId(), 1);
        await c.setRepeat(RepeatSetting.all);
        await c.previous();
        expect(curId(), 6);
      },
    );

    test('seekBy clamps at zero', () async {
      await c.playTracks(lib);
      engine.pos = const Duration(seconds: 4);
      await c.seekBy(const Duration(seconds: -10));
      expect(engine.pos, Duration.zero);
      await c.seekBy(const Duration(seconds: 10));
      expect(engine.pos, const Duration(seconds: 10));
    });

    test('skipToIndex jumps and plays', () async {
      await c.playTracks(lib);
      await c.pause();
      await c.skipToIndex(3);
      expect(curId(), 4);
      expect(c.state.playing, isTrue);
    });

    test('engine advancing on its own updates the current track', () async {
      await c.playTracks(lib);
      engine.finishCurrent();
      expect(curId(), 2);
      expect(started, [1, 2]);
    });

    test(
      'finishing the last track with repeat off rewinds to the first, paused',
      () async {
        await c.playTracks(lib, startIndex: 5);
        engine.finishCurrent();
        await Future<void>.delayed(Duration.zero);
        expect(curId(), 1);
        expect(c.state.playing, isFalse);
      },
    );

    test(
      'repeat cycles off -> all -> one -> off and reaches the engine',
      () async {
        await c.playTracks(lib);
        await c.cycleRepeat();
        expect(c.state.repeat, RepeatSetting.all);
        expect(engine.repeat, RepeatSetting.all);
        await c.cycleRepeat();
        expect(engine.repeat, RepeatSetting.one);
        await c.cycleRepeat();
        expect(engine.repeat, RepeatSetting.off);
      },
    );

    test('repeat one keeps the same track when it finishes', () async {
      await c.playTracks(lib, startIndex: 1);
      await c.setRepeat(RepeatSetting.one);
      engine.finishCurrent();
      expect(curId(), 2);
    });
  });

  group('shuffle', () {
    test(
      'enabling keeps the current track first and the same set of tracks',
      () async {
        await c.playTracks(lib, startIndex: 3);
        await c.toggleShuffle();
        expect(c.state.shuffle, isTrue);
        expect(curId(), 4);
        expect(c.state.currentIndex, 0);
        expect(ids().first, 4);
        expect(ids()..sort(), [1, 2, 3, 4, 5, 6]);
        expect(engine.trackIds, ids()); // engine mirrors the visible order
      },
    );

    test(
      'disabling restores the original order around the current track',
      () async {
        await c.playTracks(lib, startIndex: 3);
        await c.toggleShuffle();
        await c.next(); // now on a different track
        final playing = curId();
        await c.toggleShuffle();
        expect(ids(), [1, 2, 3, 4, 5, 6]);
        expect(curId(), playing);
        expect(c.state.currentIndex, playing! - 1);
        expect(engine.trackIds, ids());
      },
    );

    test(
      'playTracks while shuffle is on starts with the tapped track',
      () async {
        await c.playTracks(lib);
        await c.toggleShuffle();
        await c.playTracks(lib, startIndex: 4);
        expect(curId(), 5);
        expect(ids().first, 5);
        expect(ids()..sort(), [1, 2, 3, 4, 5, 6]);
      },
    );

    test(
      'forceShuffle starts a shuffled queue from a "shuffle all" action',
      () async {
        await c.playTracks(lib, forceShuffle: true);
        expect(c.state.shuffle, isTrue);
        expect(ids().toSet(), {1, 2, 3, 4, 5, 6});
      },
    );

    test('toggling with no queue only flips the flag', () async {
      await c.toggleShuffle();
      expect(c.state.shuffle, isTrue);
      await c.playTracks(lib);
      expect(c.state.shuffle, isTrue);
      expect(curId(), 1);
    });

    test(
      'items added while shuffled return to a sensible place when unshuffled',
      () async {
        await c.playTracks(lib.sublist(0, 4), startIndex: 1);
        await c.toggleShuffle();
        await c.playNext([lib[5]]);
        expect(ids()[1], 6);
        await c.toggleShuffle();
        // Original: [1,2,3,4]; 6 was queued next after 2.
        expect(ids(), [1, 2, 6, 3, 4]);
      },
    );
  });

  group('queue editing', () {
    test('playNext inserts right after the current track', () async {
      await c.playTracks(lib.sublist(0, 3), startIndex: 1);
      await c.playNext([lib[4]]);
      expect(ids(), [1, 2, 5, 3]);
      expect(curId(), 2);
      expect(engine.trackIds, ids());
    });

    test('addToQueue appends', () async {
      await c.playTracks(lib.sublist(0, 3));
      await c.addToQueue([lib[4], lib[5]]);
      expect(ids(), [1, 2, 3, 5, 6]);
      expect(curId(), 1);
    });

    test('adding the same track twice keeps two independent entries', () async {
      await c.playTracks(lib.sublist(0, 2));
      await c.addToQueue([lib[0]]);
      await c.addToQueue([lib[0]]);
      expect(ids(), [1, 2, 1, 1]);
      expect(c.state.queue.map((e) => e.uid).toSet(), hasLength(4));
    });

    test('adding to an empty queue starts playback', () async {
      await c.addToQueue([lib[2]]);
      expect(ids(), [3]);
      expect(c.state.playing, isTrue);
    });

    test('missing files are not queued', () async {
      await c.playTracks(lib.sublist(0, 2));
      missing = {lib[4].path};
      await c.addToQueue([lib[4]]);
      expect(ids(), [1, 2]);
    });

    test('removing a track before the current one shifts the index', () async {
      await c.playTracks(lib, startIndex: 3);
      await c.removeAt(1);
      expect(ids(), [1, 3, 4, 5, 6]);
      expect(curId(), 4);
      expect(c.state.currentIndex, 2);
      expect(engine.index, 2);
    });

    test('removing a track after the current one keeps the index', () async {
      await c.playTracks(lib, startIndex: 1);
      await c.removeAt(4);
      expect(curId(), 2);
      expect(ids(), [1, 2, 3, 4, 6]);
    });

    test(
      'removing the playing track moves on to its neighbour and keeps playing',
      () async {
        await c.playTracks(lib.sublist(0, 4), startIndex: 1);
        await c.removeAt(1);
        expect(ids(), [1, 3, 4]);
        expect(curId(), 3);
        expect(engine.isPlaying, isTrue);
      },
    );

    test(
      'removing the playing last track falls back to the new last',
      () async {
        await c.playTracks(lib.sublist(0, 3), startIndex: 2);
        await c.removeAt(2);
        expect(curId(), 2);
      },
    );

    test('removing the only track clears the queue', () async {
      await c.playTracks([lib[0]]);
      await c.removeAt(0);
      expect(c.state.hasQueue, isFalse);
      expect(c.state.playing, isFalse);
      expect(store.saved, isNull);
    });

    test('removing while paused does not start playback', () async {
      await c.playTracks(lib.sublist(0, 3));
      await c.pause();
      await c.removeAt(0);
      expect(c.state.playing, isFalse);
    });

    test('move keeps following the current track', () async {
      await c.playTracks(lib, startIndex: 2);
      await c.move(0, 4); // before current -> after current
      expect(ids(), [2, 3, 4, 5, 1, 6]);
      expect(curId(), 3);
      expect(c.state.currentIndex, 1);
      await c.move(5, 0); // after -> before
      expect(curId(), 3);
      expect(c.state.currentIndex, 2);
      await c.move(2, 4); // move the current track itself
      expect(curId(), 3);
      expect(c.state.currentIndex, 4);
      expect(engine.index, 4);
      expect(engine.trackIds, ids());
    });

    test('move ignores out-of-range or no-op requests', () async {
      await c.playTracks(lib.sublist(0, 3));
      await c.move(1, 1);
      await c.move(-1, 2);
      await c.move(0, 9);
      expect(ids(), [1, 2, 3]);
    });

    test('clearQueue stops and forgets the saved session', () async {
      await c.playTracks(lib);
      await c.clearQueue();
      expect(c.state.hasQueue, isFalse);
      expect(engine.isPlaying, isFalse);
      expect(store.saved, isNull);
    });
  });

  group('errors', () {
    test('engine error skips to the next track and tells the user', () async {
      await c.playTracks(lib);
      engine.emitError('decoder');
      expect(curId(), 2);
      expect(c.state.notice?.message, contains(lib[0].title));
    });

    test(
      'engine error on the last track pauses instead of looping forever',
      () async {
        await c.playTracks(lib, startIndex: 5);
        engine.emitError('decoder');
        await Future<void>.delayed(Duration.zero);
        expect(c.state.playing, isFalse);
        expect(curId(), 6);
      },
    );

    test(
      'notice ids increase so repeated messages are distinguishable',
      () async {
        await c.playTracks(lib);
        engine.emitError('x');
        final first = c.state.notice!.id;
        engine.emitError('y');
        expect(c.state.notice!.id, greaterThan(first));
      },
    );
  });

  group('persistence', () {
    test('queue, index, modes and position are saved', () async {
      await c.playTracks(lib, startIndex: 2);
      await c.setRepeat(RepeatSetting.all);
      engine.pos = const Duration(seconds: 42);
      c.persistNow();
      final s = store.saved!;
      expect(s.queueIds, [1, 2, 3, 4, 5, 6]);
      expect(s.index, 2);
      expect(s.positionMs, 42000);
      expect(s.repeat, RepeatSetting.all);
      expect(s.shuffle, isFalse);
    });

    test('restore rebuilds the queue paused at the saved position', () async {
      await c.playTracks(lib, startIndex: 2);
      await c.setRepeat(RepeatSetting.one);
      engine.pos = const Duration(seconds: 42);
      c.persistNow();
      final saved = store.saved!;

      final engine2 = FakeAudioEngine();
      final c2 = PlaybackController(
        engine: engine2,
        store: MemoryPlaybackStore(),
        fileExists: (_) => true,
      );
      await c2.restore(saved, {for (final t in lib) t.id: t});
      expect([for (final e in c2.state.queue) e.track.id], [1, 2, 3, 4, 5, 6]);
      expect(c2.state.currentTrack?.id, 3);
      expect(c2.state.playing, isFalse);
      expect(engine2.isPlaying, isFalse);
      expect(engine2.pos, const Duration(seconds: 42));
      expect(c2.state.repeat, RepeatSetting.one);
      expect(engine2.repeat, RepeatSetting.one);
      await c2.dispose();
    });

    test(
      'restore skips tracks that left the library or vanished from disk',
      () async {
        final saved = SavedPlayback(
          queueIds: const [1, 2, 3, 99],
          originalIds: const [1, 2, 3, 99],
          index: 1,
          positionMs: 5000,
          shuffle: false,
          repeat: RepeatSetting.off,
        );
        missing = {lib[0].path};
        await c.restore(saved, {for (final t in lib) t.id: t});
        expect(ids(), [2, 3]);
        expect(curId(), 2);
      },
    );

    test(
      'restore falls back to a neighbour when the saved track is gone',
      () async {
        final saved = SavedPlayback(
          queueIds: const [1, 2, 3],
          originalIds: const [1, 2, 3],
          index: 1,
          positionMs: 5000,
          shuffle: false,
          repeat: RepeatSetting.off,
        );
        missing = {lib[1].path};
        await c.restore(saved, {for (final t in lib) t.id: t});
        expect(ids(), [1, 3]);
        expect(engine.pos, Duration.zero);
      },
    );

    test(
      'restored shuffle can still be turned off to the original order',
      () async {
        await c.playTracks(lib, startIndex: 1);
        await c.toggleShuffle();
        c.persistNow();
        final saved = store.saved!;
        final c2 = PlaybackController(
          engine: FakeAudioEngine(),
          store: MemoryPlaybackStore(),
          fileExists: (_) => true,
        );
        await c2.restore(saved, {for (final t in lib) t.id: t});
        expect(c2.state.shuffle, isTrue);
        await c2.toggleShuffle();
        expect(
          [for (final e in c2.state.queue) e.track.id],
          [1, 2, 3, 4, 5, 6],
        );
        await c2.dispose();
      },
    );

    test('SavedPlayback JSON round-trips and rejects garbage', () {
      final s = SavedPlayback(
        queueIds: const [1, 2],
        originalIds: const [2, 1],
        index: 1,
        positionMs: 9,
        shuffle: true,
        repeat: RepeatSetting.all,
      );
      final back = SavedPlayback.fromJson(s.toJson())!;
      expect(back.queueIds, [1, 2]);
      expect(back.originalIds, [2, 1]);
      expect(back.repeat, RepeatSetting.all);
      expect(SavedPlayback.fromJson('nope'), isNull);
      expect(SavedPlayback.fromJson({'queue': []}), isNull);
      expect(
        SavedPlayback.fromJson({
          'queue': [1],
        }),
        isNull,
      );
    });
  });
}
