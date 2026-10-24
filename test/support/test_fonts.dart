import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

/// flutter_test renders every glyph as a full-width box (the "Ahem" font),
/// which makes overflow checks meaningless. Load the real Roboto + Material
/// Icons fonts that ship with the Flutter SDK so layout matches a device.
Future<void> loadTestFonts() async {
  if (_loaded) return;
  _loaded = true;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;

  Future<ByteData> bytes(String name) async =>
      ByteData.view(File('${dir.path}/$name').readAsBytesSync().buffer);

  final roboto = FontLoader('Roboto');
  for (final f in const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
    'Roboto-Light.ttf',
  ]) {
    roboto.addFont(bytes(f));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(bytes('MaterialIcons-Regular.otf'));
  await icons.load();
}
