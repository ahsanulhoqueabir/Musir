import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/library/library_controller.dart';
import '../features/player/player_providers.dart';
import '../features/settings/settings_state.dart';
import '../core/widgets/splash_gate.dart';
import 'router.dart';
import 'theme/app_theme.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MusirApp extends ConsumerStatefulWidget {
  const MusirApp({super.key});

  @override
  ConsumerState<MusirApp> createState() => _MusirAppState();
}

class _MusirAppState extends ConsumerState<MusirApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Restore the queue first so the mini-player is ready, then scan.
    unawaited(
      ref
          .read(bootstrapProvider.future)
          .whenComplete(
            () => ref.read(libraryControllerProvider.notifier).init(),
          ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Save position so the session can be resumed after the OS kills us.
        ref.read(playbackControllerProvider).persistNow();
      case AppLifecycleState.resumed:
        // The user may have granted access in system settings.
        unawaited(ref.read(libraryControllerProvider.notifier).refreshAccess());
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));

    // Playback problems (missing/undecodable files) surface as snackbars.
    ref.listen(playerStateProvider.select((s) => s.notice), (prev, next) {
      if (next == null || next.id == prev?.id) return;
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.message)));
    });

    return MaterialApp.router(
      title: 'Musir',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      scaffoldMessengerKey: messengerKey,
      routerConfig: _router,
      builder: (context, child) =>
          SplashGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
