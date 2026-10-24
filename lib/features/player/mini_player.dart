import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/tokens.dart';
import '../../core/widgets/track_artwork.dart';
import 'player_providers.dart';

const String artworkHeroTag = 'now-playing-artwork';

/// Compact player shown above the navigation bar whenever a queue exists.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final playing = ref.watch(isPlayingProvider);
    final loading = ref.watch(playerStateProvider.select((s) => s.loading));
    final hasNext = ref.watch(playerStateProvider.select((s) => s.hasNext));
    final playback = ref.read(playbackControllerProvider);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => context.push('/player'),
        child: ConstrainedBox(
          // Grows with the system text size instead of clipping.
          constraints: const BoxConstraints(minHeight: Sizes.miniPlayerHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _MiniProgress(),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.md,
                    vertical: Space.xs,
                  ),
                  child: Row(
                    children: [
                      Hero(
                        tag: artworkHeroTag,
                        child: TrackArtwork(
                          size: 44,
                          artworkPath: track.artworkPath,
                          seed: track.album,
                          radius: Corners.sm,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Semantics(
                          label:
                              'Now playing: ${track.title} by ${track.artist}. Open player',
                          excludeSemantics: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      loading
                          ? const SizedBox(
                              width: Sizes.touch,
                              height: Sizes.touch,
                              child: Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: playing ? 'Pause' : 'Play',
                              iconSize: 30,
                              icon: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                playback.togglePlayPause();
                              },
                            ),
                      IconButton(
                        tooltip: 'Next',
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: hasNext
                            ? () {
                                HapticFeedback.selectionClick();
                                playback.next();
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hairline progress; isolated so position ticks only rebuild this widget.
class _MiniProgress extends ConsumerWidget {
  const _MiniProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final total = ref.watch(engineDurationProvider).value ?? track?.duration;
    final fraction = (total == null || total.inMilliseconds == 0)
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return LinearProgressIndicator(
      value: fraction,
      minHeight: 2,
      backgroundColor: Colors.transparent,
    );
  }
}
