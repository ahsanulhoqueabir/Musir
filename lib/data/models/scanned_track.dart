/// Metadata read from one audio file by the scanner (before it has an id).
class ScannedTrack {
  const ScannedTrack({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.sizeBytes,
    required this.modifiedMs,
    this.trackNumber,
    this.artworkPath,
  });

  final String path;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int sizeBytes;
  final int modifiedMs;
  final int? trackNumber;
  final String? artworkPath;
}

/// Outcome of one scan pass.
class ScanResult {
  const ScanResult({
    required this.changed,
    required this.seenPaths,
    required this.rootsReadable,
  });

  /// New or modified files, with fresh metadata.
  final List<ScannedTrack> changed;

  /// Every supported audio file found, changed or not.
  final Set<String> seenPaths;

  /// False when no scan root could be listed (permission revoked, storage
  /// unmounted). The repository must not delete anything in that case.
  final bool rootsReadable;
}
