import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:musir/app/app.dart';
import 'package:musir/app/providers.dart';
import 'package:musir/data/db/database.dart';
import 'package:musir/data/models/scanned_track.dart';
import 'package:musir/features/library/library_controller.dart';
import 'package:musir/features/player/player_providers.dart';
import 'package:musir/features/settings/settings_state.dart';
import 'package:musir/services/library/library_scanner.dart';
import 'package:musir/services/library/permission_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_audio_engine.dart';
import 'fixtures.dart';
import 'test_fonts.dart';

class FakePermissionGateway implements PermissionGateway {
  FakePermissionGateway(this.current, {this.afterRequest});

  LibraryAccess current;
  LibraryAccess? afterRequest;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<LibraryAccess> status() async => current;

  @override
  Future<LibraryAccess> request() async {
    requests++;
    current = afterRequest ?? current;
    return current;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class FakeScanner implements LibraryScanner {
  FakeScanner(this.result);

  ScanResult result;
  int scans = 0;

  @override
  Future<ScanResult> scan(ScanRequest request) async {
    scans++;
    return result;
  }
}

ScanResult sampleScan({int count = 4}) => scanOf([
  for (var i = 1; i <= count; i++)
    scanned(
      '/music/song$i.mp3',
      title: 'Song $i',
      artist: i.isEven ? 'Bravo Band' : 'Alpha Act',
      album: i <= 2 ? 'First Album' : 'Second Album',
      durationMs: 180000 + i * 1000,
      size: 1000 + i,
      trackNumber: i,
    ),
]);

class TestEnv {
  TestEnv({
    required this.db,
    required this.engine,
    required this.permission,
    required this.scanner,
    required this.prefs,
  });

  final AppDatabase db;
  final FakeAudioEngine engine;
  final FakePermissionGateway permission;
  final FakeScanner scanner;
  final SharedPreferences prefs;

  /// Paths the playback controller should treat as deleted from disk.
  final Set<String> missingPaths = {};

  late ProviderContainer container;

  List<Override> get overrides => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    databaseProvider.overrideWithValue(db),
    audioEngineProvider.overrideWithValue(engine),
    permissionGatewayProvider.overrideWithValue(permission),
    libraryScannerProvider.overrideWithValue(scanner),
    scanRootsProvider.overrideWithValue(() async => ['/music']),
    artworkDirProvider.overrideWithValue(() async => '/tmp/musir_art'),
    fileExistsProvider.overrideWithValue((p) => !missingPaths.contains(p)),
  ];
}

Future<TestEnv> createEnv(
  WidgetTester tester, {
  LibraryAccess access = LibraryAccess.granted,
  LibraryAccess? afterRequest,
  ScanResult? scan,
  Map<String, Object> prefsValues = const {},
}) async {
  late TestEnv env;
  await tester.runAsync(() async {
    SharedPreferences.setMockInitialValues(prefsValues);
    env = TestEnv(
      db: memoryDb(),
      engine: FakeAudioEngine(),
      permission: FakePermissionGateway(access, afterRequest: afterRequest),
      scanner: FakeScanner(scan ?? sampleScan()),
      prefs: await SharedPreferences.getInstance(),
    );
  });
  addTearDown(() async {
    await tester.runAsync(env.db.close);
  });
  return env;
}

/// Boots the real [MusirApp] on a phone-sized surface with [env]'s fakes.
Future<void> pumpApp(
  WidgetTester tester,
  TestEnv env, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  await tester.runAsync(loadTestFonts);
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: env.overrides,
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          devicePixelRatio: 2,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const MusirApp(),
      ),
    ),
  );
  env.container = ProviderScope.containerOf(
    tester.element(find.byType(MusirApp)),
  );
  await settle(tester);
}

/// Lets async DB/stream work and animations complete.
Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Like [testWidgets], but unmounts the app afterwards and flushes the
/// zero-duration timers Drift schedules when its streams are cancelled.
void testApp(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  Timeout? timeout,
}) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }, timeout: timeout);
}
