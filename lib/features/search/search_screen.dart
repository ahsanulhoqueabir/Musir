import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/track_list.dart';
import '../../data/models/track.dart';
import '../../data/models/track_utils.dart';
import '../player/mini_player.dart';

/// How long typing must pause before results update.
const searchDebounce = Duration(milliseconds: 250);

/// Best matches first: title prefix, then title contains, then the rest.
List<Track> rankedSearch(Iterable<Track> tracks, String query) {
  final q = query.trim().toLowerCase();
  final hits = searchTracks(tracks, query);
  int rank(Track t) {
    final title = t.title.toLowerCase();
    if (title.startsWith(q)) return 0;
    if (title.contains(q)) return 1;
    return 2;
  }

  final sorted = [...hits]
    ..sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0
          ? r
          : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  return sorted;
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // refresh the clear button immediately
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(tracksProvider);
    final theme = Theme.of(context);
    final trimmed = _query.trim();
    final results = trimmed.isEmpty
        ? const <Track>[]
        : rankedSearch(tracks, trimmed);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: Space.gutter),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Songs, artists, albums',
              isDense: true,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _clear,
                    ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: trimmed.isEmpty
          ? EmptyState(
              icon: Icons.search_rounded,
              title: 'Search your library',
              message: tracks.isEmpty
                  ? 'Your library is empty — scan for music first.'
                  : 'Find songs by title, artist or album.',
            )
          : results.isEmpty
          ? EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results for "$trimmed"',
              message: 'Check the spelling or try a different word.',
            )
          : TrackListView(
              tracks: results,
              header: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  Space.sm,
                ),
                child: Text(
                  results.length == 1
                      ? '1 result'
                      : '${results.length} results',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
    );
  }
}
