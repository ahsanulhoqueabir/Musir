import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../data/models/track.dart';
import '../../services/audio/audio_engine.dart';
import '../../services/audio/playback_store.dart';
import 'player_state.dart';

typedef FileExists = bool Function(String path);

bool defaultFileExists(String path) => File(path).existsSync();

/// Owns the play queue and playback state; drives an [AudioEngine].
///
/// Shuffle physically reorders the queue (current track first) rather than
/// using the engine's hidden shuffle order, so the queue the user sees and
/// edits is always the real play order. [_original] keeps the pre-shuffle
/// order so turning shuffle off restores it.
class PlaybackController {
  PlaybackController({
    required this._engine,
    required this._store,
    this._fileExists = defaultFileExists,
    this._onTrackStarted,
    Random? random,
  }) : _random = random ?? Random() {
    _subs
      ..add(_engine.currentIndex.listen(_onEngineIndex))
      ..add(_engine.playing.listen(_onEnginePlaying))
      ..add(_engine.status.listen(_onEngineStatus))
      ..add(_engine.errors.listen(_onEngineError));
  }

  final AudioEngine _engine;
  final PlaybackStore _store;
  final FileExists _fileExists;
  final void Function(int trackId)? _onTrackStarted;
  final Random _random;
  final _subs = <StreamSubscription<Object?>>[];
  final _controller = StreamController<PlayerState>.broadcast(sync: true);

  PlayerState _state = const PlayerState();
  List<QueueEntry>? _original;
  int _nextUid = 1;
  int _noticeId = 0;
  int? _startedUid;
  bool _disposed = false;

  PlayerState get state => _state;
  Stream<PlayerState> get stream => _controller.stream;
  Stream<Duration> get position => _engine.position;
  Stream<Duration?> get duration => _engine.duration;

  /// Whether to restart a track instead of going back when it has played
  /// longer than this.
  static const previousRestartThreshold = Duration(seconds: 3);

  void _emit(PlayerState s) {
    if (_disposed) return;
    _state = s;
    _controller.add(s);
  }

  void _notify(String message) {
    _emit(_state.copyWith(notice: PlayerNotice(++_noticeId, message)));
  }

  QueueEntry _entry(Track t) => QueueEntry(_nextUid++, t);

  // ---------------------------------------------------------------- starting

  /// Replaces the queue with [tracks] and starts playing [startIndex].
  /// Files that no longer exist are dropped. If shuffle is on (or
  /// [forceShuffle]), the tapped track plays first and the rest are shuffled.
  Future<void> playTracks(
    List<Track> tracks, {
    int startIndex = 0,
    bool? forceShuffle,
  }) async {
    if (tracks.isEmpty) return;
    final start = tracks[startIndex.clamp(0, tracks.length - 1)];
    final entries = <QueueEntry>[];
    QueueEntry? startEntry;
    var missing = 0;
    for (final t in tracks) {
      if (!_fileExists(t.path)) {
        missing++;
        continue;
      }
      final e = _entry(t);
      entries.add(e);
      if (identical(t, start)) startEntry = e;
    }
    if (entries.isEmpty) {
      _notify('These files are no longer available.');
      return;
    }
    if (missing > 0) {
      _notify(
        missing == 1
            ? '1 file is missing and was skipped.'
            : '$missing files are missing and were skipped.',
      );
    }
    startEntry ??= entries[min(startIndex, entries.length - 1)];
    final shuffle = forceShuffle ?? _state.shuffle;
    List<QueueEntry> order;
    if (shuffle) {
      _original = entries;
      final rest = entries.where((e) => e != startEntry).toList()
        ..shuffle(_random);
      order = [startEntry, ...rest];
    } else {
      _original = null;
      order = entries;
    }
    await _load(order, order.indexOf(startEntry), shuffle: shuffle);
  }

  Future<void> _load(
    List<QueueEntry> order,
    int index, {
    required bool shuffle,
    Duration position = Duration.zero,
    bool play = true,
  }) async {
    var queue = [...order];
    var i = index;
    _startedUid = null;
    // A file can exist yet be undecodable; drop it and try the next one.
    while (queue.isNotEmpty) {
      _emit(
        _state.copyWith(
          queue: queue,
          currentIndex: i,
          shuffle: shuffle,
          loading: true,
        ),
      );
      try {
        await _engine.setQueue(queue, index: i, position: position);
        break;
      } on EngineException {
        final bad = queue[i];
        _notify('Can\'t play "${bad.track.title}".');
        queue = [...queue]..removeAt(i);
        _original = _original?.where((e) => e != bad).toList();
        if (queue.isEmpty) break;
        i = min(i, queue.length - 1);
        position = Duration.zero;
      }
    }
    if (queue.isEmpty) {
      _original = null;
      _emit(
        _state.copyWith(
          queue: const [],
          currentIndex: null,
          playing: false,
          loading: false,
        ),
      );
      return;
    }
    _emit(_state.copyWith(queue: queue, currentIndex: i, loading: false));
    await _engine.setRepeat(_state.repeat);
    if (play) await _engine.play();
    _persist();
  }

