import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/home/recent_screen.dart';
import '../features/library/detail_screens.dart';
import '../features/library/library_screen.dart';
import '../features/player/player_screen.dart';
import '../features/playlists/playlist_screen.dart';
import '../features/playlists/playlists_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell.dart';
import 'theme/tokens.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Slides up from the bottom, like expanding the mini-player. Honors the
/// system "remove animations" setting.
CustomTransitionPage<void> _playerPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.slow,
    reverseTransitionDuration: Motion.normal,
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MusirShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, _) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/playlists',
                builder: (_, _) => const PlaylistsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _playerPage(state, const PlayerScreen()),
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const SearchScreen(),
      ),
      GoRoute(
        path: '/recent',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const RecentScreen(),
      ),
      GoRoute(
        path: '/album/:trackId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => AlbumScreen(
          trackId: int.tryParse(state.pathParameters['trackId']!) ?? -1,
        ),
      ),
      GoRoute(
        path: '/artist/:trackId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ArtistScreen(
          trackId: int.tryParse(state.pathParameters['trackId']!) ?? -1,
        ),
      ),
      GoRoute(
        path: '/playlist/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => PlaylistScreen(
          playlistId: int.tryParse(state.pathParameters['id']!) ?? -1,
        ),
      ),
    ],
  );
}
