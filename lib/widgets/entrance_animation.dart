import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'motion.dart';

// ==========================================================
// ENTRANCE ANIMATION (canonical motion compatibility)
// ==========================================================
//
// This file is retained for backwards compatibility. The canonical
// entrance primitive is [FadeSlideIn] in `motion.dart` (fade +
// directional translate, optional entrance scale, stagger via
// [StaggerColumn]). The widgets below are thin shims with unchanged
// public constructors so existing call sites keep working while the
// whole app shares one motion implementation, one duration ladder
// ([AppColors.entranceAnim], [AppColors.staggerStep]) and one
// reduced-motion policy.

enum EntranceFrom { bottom, top, left, right, scale }

/// Backwards-compatible entrance wrapper. Delegates to [FadeSlideIn]:
/// direction maps to a travel vector, `scale` maps to [FadeSlideIn.scaleBegin].
@Deprecated('Use FadeSlideIn from motion.dart instead.')
class EntranceAnimation extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final EntranceFrom from;
  final double distance;
  final bool runOnMount;

  const EntranceAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppColors.entranceAnim,
    this.curve = Curves.easeOutCubic,
    this.from = EntranceFrom.bottom,
    this.distance = 18,
    this.runOnMount = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!runOnMount) return child;
    final offset = switch (from) {
      EntranceFrom.bottom => Offset(0, distance),
      EntranceFrom.top => Offset(0, -distance),
      EntranceFrom.left => Offset(-distance, 0),
      EntranceFrom.right => Offset(distance, 0),
      EntranceFrom.scale => Offset.zero,
    };
    return FadeSlideIn(
      delay: delay,
      duration: duration,
      curve: curve,
      offset: offset,
      scaleBegin: from == EntranceFrom.scale ? 0.94 : null,
      child: child,
    );
  }
}

/// Backwards-compatible staggered reveal. Delegates to [StaggerColumn].
@Deprecated('Use StaggerColumn from motion.dart instead.')
class StaggeredEntrance extends StatelessWidget {
  final List<Widget> children;
  final Duration start;
  final Duration step;
  final Duration duration;
  final EntranceFrom from;
  final double distance;

  const StaggeredEntrance({
    super.key,
    required this.children,
    this.start = Duration.zero,
    this.step = AppColors.staggerStep,
    this.duration = AppColors.entranceAnim,
    this.from = EntranceFrom.bottom,
    this.distance = 18,
  });

  @override
  Widget build(BuildContext context) {
    // Direction/distance parity is preserved per child through FadeSlideIn.
    // StaggerColumn owns the canonical stagger; direction maps here.
    if (from == EntranceFrom.bottom) {
      return StaggerColumn(
        start: start,
        step: step,
        baseDuration: duration,
        children: children,
      );
    }
    return StaggerColumn(
      start: start,
      step: step,
      baseDuration: duration,
      children: [
        for (final c in children)
          EntranceAnimation(
            from: from,
            distance: distance,
            duration: duration,
            child: c,
          ),
      ],
    );
  }
}

/// Backwards-compatible animated counter. Delegates to [CountUp].
@Deprecated('Use CountUp from motion.dart instead.')
class AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Duration duration;
  final String Function(int value)? formatter;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    this.duration = AppColors.slowAnim,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return CountUp(
      value: value,
      style: style,
      duration: duration,
      format: formatter == null ? null : (v) => formatter!(v.round()),
    );
  }
}

/// A tiny "live" dot with a breathing halo. Used next to section headings to
/// signal fresh data without a spinner.
class LivePulseDot extends StatefulWidget {
  final Color color;
  final double size;

  LivePulseDot({
    super.key,
    this.color = const Color(0xFF0F7A44),
    this.size = 7,
  });

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) return;
      _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size * 2.4,
        height: widget.size * 2.4,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: (1 - t) * 0.35,
                  child: Container(
                    width: widget.size * (1 + t * 1.4),
                    height: widget.size * (1 + t * 1.4),
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
