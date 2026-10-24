import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/settings/settings_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must run before the first AudioPlayer is created: it wires up the media
  // notification, lock-screen controls and headset buttons.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.musir.musir.playback',
    androidNotificationChannelName: 'Musir playback',
    androidNotificationOngoing: true,
  );
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MusirApp(),
    ),
  );
}
