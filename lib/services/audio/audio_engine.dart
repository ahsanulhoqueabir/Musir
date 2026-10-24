import '../../data/models/track.dart';

enum RepeatMode { off, all, one }

enum EngineStatus { idle, loading, ready, completed }

/// One slot in the play queue. [uid] is unique per slot so the same track can
/// be queued twice and a reorderable list can key on it.
class QueueEntry {
  const QueueEntry(this.uid, this.track);

  final int uid;
  final Track track;
}

class EngineError {
  const EngineError(this.message, {this.index});

  final String message;

  /// Index of the failing queue item, when known.
  final int? index;
}

/// The platform audio player as the playback controller sees it.
///
/// Index arguments always refer to the engine's own queue, which mirrors the
/// controller's play order one-to-one.
abstract interface class AudioEngine {
  Stream<int?> get currentIndex;
  Stream<bool> get playing;
  Stream<EngineStatus> get status;
  Stream<Duration> get position;
  Stream<Duration?> get duration;
  Stream<EngineError> get errors;
  Duration get currentPosition;

  /// Replaces the queue. Throws [EngineException] if the item at [index]
  /// cannot be loaded.
  Future<void> setQueue(
    List<QueueEntry> entries, {
    required int index,
    Duration position = Duration.zero,
  });

  Future<void> insert(int index, List<QueueEntry> entries);
  Future<void> removeAt(int index);

  /// Moves the item at [from] so it ends up at [to].
  Future<void> move(int from, int to);

  /// Keeps the item that is playing and swaps everything around it, without
  /// interrupting playback (used to shuffle/unshuffle).
  Future<void> reorderAround({
    required List<QueueEntry> before,
    required List<QueueEntry> after,
  });

  /// Starts or resumes playback. Returns immediately.
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position, {int? index});
  Future<void> setRepeat(RepeatMode mode);
  Future<void> setSkipSilence(bool enabled);
  Future<void> dispose();
}

class EngineException implements Exception {
  const EngineException(this.message, {this.index});

  final String message;
  final int? index;

  @override
  String toString() => 'EngineException($message, index: $index)';
}
