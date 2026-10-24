import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'audio_engine.dart';

/// [AudioEngine] backed by `just_audio`. Notification, lock-screen and media
/// button integration comes from `just_audio_background`, which reads the
/// [MediaItem] tag on every source (`JustAudioBackground.init` must have run).
class JustAudioEngine implements AudioEngine {
  JustAudioEngine({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  AudioSource _source(QueueEntry e) {
    final t = e.track;
    final art = t.artworkPath;
    return AudioSource.file(
      t.path,
      tag: MediaItem(
        id: '${e.uid}:${t.id}',
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration: t.durationMs > 0 ? t.duration : null,
        artUri: art == null ? null : Uri.file(art),
      ),
    );
  }

  @override
  Stream<int?> get currentIndex => _player.currentIndexStream;

  @override
  Stream<bool> get playing => _player.playingStream;

  @override
  Stream<EngineStatus> get status => _player.processingStateStream.map(
    (s) => switch (s) {
      ProcessingState.idle => EngineStatus.idle,
      ProcessingState.loading ||
      ProcessingState.buffering => EngineStatus.loading,
      ProcessingState.ready => EngineStatus.ready,
      ProcessingState.completed => EngineStatus.completed,
    },
  );

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<Duration?> get duration => _player.durationStream;

  @override
  Stream<EngineError> get errors => _player.errorStream.map(
    (e) => EngineError(e.message ?? 'Playback error', index: e.index),
  );

  @override
  Duration get currentPosition => _player.position;

  @override
  Future<void> setQueue(
    List<QueueEntry> entries, {
    required int index,
    Duration position = Duration.zero,
  }) async {
    try {
      await _player.setAudioSources(
        [for (final e in entries) _source(e)],
        initialIndex: index,
        initialPosition: position,
      );
    } on PlayerException catch (e) {
      throw EngineException(e.message ?? 'Unable to load audio', index: index);
    } on PlayerInterruptedException {
      // A newer setQueue superseded this one; nothing to report.
    }
  }

  @override
  Future<void> insert(int index, List<QueueEntry> entries) =>
      _player.insertAudioSources(index, [for (final e in entries) _source(e)]);

  @override
  Future<void> removeAt(int index) => _player.removeAudioSourceAt(index);

  @override
  Future<void> move(int from, int to) => _player.moveAudioSource(from, to);

  @override
  Future<void> reorderAround({
    required List<QueueEntry> before,
    required List<QueueEntry> after,
  }) async {
    final current = _player.currentIndex ?? 0;
    final length = _player.sequence.length;
    if (current + 1 < length) {
      await _player.removeAudioSourceRange(current + 1, length);
    }
    if (current > 0) await _player.removeAudioSourceRange(0, current);
    if (after.isNotEmpty) {
      await _player.insertAudioSources(1, [for (final e in after) _source(e)]);
    }
    if (before.isNotEmpty) {
      await _player.insertAudioSources(0, [for (final e in before) _source(e)]);
    }
  }

  @override
  Future<void> play() async {
    // just_audio's play() future only completes when playback pauses or ends,
    // so it must not be awaited.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position, {int? index}) =>
      _player.seek(position, index: index);

  @override
  Future<void> setRepeat(RepeatSetting mode) =>
      _player.setLoopMode(switch (mode) {
        RepeatSetting.off => LoopMode.off,
        RepeatSetting.all => LoopMode.all,
        RepeatSetting.one => LoopMode.one,
      });

  @override
  Future<void> setSkipSilence(bool enabled) =>
      _player.setSkipSilenceEnabled(enabled);

  @override
  Future<void> dispose() => _player.dispose();
}
