import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Square artwork for a track/album with a deterministic placeholder.
///
/// Decodes at display size (`cacheWidth`) so large embedded covers are not
/// held in memory at full resolution.
class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.size,
    this.artworkPath,
    this.seed = '',
    this.radius = Corners.md,
    this.iconSize,
  });

  final double size;
  final String? artworkPath;

  /// Used to pick a stable placeholder tint (title/album name).
  final String seed;
  final double radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final placeholder = _Placeholder(
      size: size,
      seed: seed,
      iconSize: iconSize ?? size * 0.42,
    );
    final path = artworkPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: path == null
            ? placeholder
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: (size * dpr).round(),
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.size,
    required this.seed,
    required this.iconSize,
  });

  final double size;
  final String seed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hue = (seed.hashCode.abs() % 360).toDouble();
    final tint = HSLColor.fromAHSL(
      1,
      hue,
      0.25,
      scheme.brightness == Brightness.dark ? 0.22 : 0.86,
    ).toColor();
    return ColoredBox(
      color: seed.isEmpty ? scheme.surfaceContainerHigh : tint,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: iconSize,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
