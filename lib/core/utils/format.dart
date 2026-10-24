/// Formats a duration as `m:ss` or `h:mm:ss`. Negative values clamp to zero.
String formatDuration(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Human friendly total, e.g. `1 hr 5 min` or `42 min`.
String formatTotalDuration(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 1) return '${d.inSeconds} sec';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h hr' : '$h hr $m min';
}

String pluralize(int count, String singular, [String? plural]) =>
    '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';
