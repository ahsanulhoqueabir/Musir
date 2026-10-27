import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../features/player/player_providers.dart';
import 'brand_mark.dart';

/// Shows the branded splash over the app until the player has been restored
/// (and a short minimum time has passed), then fades it out.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate>
    with SingleTickerProviderStateMixin {
  static const _minimum = Duration(milliseconds: 1400);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  bool _minElapsed = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.delayed(_minimum).then((_) {
        if (mounted) setState(() => _minElapsed = true);
      }),
    );
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(bootstrapProvider).hasValue;
    final show = !(ready && _minElapsed);
    final curved = CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !show,
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: FadeTransition(
                  opacity: curved,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.88, end: 1.0).animate(curved),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandMark(size: 220),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: musirGreen,
                            backgroundColor: musirGreen.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
