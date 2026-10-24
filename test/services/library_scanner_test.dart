import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musir/data/models/track.dart';
import 'package:musir/services/library/library_scanner.dart';
import 'package:path/path.dart' as p;

import '../support/audio_files.dart';

// 1x1 PNG.
final _png = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  late Directory root;
  late String art;

  ScanRequest req({
    Map<String, (int, int)> known = const {},
    List<String>? roots,
  }) => ScanRequest(roots: roots ?? [root.path], artworkDir: art, known: known);

  setUp(() {
    root = Directory.systemTemp.createTempSync('musir_scan');
    art = p.join(root.parent.path, '${p.basename(root.path)}_art');
  });
  tearDown(() {
    root.deleteSync(recursive: true);
    final a = Directory(art);
    if (a.existsSync()) a.deleteSync(recursive: true);
  });

  test('reads tags and caches embedded artwork', () {
    final f = File(p.join(root.path, 'Music', 'a.mp3'));
    writeMp3(f, emptyId3: true);
    updateMetadata(f, (m) {
      m.setTitle('Hello');
      m.setArtist('Adele');
      m.setAlbum('25');
      m.setPictures([Picture(_png, 'image/png', PictureType.coverFront)]);
    });

    final r = scanDirectories(req());
    expect(r.rootsReadable, isTrue);
    final t = r.changed.single;
    expect((t.title, t.artist, t.album), ('Hello', 'Adele', '25'));
    expect(t.artworkPath, isNotNull);
    expect(File(t.artworkPath!).readAsBytesSync(), _png);
    expect(t.artworkPath, endsWith('.png'));
  });

  test(
    'falls back to filename and unknown artist/album for untagged files',
    () {
      writeWav(File(p.join(root.path, 'My Song.wav')));
      final t = scanDirectories(req()).changed.single;
      expect(t.title, 'My Song');
      expect(t.artist, unknownArtist);
      expect(t.album, unknownAlbum);
      expect(t.artworkPath, isNull);
    },
  );

  test('corrupt file does not throw and still appears with filename title', () {
    File(p.join(root.path, 'broken.mp3')).writeAsBytesSync(List.filled(64, 7));
    final r = scanDirectories(req());
    expect(r.changed.single.title, 'broken');
  });

  test(
    'skips non-audio, empty, hidden, .nomedia, Android and ringtone dirs',
    () {
      writeWav(File(p.join(root.path, 'keep.wav')));
      File(p.join(root.path, 'notes.txt')).writeAsStringSync('x');
      File(p.join(root.path, 'empty.mp3')).createSync();
      writeWav(File(p.join(root.path, '.hidden', 'h.wav')));
      writeWav(File(p.join(root.path, 'nomedia', 'n.wav')));
      File(p.join(root.path, 'nomedia', '.nomedia')).createSync();
      writeWav(File(p.join(root.path, 'Android', 'data', 'x.wav')));
      writeWav(File(p.join(root.path, 'Ringtones', 'r.wav')));

      final r = scanDirectories(req());
      expect(r.seenPaths.map(p.basename), ['keep.wav']);
    },
  );

  test('unchanged files are reported as seen but not re-read', () {
    final f = File(p.join(root.path, 'a.wav'));
    writeWav(f);
    final first = scanDirectories(req()).changed.single;
    final r = scanDirectories(
      req(known: {f.path: (first.modifiedMs, first.sizeBytes)}),
    );
    expect(r.changed, isEmpty);
    expect(r.seenPaths, {f.path});
  });

  test('modified files are re-read', () {
    final f = File(p.join(root.path, 'a.wav'));
    writeWav(f);
    final r = scanDirectories(req(known: {f.path: (1, 1)}));
    expect(r.changed, hasLength(1));
  });

  test('unreadable roots are reported so nothing gets pruned', () {
    final r = scanDirectories(req(roots: [p.join(root.path, 'missing')]));
    expect(r.rootsReadable, isFalse);
    expect(r.seenPaths, isEmpty);
  });

  test('fnv1a64 is stable and 16 hex chars', () {
    final h = fnv1a64(Uint8List.fromList([1, 2, 3]));
    expect(h, hasLength(16));
    expect(fnv1a64(Uint8List.fromList([1, 2, 3])), h);
    expect(fnv1a64(Uint8List.fromList([1, 2, 4])), isNot(h));
  });

  test('volumeRootsFromAppDirs finds internal and SD roots', () {
    expect(
      volumeRootsFromAppDirs([
        '/storage/emulated/0/Android/data/com.musir.musir/files',
        '/storage/1A2B-3C4D/Android/data/com.musir.musir/files',
        '/weird/path',
      ]),
      ['/storage/emulated/0', '/storage/1A2B-3C4D'],
    );
  });
}
