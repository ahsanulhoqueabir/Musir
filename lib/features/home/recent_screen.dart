import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/track_list.dart';
import '../player/mini_player.dart';

class RecentScreen extends ConsumerWidget {
  const RecentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(recentlyPlayedProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently played'),
        actions: [
          if (tracks.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(historyRepositoryProvider).clear(),
              child: const Text('Clear'),
            ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: tracks.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: 'Nothing played yet',
              message: 'Songs you listen to will show up here.',
            )
          : TrackListView(
              tracks: tracks,
              header: PlayShuffleBar(tracks: tracks),
            ),
    );
  }
}
