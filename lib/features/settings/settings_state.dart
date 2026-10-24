import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/track_utils.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.defaultSort = TrackSort.title,
    this.restoreQueue = true,
    this.skipSilence = false,
  });

  final ThemeMode themeMode;
  final TrackSort defaultSort;

  /// Reopen the last queue (paused) when the app starts.
  final bool restoreQueue;

  /// Skip silent passages during playback (Android only).
  final bool skipSilence;

  AppSettings copyWith({
    ThemeMode? themeMode,
    TrackSort? defaultSort,
    bool? restoreQueue,
    bool? skipSilence,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    defaultSort: defaultSort ?? this.defaultSort,
    restoreQueue: restoreQueue ?? this.restoreQueue,
    skipSilence: skipSilence ?? this.skipSilence,
  );
}

/// Preloaded in `main()`; overridden in tests.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _theme = 'settings.theme';
  static const _sort = 'settings.sort';
  static const _restore = 'settings.restoreQueue';
  static const _silence = 'settings.skipSilence';

  late final SharedPreferences _prefs = ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    return AppSettings(
      themeMode: _enum(
        ThemeMode.values,
        _prefs.getString(_theme),
        ThemeMode.system,
      ),
      defaultSort: _enum(
        TrackSort.values,
        _prefs.getString(_sort),
        TrackSort.title,
      ),
      restoreQueue: _prefs.getBool(_restore) ?? true,
      skipSilence: _prefs.getBool(_silence) ?? false,
    );
  }

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_theme, mode.name);
  }

  Future<void> setDefaultSort(TrackSort sort) async {
    state = state.copyWith(defaultSort: sort);
    await _prefs.setString(_sort, sort.name);
  }

  Future<void> setRestoreQueue(bool value) async {
    state = state.copyWith(restoreQueue: value);
    await _prefs.setBool(_restore, value);
  }

  Future<void> setSkipSilence(bool value) async {
    state = state.copyWith(skipSilence: value);
    await _prefs.setBool(_silence, value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
