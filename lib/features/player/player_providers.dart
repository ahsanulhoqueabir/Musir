import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../services/audio/audio_engine.dart';
import '../../services/audio/just_audio_engine.dart';
import '../../services/audio/playback_store.dart';
import '../settings/settings_state.dart';
import 'playback_controller.dart';
import 'player_state.dart';

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = JustAudioEngine();
  return engine;
});

final playbackStoreProvider = Provider<PlaybackStore>(
  (ref) => PrefsPlaybackStore(ref.watch(sharedPreferencesProvider)),
);

/// Overridable so tests don't depend on real files.
final fileExistsProvider = Provider<FileExists>((ref) => defaultFileExists);

final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final history = ref.watch(historyRepositoryProvider);
  final controller = PlaybackController(
    engine: ref.watch(audioEngineProvider),
    store: ref.watch(playbackStoreProvider),
    fileExists: ref.watch(fileExistsProvider),
    onTrackStarted: (id) => unawaited(history.record(id)),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

class PlayerStateNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    final controller = ref.watch(playbackControllerProvider);
    final sub = controller.stream.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return controller.state;
  }
}

final playerStateProvider = NotifierProvider<PlayerStateNotifier, PlayerState>(
  PlayerStateNotifier.new,
);

/// Fine-grained selectors so a position tick never rebuilds the whole player.
final currentTrackProvider = Provider(
  (ref) => ref.watch(playerStateProvider.select((s) => s.currentTrack)),
);

final isPlayingProvider = Provider<bool>(
  (ref) => ref.watch(playerStateProvider.select((s) => s.playing)),
);

final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(playbackControllerProvider).position,
);

final engineDurationProvider = StreamProvider<Duration?>(
  (ref) => ref.watch(playbackControllerProvider).duration,
);

/// Runs once at startup: restores the last queue (paused) and scans.
final bootstrapProvider = FutureProvider<void>((ref) async {
  final controller = ref.read(playbackControllerProvider);
  final settings = ref.read(settingsProvider);
  await controller.setSkipSilence(settings.skipSilence);
  if (settings.restoreQueue) {
    final saved = await ref.read(playbackStoreProvider).load();
    if (saved != null) {
      final tracks = await ref.read(libraryRepositoryProvider).getTracks();
      await controller.restore(saved, {for (final t in tracks) t.id: t});
    }
  }
});
