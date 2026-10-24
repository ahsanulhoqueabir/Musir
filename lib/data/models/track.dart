import 'package:flutter/foundation.dart';

const String unknownArtist = 'Unknown artist';
const String unknownAlbum = 'Unknown album';

/// A local audio file known to the library.
///
/// [id] is the database primary key. It stays stable across rescans because
/// tracks are upserted by [path].
@immutable
class Track {
  const Track({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.sizeBytes,
    required this.modifiedMs,
    required this.addedMs,
    this.trackNumber,
    this.artworkPath,
  });

  final int id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int sizeBytes;
  final int modifiedMs;
  final int addedMs;
  final int? trackNumber;

  /// Cached embedded artwork on disk, if the file had any.
  final String? artworkPath;

  Duration get duration => Duration(milliseconds: durationMs);

  bool get hasArtwork => artworkPath != null;

  @override
  bool operator ==(Object other) =>
      other is Track && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);

  @override
  String toString() => 'Track($id, $title - $artist)';
}
