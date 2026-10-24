import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/providers.dart';
import '../../core/utils/feedback.dart';
import '../../core/utils/format.dart';
import '../../data/models/track_utils.dart';
import '../library/library_controller.dart';
import '../player/player_providers.dart';
import 'settings_state.dart';

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final lib = ref.watch(libraryControllerProvider);
    final trackCount = ref.watch(tracksProvider).length;
    final info = ref.watch(packageInfoProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        key: const PageStorageKey('settings'),
        children: [
          const _Section('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: const Text('Theme'),
            subtitle: Text(_themeLabel(settings.themeMode)),
            onTap: () async {
              final picked = await showDialog<ThemeMode>(
                context: context,
                builder: (dialogContext) => SimpleDialog(
                  title: const Text('Theme'),
                  children: [
                    RadioGroup<ThemeMode>(
                      groupValue: settings.themeMode,
                      onChanged: (v) => Navigator.of(dialogContext).pop(v),
                      child: Column(
                        children: [
                          for (final m in ThemeMode.values)
                            RadioListTile<ThemeMode>(
                              value: m,
                              title: Text(_themeLabel(m)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (picked != null) await notifier.setThemeMode(picked);
            },
          ),
          const _Section('Library'),
          ListTile(
            leading: const Icon(Icons.sort_rounded),
            title: const Text('Default sort order'),
            subtitle: Text(settings.defaultSort.label),
            onTap: () async {
              final picked = await showDialog<TrackSort>(
                context: context,
                builder: (dialogContext) => SimpleDialog(
                  title: const Text('Sort songs by'),
                  children: [
                    RadioGroup<TrackSort>(
                      groupValue: settings.defaultSort,
                      onChanged: (v) => Navigator.of(dialogContext).pop(v),
                      child: Column(
                        children: [
                          for (final s in TrackSort.values)
                            RadioListTile<TrackSort>(
                              value: s,
                              title: Text(s.label),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              if (picked != null) await notifier.setDefaultSort(picked);
            },
          ),
          ListTile(
            leading: lib.scanning
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.refresh_rounded),
            title: const Text('Rescan library'),
            subtitle: Text(
              lib.scanning
                  ? 'Scanning…'
                  : '${pluralize(trackCount, 'song')} in your library',
            ),
            enabled: !lib.scanning,
            onTap: () async {
              await ref.read(libraryControllerProvider.notifier).rescan();
              if (context.mounted) {
                final s = ref.read(libraryControllerProvider);
                showMessage(context, s.error ?? 'Library updated');
              }
            },
          ),
          const _Section('Playback'),
          SwitchListTile(
            secondary: const Icon(Icons.restore_rounded),
            title: const Text('Resume last queue'),
            subtitle: const Text(
              'Reopen your queue, paused, when Musir starts',
            ),
            value: settings.restoreQueue,
            onChanged: notifier.setRestoreQueue,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.graphic_eq_rounded),
            title: const Text('Skip silence'),
            subtitle: const Text('Jump over silent parts of tracks'),
            value: settings.skipSilence,
            onChanged: (v) async {
              await notifier.setSkipSilence(v);
              await ref.read(playbackControllerProvider).setSkipSilence(v);
            },
          ),
          const _Section('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Musir'),
            subtitle: Text(
              info == null
                  ? 'Version —'
                  : 'Version ${info.version} (${info.buildNumber})',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy'),
            subtitle: const Text(
              'Your music and listening history stay on this device',
            ),
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Privacy'),
                content: Text(
                  'Musir works entirely on your device.\n\n'
                  '• It reads audio files only to build your library.\n'
                  '• Playlists, favorites and play history are stored locally.\n'
                  '• There are no accounts, ads or analytics, and Musir does not '
                  'upload your music or listening data anywhere.\n\n'
                  'Permission used: access to audio files '
                  '(READ_MEDIA_AUDIO on Android 13+, storage on older versions).',
                  style: theme.textTheme.bodyMedium,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Musir',
              applicationVersion: info?.version,
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode m) => switch (m) {
    ThemeMode.system => 'System default',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
