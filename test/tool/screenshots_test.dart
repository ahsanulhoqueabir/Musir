// Renders README screenshots with the real app, real fonts and placeholder
// artwork. Opt-in so normal test runs stay fast and deterministic:
//
//   MUSIR_SCREENSHOTS=1 flutter test test/tool/screenshots_test.dart
//
// Output: docs/screenshots/*.png (rendered by the widget-test harness, not
// captured on a device).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musir/data/repositories/favorites_repository.dart';
import 'package:musir/data/repositories/history_repository.dart';
import 'package:musir/data/repositories/playlists_repository.dart';

import '../support/test_app.dart';

final bool _enabled = Platform.environment['MUSIR_SCREENSHOTS'] == '1';

Future<void> _goTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

Future<void> _shot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('docs/screenshots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  for (final mode in ['light', 'dark']) {
    testApp('screenshots ($mode)', skip: !_enabled, (tester) async {
      final env = await createEnv(
        tester,
        scan: sampleScan(count: 8),
        prefsValues: {'settings.theme': mode},
      );
      // Seed first: Drift streams opened inside the app's fake-async zone
      // would otherwise deadlock later writes.
      await tester.runAsync(() async {
        await env.seedLibrary();
        final history = HistoryRepository(env.db);
        await history.record(3, nowMs: 1);
        await history.record(5, nowMs: 2);
        await history.record(2, nowMs: 3);
        await FavoritesRepository(env.db).toggle(2);
        final playlists = PlaylistsRepository(env.db);
        final id = await playlists.create('Road trip');
        await playlists.addTracks(id, [1, 2, 3]);
        await playlists.create('Focus');
      });
      await pumpApp(tester, env);
      await _shot(tester, '$mode-home');

      await _goTab(tester, 'Library');
      await tester.tap(find.text('Song 3').last);
      await settle(tester);
      await _shot(tester, '$mode-library');

      await tester.tap(find.byType(Hero).first);
      await settle(tester);
      await _shot(tester, '$mode-player');
      await tester.tap(find.byTooltip('Close player'));
      await settle(tester);

      await _goTab(tester, 'Playlists');
      await tester.tap(find.text('Road trip'));
      await settle(tester);
      await _shot(tester, '$mode-playlist');
    });
  }
}
