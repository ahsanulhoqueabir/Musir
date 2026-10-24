import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/library_gate.dart';
import '../../core/widgets/track_artwork.dart';
import '../../core/widgets/track_list.dart';
import '../../data/models/track_utils.dart';
import '../settings/settings_state.dart';
import 'library_controller.dart';
import 'library_tab_state.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: ref.read(libraryTabProvider),
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) {
        ref.read(libraryTabProvider.notifier).select(_tabs.index);
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Home's quick-access tiles can switch tabs from outside.
    ref.listen(libraryTabProvider, (_, next) {
      if (next != _tabs.index) _tabs.animateTo(next);
    });
    final scanning = ref.watch(
      libraryControllerProvider.select((s) => s.scanning),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: scanning ? 'Scanning…' : 'Rescan library',
            icon: scanning
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: scanning
                ? null
                : () => ref.read(libraryControllerProvider.notifier).rescan(),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Albums'),
            Tab(text: 'Artists'),
            Tab(text: 'Favorites'),
          ],
        ),
      ),
      body: LibraryGate(
        child: TabBarView(
          controller: _tabs,
          children: const [
            _KeepAlive(child: SongsTab()),
            _KeepAlive(child: AlbumsTab()),
            _KeepAlive(child: ArtistsTab()),
            _KeepAlive(child: FavoritesTab()),
          ],
        ),
      ),
    );
  }
}

/// Keeps a tab (and its scroll position) alive while off-screen.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class SongsTab extends ConsumerStatefulWidget {
  const SongsTab({super.key});

  @override
  ConsumerState<SongsTab> createState() => _SongsTabState();
}

class _SongsTabState extends ConsumerState<SongsTab> {
  /// Session-only override; the persistent default lives in Settings.
  TrackSort? _sort;

  @override
  Widget build(BuildContext context) {
    final defaultSort = ref.watch(
      settingsProvider.select((s) => s.defaultSort),
    );
    final sort = _sort ?? defaultSort;
    final tracks = sortTracks(ref.watch(tracksProvider), sort);
    final theme = Theme.of(context);

    return TrackListView(
      storageKey: const PageStorageKey('songs'),
      tracks: tracks,
      header: Column(
        children: [
          PlayShuffleBar(tracks: tracks),
          Padding(
            padding: const EdgeInsets.only(left: Space.gutter, right: Space.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pluralize(tracks.length, 'song'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                PopupMenuButton<TrackSort>(
                  tooltip: 'Sort songs',
                  initialValue: sort,
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => [
                    for (final s in TrackSort.values)
                      CheckedPopupMenuItem(
                        value: s,
                        checked: s == sort,
                        child: Text(s.label),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md,
                      vertical: Space.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort_rounded, size: 20),
                        const SizedBox(width: Space.xs),
                        Text(sort.label, style: theme.textTheme.labelLarge),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(albumsProvider);
    final theme = Theme.of(context);
    return GridView.builder(
      key: const PageStorageKey('albums'),
      padding: const EdgeInsets.all(Space.gutter),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: Space.lg,
        crossAxisSpacing: Space.lg,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final a = albums[i];
        return InkWell(
          borderRadius: Corners.mdAll,
          onTap: () => context.push('/album/${a.tracks.first.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => TrackArtwork(
                    size: c.maxWidth,
                    artworkPath: a.artworkPath,
                    seed: a.name,
                  ),
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(
                a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                a.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ArtistsTab extends ConsumerWidget {
  const ArtistsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider);
    return ListView.builder(
      key: const PageStorageKey('artists'),
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final a = artists[i];
        return ListTile(
          onTap: () => context.push('/artist/${a.tracks.first.id}'),
          leading: ClipOval(
            child: TrackArtwork(
              size: Sizes.trackArtwork,
              artworkPath: a.artworkPath,
              seed: a.name,
              radius: 0,
            ),
          ),
          title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${pluralize(a.albumCount, 'album')} · ${pluralize(a.tracks.length, 'song')}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
        );
      },
    );
  }
}

class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteTracksProvider);
    if (favorites.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No favorites yet',
        message: 'Tap the heart on any song to keep it here.',
      );
    }
    return TrackListView(
      storageKey: const PageStorageKey('favorites'),
      tracks: favorites,
      header: PlayShuffleBar(tracks: favorites),
    );
  }
}
