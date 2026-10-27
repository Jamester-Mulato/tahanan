import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import 'tahanan_kit.dart';

/// A spring-like entrance with fade, slide and scale. Used to cascade a
/// screen in instead of dropping every element at once.
class GlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset begin;
  final double scaleBegin;
  final Curve curve;

  const GlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 620),
    this.begin = const Offset(0, 0.10),
    this.scaleBegin = 0.97,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<GlideIn> createState() => _GlideInState();
}

class _GlideInState extends State<GlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = curved;
    _slide =
        Tween<Offset>(begin: widget.begin, end: Offset.zero).animate(curved);
    _scale = Tween<double>(begin: widget.scaleBegin, end: 1).animate(curved);

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
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

/// A pointer-reactive tilt/lift for cards. Falls back to a plain child on
/// touch devices (no hover events).
class HoverTilt extends StatefulWidget {
  final Widget child;
  final double maxTilt;
  final double lift;
  final double hoverScale;
  final Duration duration;

  const HoverTilt({
    super.key,
    required this.child,
    this.maxTilt = 0.035,
    this.lift = 3,
    this.hoverScale = 1.008,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<HoverTilt> createState() => _HoverTiltState();
}

class _HoverTiltState extends State<HoverTilt> {
  double _rx = 0;
  double _ry = 0;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(_rx)
      ..rotateY(_ry);

    return MouseRegion(
      onEnter: reduce
          ? null
          : (_) {
              setState(() => _hovering = true);
            },
      onExit: reduce
          ? null
          : (_) {
              setState(() {
                _hovering = false;
                _rx = 0;
                _ry = 0;
              });
            },
      onHover: reduce
          ? null
          : (event) {
              final box = context.findRenderObject() as RenderBox?;
              final size = box?.size;
              if (size == null || size.isEmpty) return;
              final nx =
                  (event.localPosition.dx / size.width - 0.5).clamp(-0.5, 0.5);
              final ny =
                  (event.localPosition.dy / size.height - 0.5).clamp(-0.5, 0.5);
              setState(() {
                _rx = -ny * widget.maxTilt * 2;
                _ry = nx * widget.maxTilt * 2;
              });
            },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: _hovering ? 1 : 0),
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Transform.translate(
            offset: Offset(0, -widget.lift * t),
            child: Transform.scale(
              scale: 1 + (widget.hoverScale - 1) * t,
              child: Transform(
                alignment: Alignment.center,
                transform: transform,
                child: child,
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A press with a small scale, a soft shadow drop and optional haptic.
class PressGlide extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;
  final BorderRadius? borderRadius;

  const PressGlide({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
    this.haptic = true,
    this.borderRadius,
  });

  @override
  State<PressGlide> createState() => _PressGlideState();
}

class _PressGlideState extends State<PressGlide> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: _down
                ? []
                : [
                    BoxShadow(
                      color: AppColors.text.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Shakes its child when [trigger] changes to a non-null value. Used for
/// invalid form submissions.
class ShakeOnError extends StatefulWidget {
  final Widget child;
  final Object? trigger;

  const ShakeOnError({super.key, required this.child, this.trigger});

  @override
  State<ShakeOnError> createState() => _ShakeOnErrorState();
}

class _ShakeOnErrorState extends State<ShakeOnError>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(covariant ShakeOnError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != null && widget.trigger != oldWidget.trigger) {
      _controller.forward(from: 0);
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
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        if (t == 0 || t == 1) return child ?? const SizedBox.shrink();
        final damp = (1 - t) * 9;
        final dx = math.sin(t * math.pi * 8) * damp;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// A text field with a focus glow, animated border, and press response.
class GlideField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final String? error;
  final bool required;

  const GlideField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.error,
    this.required = false,
  });

  @override
  State<GlideField> createState() => _GlideFieldState();
}

class _GlideFieldState extends State<GlideField> {
  FocusNode? _internalFocus;
  bool _focused = false;

  FocusNode get _focus => widget.focusNode ?? (_internalFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant GlideField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _internalFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.error != null && widget.error!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            if (widget.required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.danger,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError
                  ? AppColors.danger.withValues(alpha: 0.6)
                  : _focused
                      ? kPrimary.withValues(alpha: 0.45)
                      : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            obscureText: widget.obscure,
            autocorrect: false,
            enableSuggestions: !widget.obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: Icon(widget.icon, size: 19, color: AppColors.muted),
              suffixIcon: widget.suffix,
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(
                    widget.error!,
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Moves a button a few pixels toward the pointer. Adds a physical, magnetic
/// feel on web without affecting touch.
class Magnetic extends StatefulWidget {
  final Widget child;
  final double strength;

  const Magnetic({super.key, required this.child, this.strength = 5});

  @override
  State<Magnetic> createState() => _MagneticState();
}

class _MagneticState extends State<Magnetic> {
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return MouseRegion(
      onHover: reduce
          ? null
          : (event) {
              final box = context.findRenderObject() as RenderBox?;
              final size = box?.size;
              if (size == null || size.isEmpty) return;
              final dx =
                  (event.localPosition.dx / size.width - 0.5).clamp(-0.5, 0.5);
              final dy =
                  (event.localPosition.dy / size.height - 0.5).clamp(-0.5, 0.5);
              setState(() => _offset = Offset(
                    dx * widget.strength * 2,
                    dy * widget.strength,
                  ));
            },
      onExit: reduce ? null : (_) => setState(() => _offset = Offset.zero),
      child: AnimatedSlide(
        offset: Offset(_offset.dx / 100, _offset.dy / 100),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// A slow, soft floating wrapper for decorative elements.
class Drift extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;

  const Drift({
    super.key,
    required this.child,
    this.amplitude = 6,
    this.period = const Duration(milliseconds: 6200),
  });

  @override
  State<Drift> createState() => _DriftState();
}

class _DriftState extends State<Drift> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value * math.pi * 2;
        return Transform.translate(
          offset: Offset(
            math.cos(t) * widget.amplitude,
            math.sin(t * 0.8) * widget.amplitude * 0.7,
          ),
          child: child,
        );
      },
    );
  }
}