  // ----------------------------------------------------------- transport

  Future<void> play() async {
    if (!_state.hasQueue) return;
    await _engine.play();
  }

  Future<void> pause() => _engine.pause();

  Future<void> togglePlayPause() => _state.playing ? pause() : play();

  Future<void> stop() async {
    await _engine.stop();
    _persist();
  }

  Future<void> seek(Duration position) => _engine.seek(position);

  Future<void> seekBy(Duration delta) async {
    final target = _engine.currentPosition + delta;
    await _engine.seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> next() async {
    final i = _state.currentIndex;
    if (i == null) return;
    if (_state.hasNext) {
      await _engine.seek(Duration.zero, index: i + 1);
    } else if (_state.repeat == RepeatMode.all && _state.queue.length > 1) {
      await _engine.seek(Duration.zero, index: 0);
    } else if (_state.repeat == RepeatMode.all) {
      await _engine.seek(Duration.zero);
    }
    // At the end with repeat off: nothing to skip to.
  }

  Future<void> previous() async {
    final i = _state.currentIndex;
    if (i == null) return;
    final restart = _engine.currentPosition > previousRestartThreshold;
    if (restart || (!_state.hasPrevious && _state.repeat != RepeatMode.all)) {
      await _engine.seek(Duration.zero);
    } else if (_state.hasPrevious) {
      await _engine.seek(Duration.zero, index: i - 1);
    } else {
      await _engine.seek(Duration.zero, index: _state.queue.length - 1);
    }
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _state.queue.length) return;
    await _engine.seek(Duration.zero, index: index);
    await _engine.play();
  }

  // --------------------------------------------------------------- modes

  Future<void> setRepeat(RepeatMode mode) async {
    _emit(_state.copyWith(repeat: mode));
    await _engine.setRepeat(mode);
    _persist();
  }

  Future<void> cycleRepeat() => setRepeat(
    RepeatMode.values[(_state.repeat.index + 1) % RepeatMode.values.length],
  );

  Future<void> setSkipSilence(bool enabled) => _engine.setSkipSilence(enabled);

  Future<void> toggleShuffle() async {
    final enabling = !_state.shuffle;
    final i = _state.currentIndex;
    if (!_state.hasQueue || i == null) {
      _emit(_state.copyWith(shuffle: enabling));
      return;
    }
    final queue = _state.queue;
    final current = queue[i];
    if (enabling) {
      _original = [...queue];
      final rest = [...queue]..removeAt(i);
      rest.shuffle(_random);
      await _engine.reorderAround(before: const [], after: rest);
      _emit(
        _state.copyWith(
          queue: [current, ...rest],
          currentIndex: 0,
          shuffle: true,
        ),
      );
    } else {
      final original = (_original ?? queue).where(queue.contains).toList();
      final pos = original.indexOf(current);
      await _engine.reorderAround(
        before: original.sublist(0, pos),
        after: original.sublist(pos + 1),
      );
      _original = null;
      _emit(
        _state.copyWith(queue: original, currentIndex: pos, shuffle: false),
      );
    }
    _persist();
  }

  // ------------------------------------------------------- queue editing

  /// Inserts [tracks] directly after the current track.
  Future<void> playNext(List<Track> tracks) =>
      _insert(tracks, afterCurrent: true);

  /// Appends [tracks] to the end of the queue.
  Future<void> addToQueue(List<Track> tracks) =>
      _insert(tracks, afterCurrent: false);

  Future<void> _insert(List<Track> tracks, {required bool afterCurrent}) async {
    final playable = tracks.where((t) => _fileExists(t.path)).toList();
    if (playable.isEmpty) return;
    if (!_state.hasQueue) {
      await playTracks(playable);
      return;
    }
    final entries = [for (final t in playable) _entry(t)];
    final cur = _state.currentIndex ?? -1;
    final at = afterCurrent ? cur + 1 : _state.queue.length;
    await _engine.insert(at, entries);
    final queue = [..._state.queue]..insertAll(at, entries);
    final original = _original;
    if (original != null) {
      final curEntry = _state.currentEntry;
      final oAt = afterCurrent && curEntry != null
          ? original.indexOf(curEntry) + 1
          : original.length;
      _original = [...original]..insertAll(oAt, entries);
    }
    _emit(_state.copyWith(queue: queue));
    _persist();
  }

  Future<void> removeAt(int index) async {
    final queue = _state.queue;
    final cur = _state.currentIndex;
    if (index < 0 || index >= queue.length || cur == null) return;
    final removed = queue[index];
    if (queue.length == 1) {
      await clearQueue();
      return;
    }
    if (index == cur) {
      // Removing what's playing: reload around the neighbour that takes over.
      final remaining = [...queue]..removeAt(index);
      _original = _original?.where((e) => e != removed).toList();
      await _load(
        remaining,
        min(index, remaining.length - 1),
        shuffle: _state.shuffle,
        play: _state.playing,
      );
      return;
    }
    await _engine.removeAt(index);
    _original = _original?.where((e) => e != removed).toList();
    _emit(
      _state.copyWith(
        queue: [...queue]..removeAt(index),
        currentIndex: index < cur ? cur - 1 : cur,
      ),
    );
    _persist();
  }

