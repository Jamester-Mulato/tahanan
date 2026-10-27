import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';

// High-performance motion primitives for Tahanan.
//
// Design goals:
// - GPU-cheap transforms only (opacity / translate / scale). No layout
//   thrash, no backdrop blur in animations.
// - Zero leaked tickers: every looping widget owns and disposes one
//   controller, and freezes when `MediaQuery.disableAnimations` is set.
// - Children are passed through `TweenAnimationBuilder.child` (or cached in
//   a [RepaintBoundary]) so the subtree is built once, not every frame.

// ---------------------------------------------------------------------------
// Entrance: fade + slide (cheap, staggered)
// ---------------------------------------------------------------------------

class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideDistance;

  /// Explicit travel vector. When provided it overrides [slideDistance]
  /// so directional entrances share this one implementation.
  final Offset? offset;

  /// Optional entrance scale (e.g. 0.94 for hero cards). Null means no
  /// scale is animated — opacity + translate only.
  final double? scaleBegin;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 380),
    this.slideDistance = 14,
    this.offset,
    this.scaleBegin,
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: curve,
      builder: (context, value, cachedChild) {
        // Hold at zero during the stagger delay, then ease in.
        final delayFrac =
            delay.inMilliseconds / (duration + delay).inMilliseconds;
        final t = ((value - 0) * 1.0) <= delayFrac
            ? 0.0
            : ((value - delayFrac) / (1 - delayFrac)).clamp(0.0, 1.0);
        final eased = curve.transform(t);
        final travel = offset ??
            Offset(
              0,
              slideDistance * (1 - eased),
            );
        final dx = offset == null ? 0.0 : travel.dx * (1 - eased);
        final dy = offset == null ? travel.dy : travel.dy * (1 - eased);
        Widget result = Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: cachedChild,
          ),
        );
        if (scaleBegin != null) {
          result = Transform.scale(
            scale: scaleBegin! + (1 - scaleBegin!) * eased,
            child: result,
          );
        }
        return result;
      },
      child: child,
    );
  }
}

/// Wraps a list of children with a stagger so screens feel alive on entry.
/// Children are built once by the caller; only opacity/translate animate.
class StaggerColumn extends StatelessWidget {
  final List<Widget> children;
  final Duration step;
  final Duration baseDuration;

  /// Initial delay before the first child starts arriving.
  final Duration start;

  const StaggerColumn({
    super.key,
    required this.children,
    this.step = const Duration(milliseconds: 45),
    this.baseDuration = const Duration(milliseconds: 340),
    this.start = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (MediaQuery.disableAnimationsOf(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          FadeSlideIn(
            delay: start + step * i,
            duration: baseDuration,
            child: children[i],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pressable: tactile scale feedback without layout cost
// ---------------------------------------------------------------------------

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool enabled;
  final bool haptic;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.enabled = true,
    this.haptic = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final interactive =
        (widget.onTap != null || widget.onLongPress != null) && widget.enabled;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final child = disableAnimations
        ? widget.child
        : AnimatedScale(
            scale: _down ? widget.pressedScale : 1.0,
            duration: AppColors.fastAnim,
            curve: Curves.easeOutCubic,
            child: widget.child,
          );
    if (!interactive) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Idle motion: gentle float / breathing glow for hero elements
// ---------------------------------------------------------------------------

/// Slow vertical drift (±[amplitude] px) for logos, empty states, hero cards.
/// Single ticker, transform-only, wrapped in a [RepaintBoundary].
class IdleFloat extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;

  const IdleFloat({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.period = const Duration(milliseconds: 3200),
  });

  @override
  State<IdleFloat> createState() => _IdleFloatState();
}

class _IdleFloatState extends State<IdleFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, cached) {
          final dy = (CurvedAnimation(
                        parent: _controller,
                        curve: Curves.easeInOutSine,
                      ).value *
                      2 -
                  1) *
              widget.amplitude;
          return Transform.translate(offset: Offset(0, dy), child: cached);
        },
        child: widget.child,
      ),
    );
  }
}

/// Soft opacity breathing for glow orbs / badges.
class Breathing extends StatefulWidget {
  final Widget child;
  final double minOpacity;
  final Duration period;

  const Breathing({
    super.key,
    required this.child,
    this.minOpacity = 0.55,
    this.period = const Duration(milliseconds: 2600),
  });

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, cached) {
          final t = Curves.easeInOutSine.transform(_controller.value);
          return Opacity(
            opacity: widget.minOpacity + (1 - widget.minOpacity) * t,
            child: cached,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Count-up numbers for stat cards
// ---------------------------------------------------------------------------

class CountUp extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;
  final String Function(num value)? format;

  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = AppColors.slowAnim,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(format?.call(value) ?? '$value',
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        final num shown =
            value is int ? animated.round() : (animated * 10).round() / 10;
        return Text(
          format?.call(shown) ?? '$shown',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer skeleton (loading placeholder)
// ---------------------------------------------------------------------------

class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return _staticBox();
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final t = _controller.value;
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  Color(0xFFE3EFE8),
                  Color(0xFFF6FBF8),
                  Color(0xFFE3EFE8),
                ],
                stops: [
                  (t - 0.35).clamp(0.0, 1.0),
                  t,
                  (t + 0.35).clamp(0.0, 1.0)
                ],
              ).createShader(bounds);
            },
            child: _staticBox(),
          );
        },
      ),
    );
  }

  Widget _staticBox() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFE3EFE8),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
    );
  }
}

/// Full skeleton card used while dashboards load.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E8DD)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 34, height: 34, borderRadius: 10),
              SizedBox(width: 8),
              Spacer(),
              Flexible(
                child: FractionallySizedBox(
                  alignment: Alignment.centerRight,
                  widthFactor: 0.5,
                  child: SkeletonBox(
                    width: double.infinity,
                    height: 18,
                    borderRadius: 999,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          FractionallySizedBox(
            widthFactor: 0.72,
            child: SkeletonBox(
                width: double.infinity, height: 24, borderRadius: 8),
          ),
          SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.95,
            child: SkeletonBox(
                width: double.infinity, height: 12, borderRadius: 6),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedTabStage: directional fade+slide over an IndexedStack
// ---------------------------------------------------------------------------

/// Preserves the state and scroll offset of every tab via [IndexedStack]
/// while animating tab switches with a GPU-cheap opacity + directional
/// translate + micro-scale transition.
class AnimatedTabStage extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const AnimatedTabStage({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedTabStage> createState() => _AnimatedTabStageState();
}

class _AnimatedTabStageState extends State<AnimatedTabStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedTabStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _direction = widget.index > oldWidget.index ? 1 : -1;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: widget.children[i],
          ),
      ],
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return stack;
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          final dx = (1.0 - t) * 22.0 * _direction;
          final dy = (1.0 - t) * 6.0;
          final scale = 0.988 + (0.012 * t);
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            ),
          );
        },
        child: stack,
      ),
    );
  }
}
