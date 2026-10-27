import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/idle_motion_spec.dart';

/// Applies a JSON-defined idle motion to its child.
///
/// The controller repeats forever; a per-spec delay is expressed as a phase
/// offset so staggered widgets start at different points without timers.
class IdleMotion extends StatefulWidget {
  final String motionKey;
  final MotionCatalog catalog;
  final Widget child;
  final bool enabled;

  const IdleMotion({
    super.key,
    required this.motionKey,
    required this.catalog,
    required this.child,
    this.enabled = true,
  });

  @override
  State<IdleMotion> createState() => _IdleMotionState();
}

class _IdleMotionState extends State<IdleMotion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  IdleMotionSpec get _spec => widget.catalog.spec(widget.motionKey);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _spec.duration);
    if (_spec.type != IdleMotionType.none) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant IdleMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSpec = oldWidget.catalog.spec(oldWidget.motionKey);
    final newSpec = _spec;

    if (oldSpec.duration != newSpec.duration ||
        oldWidget.motionKey != widget.motionKey) {
      _controller
        ..stop()
        ..duration = newSpec.duration
        ..value = 0;
      if (newSpec.type != IdleMotionType.none) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final spec = _spec;

    if (!widget.enabled || reduceMotion || spec.type == IdleMotionType.none) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final phase = (_controller.value + spec.delayFraction) % 1.0;
        return _MotionTransform(
          spec: spec,
          phase: phase,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _MotionTransform extends StatelessWidget {
  final IdleMotionSpec spec;
  final double phase;
  final Widget child;

  const _MotionTransform({
    required this.spec,
    required this.phase,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(phase * math.pi * 2) * spec.amplitude;

    switch (spec.type) {
      case IdleMotionType.float:
        return Transform.translate(offset: Offset(0, wave), child: child);
      case IdleMotionType.bob:
        return Transform.translate(
          offset: Offset(0, -wave.abs()),
          child: child,
        );
      case IdleMotionType.sway:
        return Transform.translate(offset: Offset(wave, 0), child: child);
      case IdleMotionType.breathe:
        return Transform.scale(scale: 1 + wave, child: child);
      case IdleMotionType.pulse:
        return Transform.scale(
          scale: 1 + (wave + spec.amplitude) / 2,
          child: child,
        );
      case IdleMotionType.wiggle:
      case IdleMotionType.tilt:
        return Transform.rotate(angle: wave, child: child);
      case IdleMotionType.drift:
      case IdleMotionType.orbit:
        return Transform.translate(
          offset: Offset(
            math.cos(phase * math.pi * 2) * spec.amplitude,
            math.sin(phase * math.pi * 2) * spec.amplitude,
          ),
          child: child,
        );
      case IdleMotionType.shimmer:
        final opacity = (1 -
                spec.amplitude / 2 +
                (wave.abs() / spec.amplitude) * spec.amplitude)
            .clamp(0.0, 1.0);
        return Opacity(opacity: opacity, child: child);
      case IdleMotionType.none:
        return child;
    }
  }
}

/// A moving highlight across text, used for the wordmark.
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;
  final List<Color> colors;

  const ShimmerText({
    super.key,
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 2600),
    this.colors = const [
      Color(0xFFFFFFFF),
      Color(0xFFC7F26A),
      Color(0xFFFFFFFF),
    ],
  });

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(widget.text, style: widget.style);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: widget.colors,
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(
                percent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: Text(widget.text, style: widget.style),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double percent;

  const _SlidingGradientTransform({required this.percent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (percent * 2 - 1),
      0,
      0,
    );
  }
}

/// Fades and slides a widget in after a delay. Used for the intro cascade.
class RevealOnMount extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  const RevealOnMount({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 620),
    this.offset = const Offset(0, 0.16),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<RevealOnMount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