  /// Moves the queue item at [from] so it ends up at index [to].
  Future<void> move(int from, int to) async {
    final queue = _state.queue;
    final cur = _state.currentIndex;
    if (cur == null || from == to) return;
    if (from < 0 || from >= queue.length || to < 0 || to >= queue.length) {
      return;
    }
    await _engine.move(from, to);
    final next = [...queue];
    next.insert(to, next.removeAt(from));
    int newCur = cur;
    if (from == cur) {
      newCur = to;
    } else if (from < cur && to >= cur) {
      newCur = cur - 1;
    } else if (from > cur && to <= cur) {
      newCur = cur + 1;
    }
    _emit(_state.copyWith(queue: next, currentIndex: newCur));
    _persist();
  }

  Future<void> clearQueue() async {
    await _engine.stop();
    _original = null;
    _startedUid = null;
    _emit(
      _state.copyWith(
        queue: const [],
        currentIndex: null,
        playing: false,
        loading: false,
      ),
    );
    await _store.save(null);
  }

  // ------------------------------------------------------------ restoring

  /// Rebuilds the queue from [saved] using [library] (track id lookup) and
  /// leaves playback paused.
  Future<void> restore(SavedPlayback saved, Map<int, Track> library) async {
    if (_state.hasQueue) return;
    final byId = <int, QueueEntry>{};
    QueueEntry? entryFor(int id) {
      final t = library[id];
      if (t == null || !_fileExists(t.path)) return null;
      return byId.putIfAbsent(id, () => _entry(t));
    }

    final currentId = saved.queueIds[saved.index];
    final order = [for (final id in saved.queueIds) ?entryFor(id)];
    if (order.isEmpty) return;
    var index = order.indexWhere((e) => e.track.id == currentId);
    var position = Duration(milliseconds: saved.positionMs);
    if (index < 0) {
      index = min(saved.index, order.length - 1);
      position = Duration.zero;
    }
    _original = saved.shuffle
        ? [for (final id in saved.originalIds) ?byId[id]]
        : null;
    _emit(_state.copyWith(repeat: saved.repeat));
    await _load(
      order,
      index,
      shuffle: saved.shuffle,
      position: position,
      play: false,
    );
  }

  void _persist() {
    final i = _state.currentIndex;
    if (!_state.hasQueue || i == null) return;
    unawaited(
      _store.save(
        SavedPlayback(
          queueIds: [for (final e in _state.queue) e.track.id],
          originalIds: [
            for (final e in (_original ?? _state.queue)) e.track.id,
          ],
          index: i,
          positionMs: _engine.currentPosition.inMilliseconds,
          shuffle: _state.shuffle,
          repeat: _state.repeat,
        ),
      ),
    );
  }

  /// Saves the current position (call when the app goes to the background).
  void persistNow() => _persist();

  // ------------------------------------------------------- engine events

  void _onEngineIndex(int? index) {
    if (index == null || index == _state.currentIndex) {
      _maybeRecordStart();
      return;
    }
    if (index < 0 || index >= _state.queue.length) return;
    _emit(_state.copyWith(currentIndex: index));
    _maybeRecordStart();
    _persist();
  }

  void _onEnginePlaying(bool playing) {
    if (playing == _state.playing) return;
    _emit(_state.copyWith(playing: playing));
    _maybeRecordStart();
  }

  void _onEngineStatus(EngineStatus status) {
    final loading = status == EngineStatus.loading;
    if (loading != _state.loading) {
      _emit(_state.copyWith(loading: loading));
    }
    if (status == EngineStatus.completed && _state.hasQueue) {
      // Queue finished with repeat off: rewind to the first track, paused, so
      // pressing play starts the queue again.
      unawaited(() async {
        await _engine.pause();
        await _engine.seek(Duration.zero, index: 0);
      }());
    }
  }

  void _onEngineError(EngineError error) {
    final entry = _state.currentEntry;
    final name = entry?.track.title ?? 'this track';
    _notify('Can\'t play "$name". Skipping.');
    if (_state.hasNext) {
      unawaited(_engine.seek(Duration.zero, index: _state.currentIndex! + 1));
    } else {
      unawaited(_engine.pause());
    }
  }

  void _maybeRecordStart() {
    final entry = _state.currentEntry;
    if (entry == null || !_state.playing || _startedUid == entry.uid) return;
    _startedUid = entry.uid;
    _onTrackStarted?.call(entry.track.id);
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final s in _subs) {
      await s.cancel();
    }
    await _controller.close();
    await _engine.dispose();
  }
}
