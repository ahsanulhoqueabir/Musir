import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/utils/format.dart';
import 'player_providers.dart';

/// Playback slider with elapsed/remaining labels.
///
/// While dragging, the thumb follows the finger and engine position updates
/// are ignored, so the thumb never jumps back. The seek is sent on release.
class SeekBar extends ConsumerStatefulWidget {
  const SeekBar({super.key});

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = ref.watch(currentTrackProvider);
    final enginePosition = ref.watch(positionProvider).value ?? Duration.zero;
    final engineDuration = ref.watch(engineDurationProvider).value;

    var total = engineDuration ?? track?.duration ?? Duration.zero;
    if (total == Duration.zero) total = track?.duration ?? Duration.zero;
    final max = total.inMilliseconds.toDouble();
    final enabled = max > 0;
    final position = (_drag ?? enginePosition.inMilliseconds.toDouble()).clamp(
      0.0,
      enabled ? max : 0.0,
    );
    final elapsed = Duration(milliseconds: position.round());
    final remaining = total - elapsed;
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      children: [
        Semantics(
          label: 'Seek',
          value: '${formatDuration(elapsed)} of ${formatDuration(total)}',
          child: SliderTheme(
            data: SliderTheme.of(context)
                .copyWith(trackShape: const RoundedRectSliderTrackShape()),
            child: Slider(
              value: position,
              max: enabled ? max : 1,
              onChangeStart: enabled ? (v) => setState(() => _drag = v) : null,
              onChanged: enabled ? (v) => setState(() => _drag = v) : null,
              onChangeEnd: enabled
                  ? (v) async {
                      await ref
                          .read(playbackControllerProvider)
                          .seek(Duration(milliseconds: v.round()));
                      if (mounted) setState(() => _drag = null);
                    }
                  : null,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(elapsed), style: labelStyle),
              Text(
                enabled ? '-${formatDuration(remaining)}' : '--:--',
                style: labelStyle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
