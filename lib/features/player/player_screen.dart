import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/track_actions.dart';
import '../../core/widgets/track_artwork.dart';
import '../../services/audio/audio_engine.dart';
import 'mini_player.dart';
import 'player_providers.dart';
import 'queue_sheet.dart';
import 'seek_bar.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final theme = Theme.of(context);

    if (track == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close player',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: const EmptyState(
          icon: Icons.music_off_rounded,
          title: 'Nothing is playing',
          message: 'Pick a song from your library to start listening.',
        ),
      );
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              // Fill the screen when there is room (content spreads out via
              // spaceBetween); scroll instead of overflowing when there isn't
              // (small screens, large text).
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Swipe down on the header/artwork to close. The seek bar
                    // and controls are deliberately outside this gesture.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) > 600) context.pop();
                      },
                      child: Column(
                        children: [
                          const _Header(),
                          const SizedBox(height: Space.lg),
                          _Artwork(
                            key: ValueKey(track.id),
                            artworkPath: track.artworkPath,
                            seed: track.album,
                            animate: !reduceMotion,
                          ),
                        ],
                      ),
                    ),
                    const Column(
                      children: [
                        SizedBox(height: Space.xl),
                        _TitleRow(),
                        SizedBox(height: Space.sm),
                        SeekBar(),
                        SizedBox(height: Space.sm),
                        _Controls(),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: Space.lg, bottom: Space.sm),
                      child: _BottomBar(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final track = ref.watch(currentTrackProvider);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close player',
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Text(
              'Now playing',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: track == null
                ? null
                : () => showTrackActions(context, ref, track),
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    super.key,
    required this.artworkPath,
    required this.seed,
    required this.animate,
  });

  final String? artworkPath;
  final String seed;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = MediaQuery.sizeOf(context).height;
        // Fit width, but never let the artwork eat more than ~42% of height.
        final size = math.max(
          160.0,
          math.min(constraints.maxWidth, height * 0.42),
        );
        final art = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: Corners.lgAll,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: TrackArtwork(
            size: size,
            artworkPath: artworkPath,
            seed: seed,
            radius: Corners.lg,
            iconSize: size * 0.3,
          ),
        );
        return Hero(
          tag: artworkHeroTag,
          child: animate
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.94, end: 1),
                  duration: Motion.normal,
                  curve: Curves.easeOutCubic,
                  builder: (_, scale, child) => Opacity(
                    opacity: ((scale - 0.94) / 0.06).clamp(0.0, 1.0),
                    child: Transform.scale(scale: scale, child: child),
                  ),
                  child: art,
                )
              : art,
        );
      },
    );
  }
}

class _TitleRow extends ConsumerWidget {
  const _TitleRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isFav = ref.watch(isFavoriteProvider(track.id));

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Space.xs),
              InkWell(
                borderRadius: Corners.smAll,
                onTap: () => context.push('/artist/${track.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
          iconSize: 28,
          isSelected: isFav,
          icon: const Icon(Icons.favorite_border_rounded),
          selectedIcon: Icon(
            Icons.favorite_rounded,
            color: theme.colorScheme.primary,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(favoritesRepositoryProvider).toggle(track.id);
          },
        ),
      ],
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuffle = ref.watch(playerStateProvider.select((s) => s.shuffle));
    final repeat = ref.watch(playerStateProvider.select((s) => s.repeat));
    final playing = ref.watch(isPlayingProvider);
    final loading = ref.watch(playerStateProvider.select((s) => s.loading));
    final hasNext = ref.watch(playerStateProvider.select((s) => s.hasNext));
    final repeatAll = repeat == RepeatSetting.all;
    final playback = ref.read(playbackControllerProvider);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 320dp-wide phones can't fit the full-size row.
        final compact = constraints.maxWidth < 300;
        final skipSize = compact ? 32.0 : 38.0;
        final playSize = compact ? 64.0 : 72.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: shuffle ? 'Shuffle on' : 'Shuffle off',
              isSelected: shuffle,
              style: shuffle
                  ? IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                    )
                  : null,
              icon: const Icon(Icons.shuffle_rounded),
              onPressed: () {
                HapticFeedback.selectionClick();
                playback.toggleShuffle();
              },
            ),
            IconButton(
              tooltip: 'Previous',
              iconSize: skipSize,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: () {
                HapticFeedback.selectionClick();
                playback.previous();
              },
            ),
            SizedBox.square(
              dimension: playSize,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                onPressed: loading
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        playback.togglePlayPause();
                      },
                child: Semantics(
                  label: playing ? 'Pause' : 'Play',
                  child: loading
                      ? SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: Motion.fast,
                          child: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            key: ValueKey(playing),
                            size: 40,
                          ),
                        ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next',
              iconSize: skipSize,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: (hasNext || repeatAll)
                  ? () {
                      HapticFeedback.selectionClick();
                      playback.next();
                    }
                  : null,
            ),
            IconButton(
              tooltip: switch (repeat) {
                RepeatSetting.off => 'Repeat off',
                RepeatSetting.all => 'Repeat all',
                RepeatSetting.one => 'Repeat one',
              },
              isSelected: repeat != RepeatSetting.off,
              style: repeat != RepeatSetting.off
                  ? IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                    )
                  : null,
              icon: Icon(
                repeat == RepeatSetting.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                playback.cycleRepeat();
              },
            ),
          ],
        );
      },
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.read(playbackControllerProvider);
    final track = ref.watch(currentTrackProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Back 10 seconds',
          icon: const Icon(Icons.replay_10_rounded),
          onPressed: () => playback.seekBy(const Duration(seconds: -10)),
        ),
        TextButton.icon(
          onPressed: () => showQueueSheet(context),
          icon: const Icon(Icons.queue_music_rounded),
          label: const Text('Queue'),
        ),
        if (track != null)
          IconButton(
            tooltip: 'Go to album',
            icon: const Icon(Icons.album_rounded),
            onPressed: () => context.push('/album/${track.id}'),
          ),
        IconButton(
          tooltip: 'Forward 10 seconds',
          icon: const Icon(Icons.forward_10_rounded),
          onPressed: () => playback.seekBy(const Duration(seconds: 10)),
        ),
      ],
    );
  }
}
