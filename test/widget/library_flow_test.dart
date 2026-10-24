import 'package:flutter_test/flutter_test.dart';
import 'package:musir/app/providers.dart';
import 'package:musir/services/library/permission_gateway.dart';

import '../support/fixtures.dart';
import '../support/test_app.dart';

void main() {
  testApp('granted access scans and shows the library on Home', (tester) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);

    expect(env.scanner.scans, 1);
    expect(find.text('Recently added'), findsOneWidget);
    expect(find.text('Song 1'), findsWidgets);
    expect(find.text('Allow access'), findsNothing);
  });

  testApp('denied access explains why, then scans after the user allows', (
    tester,
  ) async {
    final env = await createEnv(
      tester,
      access: LibraryAccess.denied,
      afterRequest: LibraryAccess.granted,
    );
    await pumpApp(tester, env);

    expect(find.text('Let Musir find your music'), findsOneWidget);
    expect(find.textContaining('never leaves your phone'), findsOneWidget);
    expect(env.scanner.scans, 0);

    await tester.tap(find.text('Allow access'));
    await settle(tester);

    expect(env.permission.requests, 1);
    expect(env.scanner.scans, 1);
    expect(find.text('Let Musir find your music'), findsNothing);
    expect(find.text('Song 1'), findsWidgets);
  });

  testApp('permanently denied sends the user to system settings', (
    tester,
  ) async {
    final env = await createEnv(
      tester,
      access: LibraryAccess.permanentlyDenied,
    );
    await pumpApp(tester, env);

    expect(find.text('Music access is turned off'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await settle(tester);
    expect(env.permission.settingsOpened, 1);
    expect(env.scanner.scans, 0);
  });

  testApp('empty storage shows a helpful empty state and can rescan', (
    tester,
  ) async {
    final env = await createEnv(tester, scan: scanOf([]));
    await pumpApp(tester, env);

    expect(find.text('No music found'), findsOneWidget);
    expect(find.textContaining('MP3'), findsOneWidget);

    env.scanner.result = sampleScan(count: 2);
    await tester.tap(find.text('Scan again'));
    await settle(tester);

    expect(find.text('No music found'), findsNothing);
    expect(find.text('Song 1'), findsWidgets);
  });

  testApp('files that disappear from storage leave the library', (
    tester,
  ) async {
    final env = await createEnv(tester);
    await pumpApp(tester, env);
    expect(env.container.read(tracksProvider), hasLength(4));

    env.scanner.result = scanOf([], seen: {'/music/song1.mp3'});
    await tester.runAsync(() async {
      await env.container
          .read(libraryRepositoryProvider)
          .applyScan(env.scanner.result);
    });
    await settle(tester);
    expect(env.container.read(tracksProvider), hasLength(1));
  });
}
