import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/library_gate.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/track_artwork.dart';
import '../../data/models/track.dart';
import '../library/library_tab_state.dart';
import '../player/player_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.lg,
                Space.gutter,
                Space.sm,
              ),
              child: Row(
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Musir'),
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            const _SearchEntry(),
            const Expanded(child: LibraryGate(child: _HomeContent())),
          ],
        ),
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter,
        vertical: Space.sm,
      ),
      child: Semantics(
        button: true,
        label: 'Search songs, artists and albums',
        excludeSemantics: true,
        child: Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => context.push('/search'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Sizes.touch + 4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(
                        'Search songs, artists, albums',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyPlayedProvider);
    final added = ref.watch(recentlyAddedProvider);

    return CustomScrollView(
      key: const PageStorageKey('home'),
      slivers: [
        const SliverToBoxAdapter(child: _QuickAccess()),
        if (recent.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Recently played',
              onSeeAll: () => context.push('/recent'),
            ),
          ),
          SliverToBoxAdapter(
            child: _TrackCarousel(tracks: recent.take(15).toList()),
          ),
        ],
        const SliverToBoxAdapter(child: SectionHeader(title: 'Recently added')),
        SliverToBoxAdapter(child: _TrackCarousel(tracks: added)),
        const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
      ],
    );
  }
}

class _QuickAccess extends ConsumerWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openTab(int tab) {
      ref.read(libraryTabProvider.notifier).select(tab);
      context.go('/library');
    }

    final items = <(IconData, String, VoidCallback)>[
      (Icons.music_note_rounded, 'Songs', () => openTab(libraryTabSongs)),
      (Icons.album_rounded, 'Albums', () => openTab(libraryTabAlbums)),
      (Icons.person_rounded, 'Artists', () => openTab(libraryTabArtists)),
      (Icons.queue_music_rounded, 'Playlists', () => context.go('/playlists')),
      (Icons.favorite_rounded, 'Favorites', () => openTab(libraryTabFavorites)),
      (Icons.history_rounded, 'Recent', () => context.push('/recent')),
    ];
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter,
        vertical: Space.sm,
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: Space.sm,
        crossAxisSpacing: Space.sm,
        childAspectRatio: 1.35,
        children: [
          for (final (icon, label, onTap) in items)
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: Corners.mdAll,
              child: InkWell(
                borderRadius: Corners.mdAll,
                onTap: onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(height: Space.xs),
                    Text(
                      label,
                      style: theme.textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrackCarousel extends ConsumerWidget {
  const _TrackCarousel({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playback = ref.read(playbackControllerProvider);
    // Height scales with text size so labels never clip.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = Sizes.homeCard + 52 * textScale;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: tracks.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.md),
        itemBuilder: (context, i) {
          final t = tracks[i];
          return SizedBox(
            width: Sizes.homeCard,
            child: InkWell(
              borderRadius: Corners.mdAll,
              onTap: () => playback.playTracks(tracks, startIndex: i),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrackArtwork(
                    size: Sizes.homeCard,
                    artworkPath: t.artworkPath,
                    seed: t.album,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    t.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
