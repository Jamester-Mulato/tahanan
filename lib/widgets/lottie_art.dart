import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// A small, theme-aware wrapper around the bundled Lottie animations.
///
/// Motion is skipped when the platform asks for reduced animations, so the
/// first frame becomes a static illustration instead of a moving one.
class LottieArt extends StatelessWidget {
  final String name;
  final double size;
  final bool repeat;
  final bool reverse;
  final String semanticsLabel;
  final bool animate;

  const LottieArt(
    this.name, {
    super.key,
    this.size = 120,
    this.repeat = true,
    this.reverse = false,
    this.semanticsLabel = '',
    this.animate = true,
  });

  static const _paths = {
    'pulse': 'assets/lottie/pulse.json',
    'check': 'assets/lottie/check.json',
    'dots': 'assets/lottie/dots.json',
    'shield': 'assets/lottie/shield.json',
    'idle': 'assets/lottie/idle.json',
    'aurora': 'assets/lottie/aurora.json',
    'flow': 'assets/lottie/flow.json',
    'drift': 'assets/lottie/drift.json',
    'halo': 'assets/lottie/halo.json',
    'empty': 'assets/lottie/empty.json',
  };

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final art = Lottie.asset(
      _paths[name] ?? _paths['pulse']!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      repeat: repeat && !reduce,
      reverse: reverse,
      animate: animate && !reduce,
      frameRate: FrameRate(24),
    );

    return RepaintBoundary(
      child: ExcludeSemantics(
        excluding: semanticsLabel.isEmpty,
        child: Semantics(
          label: semanticsLabel.isEmpty ? null : semanticsLabel,
          image: true,
          child: art,
        ),
      ),
    );
  }
}
