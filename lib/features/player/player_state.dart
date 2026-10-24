import 'package:flutter/foundation.dart';

import '../../data/models/track.dart';
import '../../services/audio/audio_engine.dart';

@immutable
class PlayerNotice {
  const PlayerNotice(this.id, this.message);

  /// Increases for every notice so listeners can tell repeats apart.
  final int id;
  final String message;
}

@immutable
class PlayerState {
  const PlayerState({
    this.queue = const [],
    this.currentIndex,
    this.playing = false,
    this.loading = false,
    this.shuffle = false,
    this.repeat = RepeatSetting.off,
    this.notice,
  });

  /// Play order. With shuffle on this is the shuffled order.
  final List<QueueEntry> queue;
  final int? currentIndex;
  final bool playing;
  final bool loading;
  final bool shuffle;
  final RepeatSetting repeat;
  final PlayerNotice? notice;

  QueueEntry? get currentEntry {
    final i = currentIndex;
    return (i != null && i >= 0 && i < queue.length) ? queue[i] : null;
  }

  Track? get currentTrack => currentEntry?.track;

  bool get hasQueue => queue.isNotEmpty;
  bool get hasNext => currentIndex != null && currentIndex! < queue.length - 1;
  bool get hasPrevious => currentIndex != null && currentIndex! > 0;

  PlayerState copyWith({
    List<QueueEntry>? queue,
    Object? currentIndex = _unset,
    bool? playing,
    bool? loading,
    bool? shuffle,
    RepeatSetting? repeat,
    PlayerNotice? notice,
  }) => PlayerState(
    queue: queue ?? this.queue,
    currentIndex: identical(currentIndex, _unset)
        ? this.currentIndex
        : currentIndex as int?,
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    notice: notice ?? this.notice,
  );
}

const Object _unset = Object();
