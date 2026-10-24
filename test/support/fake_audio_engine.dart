import 'dart:async';

import 'package:musir/services/audio/audio_engine.dart';
import 'package:musir/services/audio/playback_store.dart';

/// In-memory [AudioEngine] that mimics just_audio's index bookkeeping.
class FakeAudioEngine implements AudioEngine {
  final _index = StreamController<int?>.broadcast(sync: true);
  final _playing = StreamController<bool>.broadcast(sync: true);
  final _status = StreamController<EngineStatus>.broadcast(sync: true);
  final _errors = StreamController<EngineError>.broadcast(sync: true);

  List<QueueEntry> queue = [];
  int? index;
  bool isPlaying = false;
  Duration pos = Duration.zero;
  RepeatSetting repeat = RepeatSetting.off;
  bool skipSilence = false;
  bool disposed = false;
  Set<String> failPaths = {};
  int setQueueCalls = 0;

  List<int> get trackIds => [for (final e in queue) e.track.id];

  void _setIndex(int? i) {
    index = i;
    _index.add(i);
  }

  /// Simulates the player finishing the current item.
  void finishCurrent() {
    final i = index!;
    if (repeat == RepeatSetting.one) return;
    if (i + 1 < queue.length) {
      pos = Duration.zero;
      _setIndex(i + 1);
    } else if (repeat == RepeatSetting.all) {
      pos = Duration.zero;
      _setIndex(0);
    } else {
      _status.add(EngineStatus.completed);
    }
  }

  void emitError(String message, {int? at}) =>
      _errors.add(EngineError(message, index: at ?? index));

  @override
  Stream<int?> get currentIndex => _index.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<EngineStatus> get status => _status.stream;
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<Duration?> get duration => const Stream.empty();
  @override
  Stream<EngineError> get errors => _errors.stream;
  @override
  Duration get currentPosition => pos;

  @override
  Future<void> setQueue(
    List<QueueEntry> entries, {
    required int index,
    Duration position = Duration.zero,
  }) async {
    setQueueCalls++;
    if (failPaths.contains(entries[index].track.path)) {
      throw EngineException('boom', index: index);
    }
    queue = [...entries];
    pos = position;
    _setIndex(index);
    _status.add(EngineStatus.ready);
  }

  @override
  Future<void> insert(int at, List<QueueEntry> entries) async {
    queue.insertAll(at, entries);
    if (index != null && at <= index!) _setIndex(index! + entries.length);
  }

  @override
  Future<void> removeAt(int at) async {
    queue.removeAt(at);
    if (index != null && at < index!) _setIndex(index! - 1);
  }

  @override
  Future<void> move(int from, int to) async {
    final cur = index!;
    queue.insert(to, queue.removeAt(from));
    if (from == cur) {
      _setIndex(to);
    } else if (from < cur && to >= cur) {
      _setIndex(cur - 1);
    } else if (from > cur && to <= cur) {
      _setIndex(cur + 1);
    }
  }

  @override
  Future<void> reorderAround({
    required List<QueueEntry> before,
    required List<QueueEntry> after,
  }) async {
    final current = queue[index!];
    queue = [...before, current, ...after];
    _setIndex(before.length);
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> stop() async {
    isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position, {int? index}) async {
    pos = position;
    if (index != null) _setIndex(index);
  }

  @override
  Future<void> setRepeat(RepeatSetting mode) async => repeat = mode;

  @override
  Future<void> setSkipSilence(bool enabled) async => skipSilence = enabled;

  @override
  Future<void> dispose() async => disposed = true;
}

class MemoryPlaybackStore implements PlaybackStore {
  SavedPlayback? saved;

  @override
  Future<SavedPlayback?> load() async => saved;

  @override
  Future<void> save(SavedPlayback? playback) async => saved = playback;
}
