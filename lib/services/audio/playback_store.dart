import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'audio_engine.dart';

/// Snapshot of the queue so playback can be restored after a restart.
class SavedPlayback {
  const SavedPlayback({
    required this.queueIds,
    required this.originalIds,
    required this.index,
    required this.positionMs,
    required this.shuffle,
    required this.repeat,
  });

  /// Track ids in play order.
  final List<int> queueIds;

  /// Track ids in pre-shuffle order (equals [queueIds] when not shuffled).
  final List<int> originalIds;
  final int index;
  final int positionMs;
  final bool shuffle;
  final RepeatSetting repeat;

  Map<String, Object?> toJson() => {
    'queue': queueIds,
    'original': originalIds,
    'index': index,
    'positionMs': positionMs,
    'shuffle': shuffle,
    'repeat': repeat.name,
  };

  static SavedPlayback? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final queue = (json['queue'] as List).cast<int>();
      if (queue.isEmpty) return null;
      final index = json['index'] as int;
      return SavedPlayback(
        queueIds: queue,
        originalIds: (json['original'] as List).cast<int>(),
        index: index.clamp(0, queue.length - 1),
        positionMs: json['positionMs'] as int,
        shuffle: json['shuffle'] as bool,
        repeat: RepeatSetting.values.byName(json['repeat'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

abstract interface class PlaybackStore {
  Future<void> save(SavedPlayback? playback);
  Future<SavedPlayback?> load();
}

class PrefsPlaybackStore implements PlaybackStore {
  PrefsPlaybackStore(this._prefs);

  static const _key = 'playback.snapshot';
  final SharedPreferences _prefs;

  @override
  Future<void> save(SavedPlayback? playback) async {
    if (playback == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(_key, jsonEncode(playback.toJson()));
    }
  }

  @override
  Future<SavedPlayback?> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return SavedPlayback.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
