import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models/scanned_track.dart';
import '../../data/models/track.dart';

/// Extensions Musir will try to play. Playback support ultimately depends on
/// the device codecs (ExoPlayer on Android).
const Set<String> audioExtensions = {
  '.mp3', '.m4a', '.aac', '.flac', '.wav', '.ogg', '.opus', '.oga', '.wma',
  '.m4b', '.amr', '.3gp', '.mka', //
};

/// Directory names skipped during the walk (system sounds and app data).
const Set<String> _skippedDirNames = {
  'android', 'ringtones', 'notifications', 'alarms', 'ringtone', 'alarm',
  'notification', 'lost.dir', //
};

class ScanRequest {
  const ScanRequest({
    required this.roots,
    required this.artworkDir,
    required this.known,
  });

  final List<String> roots;
  final String artworkDir;

  /// `path -> (modifiedMs, sizeBytes)` of files already in the library.
  final Map<String, (int, int)> known;
}

abstract interface class LibraryScanner {
  Future<ScanResult> scan(ScanRequest request);
}

/// Runs [scanDirectories] on a background isolate so the UI never janks.
class IsolateLibraryScanner implements LibraryScanner {
  @override
  Future<ScanResult> scan(ScanRequest request) =>
      Isolate.run(() => scanDirectories(request));
}

/// Walks [ScanRequest.roots] synchronously (call from an isolate).
///
/// * Skips hidden dirs, dirs containing `.nomedia`, and system-sound folders.
/// * Only re-reads tags for new or modified files.
/// * Never throws for a single bad file: it falls back to filename metadata.
ScanResult scanDirectories(ScanRequest request) {
  final changed = <ScannedTrack>[];
  final seen = <String>{};
  var anyRootReadable = false;
  Directory(request.artworkDir).createSync(recursive: true);

  void walk(Directory dir) {
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    if (entries.any((e) => e is File && p.basename(e.path) == '.nomedia')) {
      return;
    }
    for (final e in entries) {
      final name = p.basename(e.path);
      if (e is Directory) {
        if (name.startsWith('.') ||
            _skippedDirNames.contains(name.toLowerCase())) {
          continue;
        }
        walk(e);
      } else if (e is File) {
        if (name.startsWith('.')) continue;
        if (!audioExtensions.contains(p.extension(name).toLowerCase())) {
          continue;
        }
        final scanned = _scanFile(e, request);
        if (scanned == null) continue;
        seen.add(e.path);
        if (scanned.$2 != null) changed.add(scanned.$2!);
      }
    }
  }

  for (final root in request.roots) {
    final dir = Directory(root);
    try {
      dir.listSync(followLinks: false);
      anyRootReadable = true;
    } on FileSystemException {
      continue;
    }
    walk(dir);
  }

  return ScanResult(
    changed: changed,
    seenPaths: seen,
    rootsReadable: anyRootReadable,
  );
}

/// Returns `(path, null)` when unchanged, `(path, track)` when (re)read, or
/// null when the file can't be stat'ed.
(String, ScannedTrack?)? _scanFile(File file, ScanRequest request) {
  final FileStat stat;
  try {
    stat = file.statSync();
  } on FileSystemException {
    return null;
  }
  if (stat.type != FileSystemEntityType.file || stat.size == 0) return null;
  final modified = stat.modified.millisecondsSinceEpoch;
  final known = request.known[file.path];
  if (known != null && known.$1 == modified && known.$2 == stat.size) {
    return (file.path, null);
  }

  final base = p.basenameWithoutExtension(file.path);
  String? title;
  String? artist;
  String? album;
  String? albumArtist;
  Duration? duration;
  int? trackNumber;
  String? artworkPath;
  try {
    final meta = readMetadata(file, getImage: true);
    title = meta.title;
    artist = meta.artist ?? meta.albumArtist;
    album = meta.album;
    albumArtist = meta.albumArtist;
    duration = meta.duration;
    trackNumber = meta.trackNumber;
    artworkPath = _cacheArtwork(meta.pictures, request.artworkDir);
  } catch (_) {
    // Unsupported container or corrupt tags: fall back to the filename.
  }

  String clean(String? s, String fallback) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? fallback : t;
  }

  return (
    file.path,
    ScannedTrack(
      path: file.path,
      title: clean(title, base),
      artist: clean(artist, unknownArtist),
      album: clean(album, unknownAlbum),
      albumArtist: albumArtist?.trim().isEmpty ?? true
          ? null
          : albumArtist!.trim(),
      durationMs: duration?.inMilliseconds ?? 0,
      sizeBytes: stat.size,
      modifiedMs: modified,
      trackNumber: trackNumber,
      artworkPath: artworkPath,
    ),
  );
}

String? _cacheArtwork(List<Picture> pictures, String dir) {
  if (pictures.isEmpty) return null;
  final pic = pictures.firstWhere(
    (x) => x.pictureType == PictureType.coverFront,
    orElse: () => pictures.first,
  );
  if (pic.bytes.isEmpty) return null;
  final ext = switch (pic.mimetype.toLowerCase()) {
    final m when m.contains('png') => 'png',
    final m when m.contains('webp') => 'webp',
    _ => 'jpg',
  };
  final path = p.join(dir, '${fnv1a64(pic.bytes)}.$ext');
  final f = File(path);
  try {
    if (!f.existsSync()) f.writeAsBytesSync(pic.bytes, flush: true);
    return path;
  } on FileSystemException {
    return null;
  }
}

/// Stable 64-bit FNV-1a hash (hex) used to de-duplicate cached covers.
/// Dart VM ints are 64-bit and wrap on overflow, which is what FNV expects.
String fnv1a64(Uint8List bytes) {
  var h = 0xcbf29ce484222325;
  for (final b in bytes) {
    h = (h ^ b) * 0x100000001b3;
  }
  String half(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  return half(h >>> 32) + half(h);
}

/// Storage roots to scan. App-specific external dirs look like
/// `/storage/emulated/0/Android/data/<pkg>/files`; everything before
/// `/Android/` is the volume root (internal storage or an SD card).
List<String> volumeRootsFromAppDirs(Iterable<String> appDirs) {
  final roots = <String>{};
  for (final d in appDirs) {
    final i = d.indexOf('/Android/');
    if (i > 0) roots.add(d.substring(0, i));
  }
  return roots.toList();
}

Future<List<String>> defaultScanRoots() async {
  try {
    final dirs = await getExternalStorageDirectories();
    final roots = volumeRootsFromAppDirs([
      for (final d in dirs ?? <Directory>[]) d.path,
    ]);
    if (roots.isNotEmpty) return roots;
  } catch (_) {}
  return const ['/storage/emulated/0'];
}
