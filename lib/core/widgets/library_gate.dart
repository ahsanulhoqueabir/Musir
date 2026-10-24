import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/library/library_controller.dart';
import '../../services/library/permission_gateway.dart';
import 'empty_state.dart';

/// Shows [child] once the library has music. Until then it explains what is
/// going on: permission needed, permission blocked, scanning, or no music.
class LibraryGate extends ConsumerWidget {
  const LibraryGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(allTracksProvider);
    if (tracks.hasValue && tracks.requireValue.isNotEmpty) return child;
    if (tracks.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final lib = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);

    switch (lib.access) {
      case null:
        return const Center(child: CircularProgressIndicator());
      case LibraryAccess.denied:
        return EmptyState(
          icon: Icons.library_music_rounded,
          title: 'Let Musir find your music',
          message:
              'Musir needs permission to read audio files on this device so it '
              'can build your library. Your music never leaves your phone.',
          actionLabel: 'Allow access',
          onAction: controller.requestAccess,
        );
      case LibraryAccess.permanentlyDenied:
        return EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Music access is turned off',
          message:
              'Enable the "Music and audio" permission for Musir in system '
              'settings, then come back.',
          actionLabel: 'Open settings',
          onAction: controller.openSettings,
        );
      case LibraryAccess.granted:
        if (lib.scanning) {
          return const EmptyState(
            icon: Icons.search_rounded,
            title: 'Scanning your music…',
            message: 'This can take a moment the first time.',
          );
        }
        return EmptyState(
          icon: Icons.music_off_rounded,
          title: lib.error ?? 'No music found',
          message: lib.error != null ? null : 'Add MP3, M4A, FLAC, WAV or OGG files to your device, then scan again.',
          actionLabel: 'Scan again',
          onAction: controller.rescan,
        );
    }
  }
}
