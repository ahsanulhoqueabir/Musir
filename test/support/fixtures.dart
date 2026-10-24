import 'package:drift/native.dart';
import 'package:musir/data/db/database.dart';
import 'package:musir/data/models/scanned_track.dart';
import 'package:musir/data/models/track.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

ScannedTrack scanned(
  String path, {
  String? title,
  String artist = 'Artist',
  String album = 'Album',
  int durationMs = 180000,
  int size = 1000,
  int modified = 1,
  int? trackNumber,
  String? artwork,
}) => ScannedTrack(
  path: path,
  title: title ?? path,
  artist: artist,
  album: album,
  durationMs: durationMs,
  sizeBytes: size,
  modifiedMs: modified,
  trackNumber: trackNumber,
  artworkPath: artwork,
);

ScanResult scanOf(
  List<ScannedTrack> tracks, {
  bool readable = true,
  Set<String>? seen,
}) => ScanResult(
  changed: tracks,
  seenPaths: seen ?? {for (final t in tracks) t.path},
  rootsReadable: readable,
);

Track track(
  int id, {
  String? title,
  String artist = 'Artist',
  String album = 'Album',
  int durationMs = 180000,
  int size = 1000,
  int added = 0,
  int? trackNumber,
  String? artwork,
}) => Track(
  id: id,
  path: '/m/$id.mp3',
  title: title ?? 'Song $id',
  artist: artist,
  album: album,
  durationMs: durationMs,
  sizeBytes: size,
  modifiedMs: 0,
  addedMs: added,
  trackNumber: trackNumber,
  artworkPath: artwork,
);
